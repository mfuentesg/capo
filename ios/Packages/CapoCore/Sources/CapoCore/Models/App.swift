import Foundation

public enum AppContext: Hashable, Sendable, Codable {
  /// `all` is the web's default "All" view: personal items plus every team bucket. Reads only;
  /// creating in `all` creates a personal item.
  case all(userID: UserID), personal(userID: UserID), team(teamID: TeamID)

  public var teamID: TeamID? {
    if case .team(let teamID) = self { return teamID }
    return nil
  }

  public var isAll: Bool {
    if case .all = self { return true }
    return false
  }

  /// The context new items are created in: `all` falls back to personal.
  public var creationContext: AppContext {
    if case .all(let userID) = self { return .personal(userID: userID) }
    return self
  }
}

public struct AppConfig: Hashable, Sendable {
  public var supabaseURL: URL
  public var supabaseKey: String
  public var webBaseURL: URL
  public var environmentName: String
  public var authCallbackURL: URL  // capo://auth/callback

  public static let defaultAuthCallbackURL = URL(string: "capo://auth/callback")!

  public init(
    supabaseURL: URL, supabaseKey: String, webBaseURL: URL, environmentName: String,
    authCallbackURL: URL = AppConfig.defaultAuthCallbackURL
  ) {
    self.supabaseURL = supabaseURL
    self.supabaseKey = supabaseKey
    self.webBaseURL = webBaseURL
    self.environmentName = environmentName
    self.authCallbackURL = authCallbackURL
  }

  /// Reads `Secrets.plist` from the bundle. nil when it is missing or incomplete (demo mode).
  public static func load(from bundle: Bundle) -> AppConfig? {
    guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
      let data = try? Data(contentsOf: url),
      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        as? [String: Any]
    else { return nil }
    return load(from: plist)
  }

  static func load(from plist: [String: Any]) -> AppConfig? {
    func value(_ key: String) -> String? {
      guard let s = (plist[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
        !s.isEmpty
      else { return nil }
      return s
    }
    guard let supabase = value("SUPABASE_URL").flatMap(URL.init(string:)),
      let key = value("SUPABASE_PUBLISHABLE_KEY"),
      let web = value("CAPO_WEB_URL").flatMap(URL.init(string:))
    else { return nil }
    return AppConfig(
      supabaseURL: supabase, supabaseKey: key, webBaseURL: web,
      environmentName: value("CAPO_ENV_NAME") ?? "production"
    )
  }
}

public struct AuthSession: Hashable, Sendable {
  public var userID: UserID
  public var email: String?
  public var fullName: String?
  public var avatarURL: URL?
  public var provider: String?

  public init(
    userID: UserID, email: String?, fullName: String?, avatarURL: URL?, provider: String?
  ) {
    self.userID = userID
    self.email = email
    self.fullName = fullName
    self.avatarURL = avatarURL
    self.provider = provider
  }
}

public enum CapoError: Error, Hashable, Sendable {
  case notAuthenticated, offlineUnavailable, permissionDenied, notFound, conflict
  case invalidInput(String), server(String), configurationMissing
}

public struct SongConflict: Identifiable, Hashable, Sendable {
  public var id: UUID  // op id
  public var local: Song
  public var server: Song?
  public var detectedAt: Date

  public init(id: UUID, local: Song, server: Song?, detectedAt: Date) {
    self.id = id
    self.local = local
    self.server = server
    self.detectedAt = detectedAt
  }
}

public enum ConflictResolution: Hashable, Sendable {
  case keepMine, keepTheirs, keepBothAsCopy
}

public enum SyncPhase: Hashable, Sendable {
  case idle, pushing, pulling, offline, error(String)
}

public struct SyncStatus: Hashable, Sendable {
  public var phase: SyncPhase
  public var lastSuccessAt: Date?
  public var pendingOperations: Int
  public var conflicts: Int
  public var failedOperations: Int

  public init(
    phase: SyncPhase = .idle, lastSuccessAt: Date? = nil, pendingOperations: Int = 0,
    conflicts: Int = 0, failedOperations: Int = 0
  ) {
    self.phase = phase
    self.lastSuccessAt = lastSuccessAt
    self.pendingOperations = pendingOperations
    self.conflicts = conflicts
    self.failedOperations = failedOperations
  }
}

public enum SyncReason: Hashable, Sendable {
  case appLaunch, foreground, manual, realtime, reachability, outboxEnqueued
}

public struct SyncScope: Hashable, Sendable {
  public var userID: UserID
  public var teamIDs: [TeamID]

  public init(userID: UserID, teamIDs: [TeamID]) {
    self.userID = userID
    self.teamIDs = teamIDs
  }
}

public struct RowVersion: Hashable, Sendable {
  public var id: UUID
  public var updatedAt: ServerTimestamp

  public init(id: UUID, updatedAt: ServerTimestamp) {
    self.id = id
    self.updatedAt = updatedAt
  }
}

public struct RealtimeChange: Hashable, Sendable {
  public var table: String

  public init(table: String) {
    self.table = table
  }
}
