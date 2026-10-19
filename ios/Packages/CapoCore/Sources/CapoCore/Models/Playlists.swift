import Foundation

public struct Playlist: Identifiable, Hashable, Sendable, Codable {
  public var id: PlaylistID
  public var name: String
  public var description: String?
  public var date: String?  // yyyy-MM-dd
  public var isPublic: Bool
  public var allowGuestEditing: Bool
  public var shareCode: String?
  public var shareExpiresAt: ServerTimestamp?
  public var archivedAt: ServerTimestamp?
  public var userID: UserID?
  public var teamID: TeamID?
  public var createdBy: UserID
  public var createdAt: ServerTimestamp
  public var updatedAt: ServerTimestamp

  public init(
    id: PlaylistID, name: String, description: String?, date: String?, isPublic: Bool,
    allowGuestEditing: Bool, shareCode: String?, shareExpiresAt: ServerTimestamp?,
    archivedAt: ServerTimestamp?, userID: UserID?, teamID: TeamID?, createdBy: UserID,
    createdAt: ServerTimestamp, updatedAt: ServerTimestamp
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.date = date
    self.isPublic = isPublic
    self.allowGuestEditing = allowGuestEditing
    self.shareCode = shareCode
    self.shareExpiresAt = shareExpiresAt
    self.archivedAt = archivedAt
    self.userID = userID
    self.teamID = teamID
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct PlaylistEntry: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID
  public var playlistID: PlaylistID
  public var songID: SongID
  public var position: Int

  public init(id: UUID, playlistID: PlaylistID, songID: SongID, position: Int) {
    self.id = id
    self.playlistID = playlistID
    self.songID = songID
    self.position = position
  }
}

public struct PlaylistSummary: Identifiable, Hashable, Sendable {
  public var playlist: Playlist
  public var songCount: Int
  public var isPinned: Bool
  public var isFullyAvailableOffline: Bool
  public var id: PlaylistID { playlist.id }

  public init(playlist: Playlist, songCount: Int, isPinned: Bool, isFullyAvailableOffline: Bool) {
    self.playlist = playlist
    self.songCount = songCount
    self.isPinned = isPinned
    self.isFullyAvailableOffline = isFullyAvailableOffline
  }
}

public struct PlaylistDetail: Hashable, Sendable {
  public var playlist: Playlist
  public var songs: [SongListItem]  // ordered by position
  public var isPinned: Bool

  public init(playlist: Playlist, songs: [SongListItem], isPinned: Bool) {
    self.playlist = playlist
    self.songs = songs
    self.isPinned = isPinned
  }
}

public struct PlaylistDraft: Hashable, Sendable {
  public var name: String
  public var description: String?
  public var date: String?
  public var songIDs: [SongID] = []

  public init(name: String, description: String? = nil, date: String? = nil, songIDs: [SongID] = []) {
    self.name = name
    self.description = description
    self.date = date
    self.songIDs = songIDs
  }
}

public struct PlaylistPatch: Hashable, Sendable, Codable {
  public var name: String?
  public var description: String?
  public var date: String?
  public var isPublic: Bool?
  public var allowGuestEditing: Bool?

  public init(
    name: String? = nil, description: String? = nil, date: String? = nil, isPublic: Bool? = nil,
    allowGuestEditing: Bool? = nil
  ) {
    self.name = name
    self.description = description
    self.date = date
    self.isPublic = isPublic
    self.allowGuestEditing = allowGuestEditing
  }
}
