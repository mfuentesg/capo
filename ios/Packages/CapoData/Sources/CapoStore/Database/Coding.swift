import CapoCore
import Foundation
import GRDB

// UUIDs are stored as lowercase TEXT (matching Postgres), never GRDB's default 16-byte blob.
extension UUID {
  var dbString: String { uuidString.lowercased() }
  static let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}

extension Row {
  func uuid(_ column: String) -> UUID {
    UUID(uuidString: self[column] as String) ?? .zero
  }

  func optionalUUID(_ column: String) -> UUID? {
    guard let string = self[column] as String? else { return nil }
    return UUID(uuidString: string)
  }

  func timestamp(_ column: String) -> ServerTimestamp {
    ServerTimestamp(self[column] as String)
  }

  func optionalTimestamp(_ column: String) -> ServerTimestamp? {
    (self[column] as String?).map(ServerTimestamp.init)
  }
}

func nonEmpty(_ string: String?) -> String? {
  guard let string, !string.isEmpty else { return nil }
  return string
}

/// Lyrics with `[chords]` removed and `{directives}` replaced by a space, for full-text search.
func makeSearchLyrics(_ lyrics: String?) -> String {
  guard let lyrics, !lyrics.isEmpty else { return "" }
  var out = ""
  out.reserveCapacity(lyrics.utf8.count)
  var index = lyrics.startIndex
  while index < lyrics.endIndex {
    let character = lyrics[index]
    let next = lyrics.index(after: index)
    if character == "[", let close = lyrics[next...].firstIndex(of: "]") {
      index = lyrics.index(after: close)
    } else if character == "{", let close = lyrics[next...].firstIndex(of: "}") {
      out.append(" ")
      index = lyrics.index(after: close)
    } else {
      out.append(character)
      index = next
    }
  }
  return out
}

// MARK: - Song

extension Song {
  init(row: Row) {
    self.init(
      id: row.uuid("id"), title: row["title"], artist: row["artist"], key: row["key"],
      bpm: row["bpm"], lyrics: row["lyrics"], notes: row["notes"], transpose: row["transpose"],
      capo: row["capo"], status: SongStatus(rawValue: row["status"]) ?? .published,
      userID: row.optionalUUID("user_id"), teamID: row.optionalUUID("team_id"),
      createdBy: row.uuid("created_by"), createdAt: row.timestamp("created_at"),
      updatedAt: row.timestamp("updated_at"))
  }

  func upsert(_ db: Database, localModifiedAt: ServerTimestamp? = nil) throws {
    try db.execute(
      sql: """
        INSERT INTO songs (id, title, artist, "key", bpm, lyrics, notes, search_lyrics, transpose,
          capo, status, user_id, team_id, created_by, created_at, updated_at, local_modified_at)
        VALUES (:id, :title, :artist, :key, :bpm, :lyrics, :notes, :search, :transpose, :capo,
          :status, :userID, :teamID, :createdBy, :createdAt, :updatedAt, :modified)
        ON CONFLICT(id) DO UPDATE SET title = excluded.title, artist = excluded.artist,
          "key" = excluded."key", bpm = excluded.bpm, lyrics = excluded.lyrics,
          notes = excluded.notes, search_lyrics = excluded.search_lyrics,
          transpose = excluded.transpose, capo = excluded.capo, status = excluded.status,
          user_id = excluded.user_id, team_id = excluded.team_id,
          created_by = excluded.created_by, created_at = excluded.created_at,
          updated_at = excluded.updated_at, local_modified_at = excluded.local_modified_at
        """,
      arguments: [
        "id": id.dbString, "title": title, "artist": artist, "key": key, "bpm": bpm,
        "lyrics": lyrics, "notes": notes, "search": makeSearchLyrics(lyrics),
        "transpose": transpose, "capo": capo, "status": status.rawValue,
        "userID": userID?.dbString, "teamID": teamID?.dbString, "createdBy": createdBy.dbString,
        "createdAt": createdAt.raw, "updatedAt": updatedAt.raw, "modified": localModifiedAt?.raw
      ])
  }

  /// Applies a patch the way the web does: empty string / 0 bpm clear the field.
  mutating func apply(_ patch: SongPatch) {
    if let value = patch.title { title = value }
    if let value = patch.artist { artist = nonEmpty(value) }
    if let value = patch.key { key = nonEmpty(value) }
    if let value = patch.bpm { bpm = value > 0 ? value : nil }
    if let value = patch.lyrics { lyrics = nonEmpty(value) }
    if let value = patch.notes { notes = nonEmpty(value) }
    if let value = patch.transpose { transpose = value }
    if let value = patch.capo { capo = value }
    if let value = patch.status { status = value }
  }

  /// A patch that makes the server row equal to this song (used by "keep mine").
  var fullPatch: SongPatch {
    SongPatch(
      title: title, artist: artist ?? "", key: key ?? "", bpm: bpm ?? 0, lyrics: lyrics ?? "",
      notes: notes ?? "", transpose: transpose, capo: capo, status: status)
  }
}

extension SongTag {
  init(row: Row) {
    self.init(
      id: row.uuid("id"), name: row["name"], color: row["color"],
      userID: row.optionalUUID("user_id"), teamID: row.optionalUUID("team_id"),
      createdAt: row.timestamp("created_at"))
  }

  func upsert(_ db: Database) throws {
    try db.execute(
      sql: """
        INSERT OR REPLACE INTO song_tags (id, name, color, user_id, team_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
      arguments: [
        id.dbString, name, color, userID?.dbString, teamID?.dbString, createdAt.raw
      ])
  }
}

// MARK: - Playlist

extension Playlist {
  init(row: Row) {
    self.init(
      id: row.uuid("id"), name: row["name"], description: row["description"], date: row["date"],
      isPublic: row["is_public"], allowGuestEditing: row["allow_guest_editing"],
      shareCode: row["share_code"], shareExpiresAt: row.optionalTimestamp("share_expires_at"),
      archivedAt: row.optionalTimestamp("archived_at"), userID: row.optionalUUID("user_id"),
      teamID: row.optionalUUID("team_id"), createdBy: row.uuid("created_by"),
      createdAt: row.timestamp("created_at"), updatedAt: row.timestamp("updated_at"))
  }

  func upsert(_ db: Database) throws {
    try db.execute(
      sql: """
        INSERT OR REPLACE INTO playlists (id, name, description, date, is_public,
          allow_guest_editing, share_code, share_expires_at, archived_at, user_id, team_id,
          created_by, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
      arguments: [
        id.dbString, name, description, date, isPublic, allowGuestEditing, shareCode,
        shareExpiresAt?.raw, archivedAt?.raw, userID?.dbString, teamID?.dbString,
        createdBy.dbString, createdAt.raw, updatedAt.raw
      ])
  }
}

extension PlaylistPatch {
  /// Fields set in `newer` win.
  func merged(with newer: PlaylistPatch) -> PlaylistPatch {
    PlaylistPatch(
      name: newer.name ?? name, description: newer.description ?? description,
      date: newer.date ?? date, isPublic: newer.isPublic ?? isPublic,
      allowGuestEditing: newer.allowGuestEditing ?? allowGuestEditing)
  }
}

extension PreferencesPatch {
  func merged(with newer: PreferencesPatch) -> PreferencesPatch {
    PreferencesPatch(
      lyricsColumns: newer.lyricsColumns ?? lyricsColumns, locale: newer.locale ?? locale,
      theme: newer.theme ?? theme, chordHand: newer.chordHand ?? chordHand)
  }
}

// MARK: - Context filters (mirror `applyContextFilter`)

enum ContextFilter {
  /// Personal: `user_id = me AND team_id IS NULL`. Team: `team_id = X AND user_id IS NULL`.
  static func clause(_ context: AppContext, alias: String = "") -> (sql: String, args: [String]) {
    let prefix = alias.isEmpty ? "" : alias + "."
    switch context {
    case .personal(let userID):
      return ("\(prefix)user_id = ? AND \(prefix)team_id IS NULL", [userID.dbString])
    case .team(let teamID):
      return ("\(prefix)team_id = ? AND \(prefix)user_id IS NULL", [teamID.dbString])
    }
  }
}

func jsonString<T: Encodable>(_ value: T) throws -> String {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return String(decoding: try encoder.encode(value), as: UTF8.self)
}

func decodeJSON<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
  try JSONDecoder().decode(type, from: Data(string.utf8))
}
