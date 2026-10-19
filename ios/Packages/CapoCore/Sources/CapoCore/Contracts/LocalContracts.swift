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
  func acceptInvitation(token: String) async throws -> TeamID
  func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws
  func removeMember(userID: UserID, teamID: TeamID) async throws
  func transferOwnership(teamID: TeamID, to userID: UserID) async throws
}

public protocol SharingService: Sendable {
  func ensureShareCode(playlistID: PlaylistID) async throws -> String  // online, rpc ensure_share_code
  func shareURL(forCode code: String) -> URL  // webBaseURL/playlists/<code>
}

public protocol ConflictRepository: Sendable {
  func conflicts() -> AsyncStream<[SongConflict]>
  func resolve(_ conflictID: UUID, with resolution: ConflictResolution) async throws
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

  public init(
    userID: UserID, songs: any SongRepository, tags: any TagRepository,
    playlists: any PlaylistRepository, settings: any SettingsRepository,
    teams: any TeamRepository, sharing: any SharingService, conflicts: any ConflictRepository,
    sync: any SyncService, tearDown: @escaping @Sendable (_ eraseLocalData: Bool) async -> Void
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
  }
}

public struct AppDependencies: Sendable {
  public var config: AppConfig?
  public var isDemo: Bool
  public var auth: any AuthService
  public var makeUserServices: @Sendable (AuthSession) async throws -> UserServices

  public init(
    config: AppConfig?, isDemo: Bool, auth: any AuthService,
    makeUserServices: @escaping @Sendable (AuthSession) async throws -> UserServices
  ) {
    self.config = config
    self.isDemo = isDemo
    self.auth = auth
    self.makeUserServices = makeUserServices
  }
}
