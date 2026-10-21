import CapoCore
import Foundation
import Supabase
import Testing

@testable import CapoSupabase

/// Runs only with `CAPO_LOCAL_SUPABASE=1` and `CAPO_LOCAL_SUPABASE_KEY` set, against the
/// already-running local stack at 127.0.0.1:54321. Never resets or stops anything.
@Suite(
  .enabled(
    if: ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE"] == "1"
      && ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE_KEY"] != nil)
)
struct LocalE2E {
  @Test func songRoundTripWithConflict() async throws {
    let key = ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE_KEY"]!
    let client = SupabaseClient(
      supabaseURL: URL(string: "http://127.0.0.1:54321")!, supabaseKey: key,
      options: SupabaseClientOptions(
        auth: .init(storage: MemoryAuthStorage(), emitLocalSessionAsInitialSession: true)))
    let email = "ios-e2e+\(UUID().uuidString.lowercased())@example.test"
    let session: AuthResponse
    do {
      session = try await client.auth.signUp(email: email, password: "e2e-\(UUID().uuidString)")
    } catch {
      // The local stack ships with enable_signup = false; without a throwaway user there is nothing
      // to write as, so this write-path test is a no-op there (see LocalE2EReadPath for the read path).
      print("LocalE2E.songRoundTripWithConflict skipped: signup unavailable (\(error))")
      return
    }
    let userID = session.user.id
    let writer = SupabaseRemoteWriter(client: client)
    let source = SupabaseRemoteSyncSource(client: client)

    var song = makeSong(id: UUID())
    song.userID = userID
    song.createdBy = userID
    var created: Song?
    if case .applied(let server?) = try await writer.apply(.createSong(song)) { created = server }
    let server = try #require(created)

    let scope = SyncScope(userID: userID, teamIDs: [])
    #expect(try await source.songVersions(scope: scope).contains { $0.id == song.id })

    let first = try await writer.apply(
      .updateSong(id: song.id, patch: SongPatch(title: "One"), base: server.updatedAt))
    guard case .applied(let updated?) = first else { Issue.record("update not applied"); return }
    let stale = try await writer.apply(
      .updateSong(id: song.id, patch: SongPatch(title: "Two"), base: server.updatedAt))
    #expect(stale == .conflict(server: updated))

    _ = try await writer.apply(.deleteSong(id: song.id))
    try? await client.auth.signOut(scope: .local)
  }
}

/// Read-only: signs in with the session minted by `ios/scripts/mint-dev-session.sh` (git-ignored
/// `ios/Capo/Capo/DevSession.plist`) and pulls the user's library through the real
/// `SupabaseRemoteSyncSource`. Writes nothing. Skips when the plist is missing or its access token
/// has expired (re-run the script) so the refresh token is never rotated out from under the app.
@Suite(
  .enabled(
    if: ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE"] == "1"
      && ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE_KEY"] != nil)
)
struct LocalE2EReadPath {
  private static var plistURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Capo/Capo/DevSession.plist")
  }

  private static func expiry(of jwt: String) -> Date? {
    let parts = jwt.split(separator: ".")
    guard parts.count > 1 else { return nil }
    var b64 = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while b64.count % 4 != 0 { b64 += "=" }
    guard let data = Data(base64Encoded: b64),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let exp = obj["exp"] as? TimeInterval
    else { return nil }
    return Date(timeIntervalSince1970: exp)
  }

  @Test func libraryPullReturnsSongs() async throws {
    guard let data = try? Data(contentsOf: Self.plistURL),
      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any],
      let access = plist["ACCESS_TOKEN"] as? String, let refresh = plist["REFRESH_TOKEN"] as? String
    else {
      print("LocalE2EReadPath skipped: no DevSession.plist (run ios/scripts/mint-dev-session.sh)")
      return
    }
    guard let exp = Self.expiry(of: access), exp > Date().addingTimeInterval(30) else {
      print("LocalE2EReadPath skipped: dev session expired (re-run mint-dev-session.sh)")
      return
    }
    let key = ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE_KEY"]!
    let client = SupabaseClient(
      supabaseURL: URL(string: "http://127.0.0.1:54321")!, supabaseKey: key,
      options: SupabaseClientOptions(
        auth: .init(storage: MemoryAuthStorage(), emitLocalSessionAsInitialSession: true)))
    let session = try await client.auth.setSession(accessToken: access, refreshToken: refresh)
    let source = SupabaseRemoteSyncSource(client: client)

    let memberships = try await source.memberships(userID: session.user.id)
    let scope = SyncScope(userID: session.user.id, teamIDs: memberships.map(\.teamID))
    let versions = try await source.songVersions(scope: scope)
    #expect(versions.count > 0)
    let songs = try await source.songs(ids: Array(versions.prefix(20).map(\.id)))
    #expect(songs.count == min(20, versions.count))
    #expect(songs.allSatisfy { !$0.title.isEmpty })
    _ = try await source.profile(userID: session.user.id)
    print("LocalE2EReadPath: \(versions.count) song versions, \(memberships.count) memberships")
  }
}
