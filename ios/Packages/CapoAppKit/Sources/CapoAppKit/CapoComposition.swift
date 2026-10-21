import CapoCore
import CapoFakes
import CapoStore
import CapoSupabase
import CapoSync
import Foundation
import os

public nonisolated enum CapoComposition {
  private static let logger = Logger(subsystem: "com.mfuentesg.capo", category: "composition")

  /// Demo mode when `config` is nil or the app was launched with `-CapoDemoMode YES`.
  public static func make(config: AppConfig?) -> AppDependencies {
    guard let config, !UserDefaults.standard.bool(forKey: "CapoDemoMode") else {
      logger.info("Starting in demo mode")
      return .demo
    }
    return makeLive(config: config)
  }

  /// Supabase auth, then per session: the user's SQLite database, GRDB repositories and a
  /// SyncEngine over the Supabase remote. Sync start and lifecycle triggers are driven by the shell.
  static func makeLive(config: AppConfig) -> AppDependencies {
    logger.info("Starting against \(config.environmentName, privacy: .public) (\(config.supabaseURL.absoluteString, privacy: .public))")
    let client = SupabaseClientFactory.make(config: config)
    let auth = SupabaseAuthService(client: client, callbackURL: config.authCallbackURL)
    #if DEBUG
      DevSession.applyIfPresent(to: client)
    #endif
    let remotes = Remotes(
      teams: SupabaseTeamsRemote(client: client, webBaseURL: config.webBaseURL),
      syncSource: SupabaseRemoteSyncSource(client: client),
      writer: SupabaseRemoteWriter(client: client),
      realtime: SupabaseRealtimeNotifier(client: client),
      account: SupabaseAccountRemote(client: client))
    return AppDependencies(
      config: config, isDemo: false, auth: auth,
      makeUserServices: { session in
        try makeUserServices(session: session, remotes: remotes, config: config)
      })
  }

  /// The Supabase-backed remotes shared by every session of this app run.
  struct Remotes: Sendable {
    var teams: any TeamsRemote
    var syncSource: any RemoteSyncSource
    var writer: any RemoteWriter
    var realtime: any RealtimeNotifier
    var account: SupabaseAccountRemote?
  }

  static func databaseDirectory() throws -> URL {
    try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    ).appendingPathComponent("Capo", isDirectory: true)
  }

  static func makeUserServices(
    session: AuthSession, remotes: Remotes, config: AppConfig, directory: URL? = nil,
    reachability: (any ReachabilityMonitor)? = nil
  ) throws -> UserServices {
    let userID = session.userID
    let database = try CapoDatabase.open(
      userID: userID, directory: try directory ?? databaseDirectory())
    let teamsRemote = remotes.teams
    let syncBox = SyncBox()
    let repositories = LocalRepositories(
      database: database, userID: userID, teamsRemote: teamsRemote,
      onRemoteMutation: { await syncBox.engine?.syncNow(reason: .manual) })
    let engine = SyncEngine(
      userID: userID, store: repositories.syncStore,
      remote: remotes.syncSource, writer: remotes.writer, realtime: remotes.realtime,
      reachability: reachability ?? NWReachabilityMonitor())
    syncBox.engine = engine
    var deleteAccount: (@Sendable () async throws -> Void)?
    if let account = remotes.account {
      deleteAccount = { try await account.deleteAccount(userID: userID) }
    }
    logger.info("Opened local database for user \(userID.uuidString, privacy: .private)")

    return UserServices(
      userID: userID,
      songs: repositories.songs,
      tags: repositories.tags,
      playlists: repositories.playlists,
      settings: repositories.settings,
      teams: repositories.teams,
      sharing: RemoteSharingService(remote: teamsRemote, webBaseURL: config.webBaseURL),
      conflicts: repositories.conflicts,
      sync: engine,
      tearDown: { eraseLocalData in
        await engine.stop()
        syncBox.engine = nil
        guard eraseLocalData else { return }
        do {
          try database.erase()
          logger.info("Erased local data on sign-out")
        } catch {
          logger.error("Erasing local data failed: \(error.localizedDescription, privacy: .public)")
        }
      },
      deleteAccount: deleteAccount)
  }
}

/// Late-bound reference so team mutations made through the repositories can trigger a pull.
private nonisolated final class SyncBox: Sendable {
  private let state = OSAllocatedUnfairLock<SyncEngine?>(initialState: nil)
  var engine: SyncEngine? {
    get { state.withLock { $0 } }
    set { state.withLock { $0 = newValue } }
  }
}

/// Online-only share links: `ensure_share_code` RPC through the teams remote.
nonisolated struct RemoteSharingService: SharingService {
  let remote: any TeamsRemote
  let webBaseURL: URL

  func ensureShareCode(playlistID: PlaylistID) async throws -> String {
    try await remote.ensureShareCode(playlistID: playlistID)
  }

  func shareURL(forCode code: String) -> URL {
    webBaseURL.appendingPathComponent("playlists").appendingPathComponent(code)
  }
}
