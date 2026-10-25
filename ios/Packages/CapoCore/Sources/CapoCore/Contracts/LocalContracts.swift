import Foundation

// Local contracts: consumed by UI; implemented by CapoStore and CapoFakes.

public enum SongSort: String, Sendable, CaseIterable {
  case recent, title, artist, relevance
}

public struct SongQuery: Hashable, Sendable {
  public var context: AppContext
  public var searchText: String = ""
  public var tagIDs: Set<TagID> = []
  public var statuses: Set<SongStatus> = [.published, .draft]
  public var bpmRange: ClosedRange<Int>? = nil
  public var sort: SongSort = .recent

  public init(
    context: AppContext, searchText: String = "", tagIDs: Set<TagID> = [],
    statuses: Set<SongStatus> = [.published, .draft], bpmRange: ClosedRange<Int>? = nil,
    sort: SongSort = .recent
  ) {
    self.context = context
    self.searchText = searchText
    self.tagIDs = tagIDs
    self.statuses = statuses
    self.bpmRange = bpmRange
    self.sort = sort
  }
}

public protocol SongRepository: Sendable {
  func songs(_ query: SongQuery) -> AsyncStream<[SongListItem]>
  func song(id: SongID) -> AsyncStream<Song?>
  func fetchSong(id: SongID) async throws -> Song?
  func create(_ draft: SongDraft, in context: AppContext) async throws -> Song
  func update(id: SongID, _ patch: SongPatch) async throws
  func delete(id: SongID) async throws
  func setTags(songID: SongID, tagIDs: [TagID]) async throws
  func tags(forSong id: SongID) -> AsyncStream<[SongTag]>
}

public protocol TagRepository: Sendable {
  func tags(in context: AppContext) -> AsyncStream<[SongTag]>
  func create(name: String, color: String?, in context: AppContext) async throws -> SongTag
  func delete(id: TagID) async throws
}

public protocol PlaylistRepository: Sendable {
  func playlists(in context: AppContext, includeArchived: Bool) -> AsyncStream<[PlaylistSummary]>
  func playlist(id: PlaylistID) -> AsyncStream<PlaylistDetail?>
  func create(_ draft: PlaylistDraft, in context: AppContext) async throws -> Playlist
  func update(id: PlaylistID, _ patch: PlaylistPatch) async throws
  func delete(id: PlaylistID) async throws
  func setArchived(id: PlaylistID, _ archived: Bool) async throws
  func addSongs(_ songIDs: [SongID], to playlistID: PlaylistID) async throws
  func removeSong(_ songID: SongID, from playlistID: PlaylistID) async throws
  func reorder(playlistID: PlaylistID, songIDs: [SongID]) async throws
  func setPinned(_ pinned: Bool, playlistID: PlaylistID) async throws
}

public protocol SettingsRepository: Sendable {
  func songSettings(songID: SongID) -> AsyncStream<UserSongSettings?>
  func saveSongSettings(_ settings: UserSongSettings) async throws
  func preferences() -> AsyncStream<UserPreferences>
  func updatePreferences(_ patch: PreferencesPatch) async throws
}

public protocol TeamRepository: Sendable {
  func teams() -> AsyncStream<[TeamWithRole]>  // local
  func members(teamID: TeamID) async throws -> [TeamMember]  // online-only below
  func invitations(teamID: TeamID) async throws -> [TeamInvitation]
  func pendingInvitationsForMe() async throws -> [PendingInvitation]
  func createTeam(name: String, icon: String?, isPublic: Bool) async throws -> Team
  func updateTeam(id: TeamID, name: String, icon: String?) async throws
  func deleteTeam(id: TeamID) async throws
  func leaveTeam(id: TeamID) async throws
  func invite(email: String, role: TeamRole, teamID: TeamID) async throws -> TeamInvitation
  func revokeInvitation(id: UUID) async throws
  func declineInvitation(token: String) async throws
  func resendInvitation(id: UUID) async throws -> TeamInvitation
  func acceptInvitation(token: String) async throws -> TeamID
  func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws
  func removeMember(userID: UserID, teamID: TeamID) async throws
  func transferOwnership(teamID: TeamID, to userID: UserID) async throws
}

public protocol SharingService: Sendable {
  func ensureShareCode(playlistID: PlaylistID) async throws -> String  // online, rpc ensure_share_code
  func shareURL(forCode code: String) -> URL  // webBaseURL/shared/<code> (web route app/(app)/shared/[shareCode])
}

/// A queued change the server refused (or that kept failing). It stays visible, and the local
/// copy is protected from the next pull, until the user retries or discards it.
public struct FailedOperation: Identifiable, Hashable, Sendable {
  public var id: UUID
  /// Outbox kind, e.g. "deleteSong", "setSongTags".
  public var kind: String
  /// Song title, playlist or tag name; nil when the entity is gone locally.
  public var subject: String?
  public var error: String?
  public var createdAt: Date

  public init(id: UUID, kind: String, subject: String?, error: String?, createdAt: Date) {
    self.id = id
    self.kind = kind
    self.subject = subject
    self.error = error
    self.createdAt = createdAt
  }
}

public protocol ConflictRepository: Sendable {
  func conflicts() -> AsyncStream<[SongConflict]>
  func resolve(_ conflictID: UUID, with resolution: ConflictResolution) async throws
  func failedOperations() -> AsyncStream<[FailedOperation]>
  /// Queues the operation again (attempts reset).
  func retryFailed(_ id: UUID) async throws
  /// Drops the operation and rolls the local copy back to the server's state at the next pull.
  func discardFailed(_ id: UUID) async throws
}

public protocol SyncService: Sendable {
  func status() -> AsyncStream<SyncStatus>
  func syncNow(reason: SyncReason) async
  func start() async
  func stop() async
}

public protocol AuthService: Sendable {
  func sessionStream() -> AsyncStream<AuthSession?>  // first element = restored local session (offline-safe)
  func currentSession() async -> AuthSession?
  func signInWithGoogle() async throws
  /// Native Sign in with Apple (nonce + identity token exchanged with Supabase).
  func signInWithApple() async throws
  func signIn(email: String, password: String) async throws
  func signUp(email: String, password: String) async throws
  func signOut() async throws
  func handleOpenURL(_ url: URL) async -> Bool
}

public struct UserServices: Sendable {
  public var userID: UserID
  public var songs: any SongRepository
  public var tags: any TagRepository
  public var playlists: any PlaylistRepository
  public var settings: any SettingsRepository
  public var teams: any TeamRepository
  public var sharing: any SharingService
  public var conflicts: any ConflictRepository
  public var sync: any SyncService
  public var tearDown: @Sendable (_ eraseLocalData: Bool) async -> Void
  /// Permanently deletes the signed-in account (`delete_user_account` RPC). nil when unavailable
  /// (demo mode, fakes); the shell additionally hides it in release builds.
  public var deleteAccount: (@Sendable () async throws -> Void)?
  /// Inserts into `feedback` like the web form. nil when unavailable (demo mode, fakes).
  public var submitFeedback: (@Sendable (FeedbackDraft) async throws -> Void)?

  public init(
    userID: UserID, songs: any SongRepository, tags: any TagRepository,
    playlists: any PlaylistRepository, settings: any SettingsRepository,
    teams: any TeamRepository, sharing: any SharingService, conflicts: any ConflictRepository,
    sync: any SyncService, tearDown: @escaping @Sendable (_ eraseLocalData: Bool) async -> Void,
    deleteAccount: (@Sendable () async throws -> Void)? = nil,
    submitFeedback: (@Sendable (FeedbackDraft) async throws -> Void)? = nil
  ) {
    self.userID = userID
    self.songs = songs
    self.tags = tags
    self.playlists = playlists
    self.settings = settings
    self.teams = teams
    self.sharing = sharing
    self.conflicts = conflicts
    self.sync = sync
    self.tearDown = tearDown
    self.deleteAccount = deleteAccount
    self.submitFeedback = submitFeedback
  }
}

public struct AppDependencies: Sendable {
  public var config: AppConfig?
  public var isDemo: Bool
  public var auth: any AuthService
  public var makeUserServices: @Sendable (AuthSession) async throws -> UserServices
  /// DEBUG builds only: signs in with the bundled local dev session (nil everywhere else).
  public var devSignIn: (@Sendable () async throws -> Void)?

  public init(
    config: AppConfig?, isDemo: Bool, auth: any AuthService,
    makeUserServices: @escaping @Sendable (AuthSession) async throws -> UserServices,
    devSignIn: (@Sendable () async throws -> Void)? = nil
  ) {
    self.devSignIn = devSignIn
    self.config = config
    self.isDemo = isDemo
    self.auth = auth
    self.makeUserServices = makeUserServices
  }
}
