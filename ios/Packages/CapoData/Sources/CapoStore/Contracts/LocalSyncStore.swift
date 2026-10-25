import CapoCore
import Foundation

// Frozen contract between CapoStore (WP3a) and CapoSync (WP3b). Changes only via WP0.

public enum SyncedTable: String, Sendable, CaseIterable {
  case songs, playlists
}

public struct PullBatch: Sendable {
  public var teams: [Team]?
  public var memberships: [TeamMembership]?
  public var upsertSongs: [Song] = []
  public var deleteSongIDs: [SongID] = []
  public var upsertPlaylists: [Playlist] = []
  public var deletePlaylistIDs: [PlaylistID] = []
  public var playlistEntries: [PlaylistEntry]?
  public var tags: [SongTag]?
  public var tagAssignments: [TagAssignment]?
  public var userSongSettings: [UserSongSettings]?
  public var profile: Profile?
  public var skipEntityKeys: Set<String> = []

  public init(
    teams: [Team]? = nil, memberships: [TeamMembership]? = nil, upsertSongs: [Song] = [],
    deleteSongIDs: [SongID] = [], upsertPlaylists: [Playlist] = [],
    deletePlaylistIDs: [PlaylistID] = [], playlistEntries: [PlaylistEntry]? = nil,
    tags: [SongTag]? = nil, tagAssignments: [TagAssignment]? = nil,
    userSongSettings: [UserSongSettings]? = nil, profile: Profile? = nil,
    skipEntityKeys: Set<String> = []
  ) {
    self.teams = teams
    self.memberships = memberships
    self.upsertSongs = upsertSongs
    self.deleteSongIDs = deleteSongIDs
    self.upsertPlaylists = upsertPlaylists
    self.deletePlaylistIDs = deletePlaylistIDs
    self.playlistEntries = playlistEntries
    self.tags = tags
    self.tagAssignments = tagAssignments
    self.userSongSettings = userSongSettings
    self.profile = profile
    self.skipEntityKeys = skipEntityKeys
  }
}

public struct OutboxRecord: Identifiable, Sendable {
  public var id: Int64
  public var opID: UUID
  public var operation: OutboxOperation
  public var attempts: Int
  public var createdAt: Date
  public var lastError: String?

  public init(
    id: Int64, opID: UUID, operation: OutboxOperation, attempts: Int, createdAt: Date,
    lastError: String?
  ) {
    self.id = id
    self.opID = opID
    self.operation = operation
    self.attempts = attempts
    self.createdAt = createdAt
    self.lastError = lastError
  }
}

public enum OutboxOutcome: Sendable {
  case applied(serverSong: Song?)
  case retryLater(error: String, nextAttemptAt: Date)
  case rejected(CapoError)
  case conflict(server: Song?)
}

public struct SyncMetadata: Codable, Hashable, Sendable {
  public var lastPullAt: Date?
  public var lastPushAt: Date?
  public var lastError: String?

  public init(lastPullAt: Date? = nil, lastPushAt: Date? = nil, lastError: String? = nil) {
    self.lastPullAt = lastPullAt
    self.lastPushAt = lastPushAt
    self.lastError = lastError
  }
}

public protocol LocalSyncStore: Sendable {
  func localVersions(of table: SyncedTable) async throws -> [UUID: ServerTimestamp]
  func localPlaylistIDs() async throws -> [PlaylistID]
  func apply(_ batch: PullBatch) async throws
  func nextPendingOperations(limit: Int, now: Date) async throws -> [OutboxRecord]  // FIFO/entity, skips blocked
  func markInflight(_ id: Int64) async throws
  func complete(_ id: Int64, outcome: OutboxOutcome) async throws
  func pendingEntityKeys() async throws -> Set<String>
  func outboxChanges() -> AsyncStream<Int>  // pending count
  func syncMetadata() async throws -> SyncMetadata
  func saveSyncMetadata(_ metadata: SyncMetadata) async throws
  func statusCounts() async throws -> (pending: Int, conflicts: Int, failed: Int)
}
