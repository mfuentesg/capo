import CapoCore
import CapoFakes
import CapoSupabase
import Foundation
import Supabase
import Testing

@testable import CapoAppKit

private let localConfig = AppConfig(
  supabaseURL: URL(string: "http://127.0.0.1:54321")!, supabaseKey: "sb_publishable_test",
  webBaseURL: URL(string: "http://localhost:3000")!, environmentName: "local")

private let session = AuthSession(
  userID: FakeIDs.user, email: "me@example.test", fullName: nil, avatarURL: nil, provider: "google")

/// Remotes that fail every network call, as on a device in airplane mode.
private func offlineRemotes() async -> CapoComposition.Remotes {
  let source = FakeRemoteSyncSource()
  for method in ["memberships", "teams", "songVersions", "songs", "playlistVersions", "profile"] {
    await source.failNext(method, with: URLError(.notConnectedToInternet))
  }
  let writer = FakeRemoteWriter()
  await writer.enqueueFailure(URLError(.notConnectedToInternet))
  return CapoComposition.Remotes(
    teams: FakeTeamsRemote(backend: InMemoryBackend()), syncSource: source, writer: writer,
    realtime: FakeRealtimeNotifier())
}

private func temporaryDirectory() -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent("capo-tests-\(UUID().uuidString)")
}

@Suite(.serialized) struct CompositionTests {
  @Test func demoModeWithoutConfig() {
    let dependencies = CapoComposition.make(config: nil)
    #expect(dependencies.isDemo)
    #expect(dependencies.config == nil)
  }

  @Test func liveModeWithConfig() {
    let dependencies = CapoComposition.makeLive(config: localConfig)
    #expect(!dependencies.isDemo)
    #expect(dependencies.config == localConfig)
  }

  /// Offline cold start: the per-user database opens and serves local data with no network,
  /// and sync reports `.offline` instead of failing.
  @Test func offlineColdStartServesLocalData() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let context = AppContext.personal(userID: session.userID)

    let first = try CapoComposition.makeUserServices(
      session: session, remotes: await offlineRemotes(), config: localConfig,
      directory: directory, reachability: FakeReachability(online: false))
    let song = try await first.songs.create(SongDraft(title: "Canción offline"), in: context)
    await first.tearDown(false)

    // Cold start: a fresh composition over the same directory, still offline.
    let second = try CapoComposition.makeUserServices(
      session: session, remotes: await offlineRemotes(), config: localConfig,
      directory: directory, reachability: FakeReachability(online: false))
    #expect(try await second.songs.fetchSong(id: song.id)?.title == "Canción offline")

    var results = second.songs.songs(SongQuery(context: context, searchText: "cancion")).makeAsyncIterator()
    #expect(await results.next()?.map(\.id) == [song.id])

    // The injected reachability reaches the engine, and a sync while offline stays offline.
    await second.sync.start()
    #expect(await firstStatus(of: second.sync) { $0.phase == .offline } != nil)
    await second.sync.syncNow(reason: .appLaunch)
    #expect(await firstStatus(of: second.sync) { _ in true }?.phase == .offline)
    await second.tearDown(false)
  }

  @Test func tearDownWithEraseDropsLocalData() async throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let context = AppContext.personal(userID: session.userID)

    let services = try CapoComposition.makeUserServices(
      session: session, remotes: await offlineRemotes(), config: localConfig,
      directory: directory, reachability: FakeReachability(online: false))
    let song = try await services.songs.create(SongDraft(title: "Temporary"), in: context)
    await services.tearDown(true)

    let reopened = try CapoComposition.makeUserServices(
      session: session, remotes: await offlineRemotes(), config: localConfig,
      directory: directory, reachability: FakeReachability(online: false))
    #expect(try await reopened.songs.fetchSong(id: song.id) == nil)
    await reopened.tearDown(false)
  }

  /// The URL ASWebAuthenticationSession opens for Google: PKCE, provider and our callback.
  @Test func googleOAuthURLUsesPKCEAndCapoCallback() throws {
    let client = SupabaseClientFactory.make(config: localConfig)
    let url = try client.auth.getOAuthSignInURL(provider: .google, redirectTo: localConfig.authCallbackURL)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let query = Dictionary(
      (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })

    #expect(components.host == "127.0.0.1")
    #expect(components.port == 54321)
    #expect(components.path == "/auth/v1/authorize")
    #expect(query["provider"] == "google")
    #expect(query["redirect_to"] == "capo://auth/callback")
    #expect(query["code_challenge"]?.isEmpty == false)
    #expect(query["code_challenge_method"]?.lowercased() == "s256")
  }
}

/// The first status matching `predicate` within two seconds, or nil.
private func firstStatus(
  of sync: any SyncService, where predicate: @escaping @Sendable (SyncStatus) -> Bool
) async -> SyncStatus? {
  await withTaskGroup(of: SyncStatus?.self) { group in
    group.addTask {
      for await status in sync.status() where predicate(status) { return status }
      return nil
    }
    group.addTask {
      try? await Task.sleep(for: .seconds(2))
      return nil
    }
    let result = await group.next() ?? nil
    group.cancelAll()
    return result
  }
}

