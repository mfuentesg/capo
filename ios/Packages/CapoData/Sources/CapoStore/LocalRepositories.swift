import CapoCore
import Foundation

/// All local repositories for one signed-in user, bound to one `CapoDatabase`.
public struct LocalRepositories: Sendable {
  public let songs: any SongRepository
  public let tags: any TagRepository
  public let playlists: any PlaylistRepository
  public let settings: any SettingsRepository
  public let teams: any TeamRepository
  public let conflicts: any ConflictRepository
  public let syncStore: any LocalSyncStore

  public init(
    database: CapoDatabase, userID: UserID, teamsRemote: (any TeamsRemote)?,
    onRemoteMutation: @escaping @Sendable () async -> Void
  ) {
    precondition(database.userID == userID, "LocalRepositories user must match the database user")
    songs = GRDBSongRepository(database: database)
    tags = GRDBTagRepository(database: database)
    playlists = GRDBPlaylistRepository(database: database)
    settings = GRDBSettingsRepository(database: database)
    teams = GRDBTeamRepository(
      database: database, remote: teamsRemote, onRemoteMutation: onRemoteMutation)
    conflicts = GRDBConflictRepository(database: database)
    syncStore = GRDBSyncStore(database: database)
  }
}
