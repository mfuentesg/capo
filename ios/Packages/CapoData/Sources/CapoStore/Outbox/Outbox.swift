import CapoCore
import Foundation
import GRDB

enum OutboxState: String {
  case pending, inflight, conflict, failed
}

struct OutboxEntry {
  var id: Int64
  var opID: UUID
  var operation: OutboxOperation
  var state: OutboxState
  var attempts: Int
  var createdAt: Date
  var lastError: String?

  init(row: Row) throws {
    id = row["id"]
    opID = row.uuid("op_id")
    operation = try decodeJSON(OutboxOperation.self, from: row["payload_json"])
    state = OutboxState(rawValue: row["state"]) ?? .pending
    attempts = row["attempts"]
    createdAt = Date(timeIntervalSince1970: row["created_at"])
    lastError = row["last_error"]
  }
}

/// Outbox primitives shared by the repositories and the sync store. All of them run inside the
/// caller's transaction so a local write and its operation commit together.
enum Outbox {
  static func kind(_ operation: OutboxOperation) -> String {
    switch operation {
    case .createSong: return "createSong"
    case .updateSong: return "updateSong"
    case .deleteSong: return "deleteSong"
    case .setSongTags: return "setSongTags"
    case .createTag: return "createTag"
    case .deleteTag: return "deleteTag"
    case .upsertSongSettings: return "upsertSongSettings"
    case .updatePreferences: return "updatePreferences"
    case .createPlaylist: return "createPlaylist"
    case .updatePlaylist: return "updatePlaylist"
    case .deletePlaylist: return "deletePlaylist"
    case .setPlaylistArchived: return "setPlaylistArchived"
    case .addSongToPlaylist: return "addSongToPlaylist"
    case .removeSongFromPlaylist: return "removeSongFromPlaylist"
    case .reorderPlaylist: return "reorderPlaylist"
    }
  }

  @discardableResult
  static func enqueue(_ db: Database, _ operation: OutboxOperation) throws -> Int64 {
    try db.execute(
      sql: """
        INSERT INTO outbox (op_id, entity_key, kind, payload_json, state, created_at)
        VALUES (?, ?, ?, ?, 'pending', ?)
        """,
      arguments: [
        UUID().dbString, operation.entityKey, kind(operation), try jsonString(operation),
        Date().timeIntervalSince1970
      ])
    return db.lastInsertedRowID
  }

  /// Entries for an entity in FIFO order, optionally narrowed by kind and state.
  static func entries(
    _ db: Database, entityKey: String, kind: String? = nil, states: [OutboxState]? = nil
  ) throws -> [OutboxEntry] {
    var sql = "SELECT * FROM outbox WHERE entity_key = ?"
    var arguments: [any DatabaseValueConvertible] = [entityKey]
    if let kind {
      sql += " AND kind = ?"
      arguments.append(kind)
    }
    if let states {
      sql += " AND state IN (\(databaseQuestionMarks(count: states.count)))"
      arguments.append(contentsOf: states.map(\.rawValue))
    }
    sql += " ORDER BY id"
    return try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
      .map(OutboxEntry.init(row:))
  }

  /// Every not-yet-sent entry of the given kinds (any entity), FIFO.
  static func pendingEntries(_ db: Database, kinds: [String]) throws -> [OutboxEntry] {
    try Row.fetchAll(
      db,
      sql: """
        SELECT * FROM outbox WHERE state = 'pending'
          AND kind IN (\(databaseQuestionMarks(count: kinds.count))) ORDER BY id
        """,
      arguments: StatementArguments(kinds)
    ).map(OutboxEntry.init(row:))
  }

  /// The newest operation of `kind` for the entity that has not been sent yet.
  static func latestPending(_ db: Database, entityKey: String, kind: String) throws -> OutboxEntry? {
    try entries(db, entityKey: entityKey, kind: kind, states: [.pending]).last
  }

  static func replace(_ db: Database, id: Int64, with operation: OutboxOperation) throws {
    try db.execute(
      sql: "UPDATE outbox SET payload_json = ?, kind = ?, entity_key = ? WHERE id = ?",
      arguments: [try jsonString(operation), kind(operation), operation.entityKey, id])
  }

  static func delete(_ db: Database, id: Int64) throws {
    try db.execute(sql: "DELETE FROM outbox WHERE id = ?", arguments: [id])
  }

  static func delete(
    _ db: Database, entityKey: String, kind: String? = nil, states: [OutboxState]
  ) throws {
    for entry in try entries(db, entityKey: entityKey, kind: kind, states: states) {
      try delete(db, id: entry.id)
    }
  }

  /// Keeps only the newest unsent op of this kind: removes the older unsent ones.
  static func dropOlderPending(_ db: Database, entityKey: String, kind: String) throws {
    try db.execute(
      sql: "DELETE FROM outbox WHERE entity_key = ? AND kind = ? AND state = 'pending'",
      arguments: [entityKey, kind])
  }

  static func hasPending(_ db: Database, entityKey: String, kind: String) throws -> Bool {
    try !entries(db, entityKey: entityKey, kind: kind, states: [.pending]).isEmpty
  }

  // MARK: Coalescing writers

  /// Merges into an unsent `updateSong` for the same song (keeping its base), else enqueues.
  static func enqueueSongUpdate(
    _ db: Database, id: SongID, patch: SongPatch, base: ServerTimestamp
  ) throws {
    let key = OutboxOperation.key("song", id)
    if let entry = try latestPending(db, entityKey: key, kind: "updateSong"),
      case .updateSong(_, let older, let olderBase) = entry.operation
    {
      try replace(
        db, id: entry.id,
        with: .updateSong(id: id, patch: older.merged(with: patch), base: olderBase))
    } else {
      try enqueue(db, .updateSong(id: id, patch: patch, base: base))
    }
  }

  /// Removes references to a song from unsent playlist/settings operations.
  static func pruneSongReferences(_ db: Database, songID: SongID) throws {
    try delete(
      db, entityKey: OutboxOperation.key("settings", songID), states: [.pending, .failed])
    let kinds = ["addSongToPlaylist", "reorderPlaylist", "createPlaylist"]
    for entry in try pendingEntries(db, kinds: kinds) {
      switch entry.operation {
      case .addSongToPlaylist(_, let id) where id == songID:
        try delete(db, id: entry.id)
      case .reorderPlaylist(let playlistID, let ids) where ids.contains(songID):
        try replace(
          db, id: entry.id,
          with: .reorderPlaylist(playlistID: playlistID, songIDs: ids.filter { $0 != songID }))
      case .createPlaylist(let playlist, let ids) where ids.contains(songID):
        try replace(
          db, id: entry.id,
          with: .createPlaylist(playlist, songIDs: ids.filter { $0 != songID }))
      default:
        break
      }
    }
  }

  static func pruneTagReferences(_ db: Database, tagID: TagID) throws {
    for entry in try pendingEntries(db, kinds: ["setSongTags"]) {
      if case .setSongTags(let songID, let ids) = entry.operation, ids.contains(tagID) {
        try replace(db, id: entry.id, with: .setSongTags(songID: songID, tagIDs: ids.filter { $0 != tagID }))
      }
    }
  }
}

// MARK: - Local deletion helpers

enum LocalPurge {
  static func song(_ db: Database, id: SongID) throws {
    let value = id.dbString
    for table in ["song_tag_assignments", "playlist_songs", "user_song_settings", "conflicts"] {
      try db.execute(sql: "DELETE FROM \(table) WHERE song_id = ?", arguments: [value])
    }
    try db.execute(sql: "DELETE FROM songs WHERE id = ?", arguments: [value])
  }

  static func playlist(_ db: Database, id: PlaylistID) throws {
    let value = id.dbString
    try db.execute(sql: "DELETE FROM playlist_songs WHERE playlist_id = ?", arguments: [value])
    try db.execute(sql: "DELETE FROM offline_pins WHERE playlist_id = ?", arguments: [value])
    try db.execute(sql: "DELETE FROM playlists WHERE id = ?", arguments: [value])
  }

  static func tag(_ db: Database, id: TagID) throws {
    let value = id.dbString
    try db.execute(sql: "DELETE FROM song_tag_assignments WHERE tag_id = ?", arguments: [value])
    try db.execute(sql: "DELETE FROM song_tags WHERE id = ?", arguments: [value])
  }
}
