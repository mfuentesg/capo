import Foundation

public enum SongStatus: String, Codable, Sendable, CaseIterable {
  case draft, published, archived
}

public struct Song: Identifiable, Hashable, Sendable, Codable {
  public var id: SongID
  public var title: String
  public var artist: String?
  public var key: String?
  public var bpm: Int?
  public var lyrics: String?
  public var notes: String?
  public var transpose: Int
  public var capo: Int
  public var status: SongStatus
  public var userID: UserID?
  public var teamID: TeamID?
  public var createdBy: UserID
  public var createdAt: ServerTimestamp
  public var updatedAt: ServerTimestamp

  public init(
    id: SongID, title: String, artist: String?, key: String?, bpm: Int?, lyrics: String?,
    notes: String?, transpose: Int, capo: Int, status: SongStatus, userID: UserID?,
    teamID: TeamID?, createdBy: UserID, createdAt: ServerTimestamp, updatedAt: ServerTimestamp
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.key = key
    self.bpm = bpm
    self.lyrics = lyrics
    self.notes = notes
    self.transpose = transpose
    self.capo = capo
    self.status = status
    self.userID = userID
    self.teamID = teamID
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct SongTag: Identifiable, Hashable, Sendable, Codable {
  public var id: TagID
  public var name: String
  public var color: String?  // CSS hex; UI default #6b7280
  public var userID: UserID?
  public var teamID: TeamID?
  public var createdAt: ServerTimestamp

  public static let defaultColor = "#6b7280"

  public init(
    id: TagID, name: String, color: String?, userID: UserID?, teamID: TeamID?,
    createdAt: ServerTimestamp
  ) {
    self.id = id
    self.name = name
    self.color = color
    self.userID = userID
    self.teamID = teamID
    self.createdAt = createdAt
  }
}

public struct TagAssignment: Hashable, Sendable, Codable {
  public var songID: SongID
  public var tagID: TagID

  public init(songID: SongID, tagID: TagID) {
    self.songID = songID
    self.tagID = tagID
  }
}

public struct SongListItem: Identifiable, Hashable, Sendable {
  public var id: SongID
  public var title: String
  public var artist: String?
  public var key: String?
  public var bpm: Int?
  public var status: SongStatus
  public var teamID: TeamID?
  public var hasLyrics: Bool
  public var tags: [SongTag]
  public var hasPendingChanges: Bool
  public var createdAt: ServerTimestamp

  public init(
    id: SongID, title: String, artist: String?, key: String?, bpm: Int?, status: SongStatus,
    teamID: TeamID?, hasLyrics: Bool, tags: [SongTag], hasPendingChanges: Bool,
    createdAt: ServerTimestamp
  ) {
    self.id = id
    self.title = title
    self.artist = artist
    self.key = key
    self.bpm = bpm
    self.status = status
    self.teamID = teamID
    self.hasLyrics = hasLyrics
    self.tags = tags
    self.hasPendingChanges = hasPendingChanges
    self.createdAt = createdAt
  }
}

public struct SongDraft: Hashable, Sendable {
  public var title: String
  public var artist: String?
  public var key: String?
  public var bpm: Int?
  public var lyrics: String?
  public var notes: String?
  public var transpose: Int = 0
  public var capo: Int = 0
  public var status: SongStatus = .published

  public init(
    title: String, artist: String? = nil, key: String? = nil, bpm: Int? = nil,
    lyrics: String? = nil, notes: String? = nil, transpose: Int = 0, capo: Int = 0,
    status: SongStatus = .published
  ) {
    self.title = title
    self.artist = artist
    self.key = key
    self.bpm = bpm
    self.lyrics = lyrics
    self.notes = notes
    self.transpose = transpose
    self.capo = capo
    self.status = status
  }
}

/// nil = unchanged. Empty string / 0 bpm = clear (NULL), mirroring web mapFrontendUpdatesToDB.
public struct SongPatch: Hashable, Sendable, Codable {
  public var title: String?
  public var artist: String?
  public var key: String?
  public var bpm: Int?
  public var lyrics: String?
  public var notes: String?
  public var transpose: Int?
  public var capo: Int?
  public var status: SongStatus?

  public init(
    title: String? = nil, artist: String? = nil, key: String? = nil, bpm: Int? = nil,
    lyrics: String? = nil, notes: String? = nil, transpose: Int? = nil, capo: Int? = nil,
    status: SongStatus? = nil
  ) {
    self.title = title
    self.artist = artist
    self.key = key
    self.bpm = bpm
    self.lyrics = lyrics
    self.notes = notes
    self.transpose = transpose
    self.capo = capo
    self.status = status
  }

  /// Fields set in `newer` win; fields it leaves nil keep this patch's value.
  public func merged(with newer: SongPatch) -> SongPatch {
    SongPatch(
      title: newer.title ?? title,
      artist: newer.artist ?? artist,
      key: newer.key ?? key,
      bpm: newer.bpm ?? bpm,
      lyrics: newer.lyrics ?? lyrics,
      notes: newer.notes ?? notes,
      transpose: newer.transpose ?? transpose,
      capo: newer.capo ?? capo,
      status: newer.status ?? status
    )
  }
}
