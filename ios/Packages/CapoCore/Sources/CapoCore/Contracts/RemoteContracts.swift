import Foundation

// Remote contracts: implemented by CapoSupabase and CapoFakes; consumed by CapoSync and CapoStore.

public protocol RemoteSyncSource: Sendable {
  func memberships(userID: UserID) async throws -> [TeamMembership]
  func teams(ids: [TeamID]) async throws -> [Team]
  func songVersions(scope: SyncScope) async throws -> [RowVersion]
  func songs(ids: [SongID]) async throws -> [Song]
  func playlistVersions(scope: SyncScope) async throws -> [RowVersion]
  func playlists(ids: [PlaylistID]) async throws -> [Playlist]
  func playlistEntries(playlistIDs: [PlaylistID]) async throws -> [PlaylistEntry]
  func tags(scope: SyncScope) async throws -> [SongTag]
  func tagAssignments() async throws -> [TagAssignment]  // RLS-scoped to own/team songs
  func userSongSettings(userID: UserID) async throws -> [UserSongSettings]
  func profile(userID: UserID) async throws -> Profile
}

public enum OutboxOperation: Hashable, Sendable, Codable {
  case createSong(Song)
  case updateSong(id: SongID, patch: SongPatch, base: ServerTimestamp)
  case deleteSong(id: SongID)
  case setSongTags(songID: SongID, tagIDs: [TagID])
  case createTag(SongTag)
  case deleteTag(id: TagID)
  case upsertSongSettings(UserSongSettings, userID: UserID)
  case updatePreferences(PreferencesPatch, userID: UserID)
  case createPlaylist(Playlist, songIDs: [SongID])
  case updatePlaylist(id: PlaylistID, patch: PlaylistPatch)
  case deletePlaylist(id: PlaylistID)
  case setPlaylistArchived(id: PlaylistID, archivedAt: ServerTimestamp?)
  case addSongToPlaylist(playlistID: PlaylistID, songID: SongID)
  case removeSongFromPlaylist(playlistID: PlaylistID, songID: SongID)
  case reorderPlaylist(playlistID: PlaylistID, songIDs: [SongID])

  /// "song:<id>", "playlist:<id>", "tag:<id>", "settings:<songID>", "prefs". Ids are lowercased.
  public var entityKey: String {
    switch self {
    case .createSong(let song): return Self.key("song", song.id)
    case .updateSong(let id, _, _), .deleteSong(let id): return Self.key("song", id)
    case .setSongTags(let songID, _): return Self.key("song", songID)
    case .createTag(let tag): return Self.key("tag", tag.id)
    case .deleteTag(let id): return Self.key("tag", id)
    case .upsertSongSettings(let settings, _): return Self.key("settings", settings.songID)
    case .updatePreferences: return "prefs"
    case .createPlaylist(let playlist, _): return Self.key("playlist", playlist.id)
    case .updatePlaylist(let id, _), .deletePlaylist(let id), .setPlaylistArchived(let id, _):
      return Self.key("playlist", id)
    case .addSongToPlaylist(let id, _), .removeSongFromPlaylist(let id, _),
      .reorderPlaylist(let id, _):
      return Self.key("playlist", id)
    }
  }

  public static func key(_ kind: String, _ id: UUID) -> String {
    "\(kind):\(id.uuidString.lowercased())"
  }
}

public enum RemoteApplyResult: Hashable, Sendable {
  case applied(serverSong: Song?)  // createSong/updateSong return the server row
  case conflict(server: Song?)  // updateSong base mismatch (nil = deleted remotely)
  case rejected(CapoError)  // permanent; drop & surface
}

/// A thrown error is transient (retry with backoff).
public protocol RemoteWriter: Sendable {
  func apply(_ op: OutboxOperation) async throws -> RemoteApplyResult
}

public protocol TeamsRemote: Sendable {
  func members(teamID: TeamID) async throws -> [TeamMember]
  func invitations(teamID: TeamID) async throws -> [TeamInvitation]
  func pendingInvitations(email: String) async throws -> [PendingInvitation]
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
  func ensureShareCode(playlistID: PlaylistID) async throws -> String
}

public protocol RealtimeNotifier: Sendable {
  func changes(scope: SyncScope) -> AsyncStream<RealtimeChange>
}

public protocol ReachabilityMonitor: Sendable {
  func isOnline() -> AsyncStream<Bool>
}
