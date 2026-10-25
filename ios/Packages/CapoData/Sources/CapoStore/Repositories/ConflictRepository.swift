import CapoCore
import Foundation
import GRDB

struct GRDBConflictRepository: ConflictRepository {
  let database: CapoDatabase

  func conflicts() -> AsyncStream<[SongConflict]> {
    database.stream { db in
      try Row.fetchAll(db, sql: "SELECT * FROM conflicts ORDER BY detected_at, id").compactMap {
        row in
        guard let local = try? decodeJSON(Song.self, from: row["local_json"]) else { return nil }
        let server = (row["server_json"] as String?).flatMap { try? decodeJSON(Song.self, from: $0) }
        return SongConflict(
          id: row.uuid("id"), local: local, server: server,
          detectedAt: Date(timeIntervalSince1970: row["detected_at"]))
      }
    }
  }

  func failedOperations() -> AsyncStream<[FailedOperation]> {
    database.stream { db in
      try Row.fetchAll(
        db, sql: "SELECT * FROM outbox WHERE state = 'failed' ORDER BY id"
      ).compactMap { row in
        guard let entry = try? OutboxEntry(row: row) else { return nil }
        return FailedOperation(
          id: entry.opID, kind: Outbox.kind(entry.operation),
          subject: try Self.subject(db, entityKey: entry.operation.entityKey),
          error: entry.lastError, createdAt: entry.createdAt)
      }
    }
  }

  func retryFailed(_ id: UUID) async throws {
    try await database.writer.write { db in
      try db.execute(
        sql: """
          UPDATE outbox SET state = 'pending', attempts = 0, next_attempt_at = 0, last_error = NULL
          WHERE op_id = ? AND state = 'failed'
          """,
        arguments: [id.dbString])
    }
  }

  func discardFailed(_ id: UUID) async throws {
    try await database.writer.write { db in
      guard
        let row = try Row.fetchOne(
          db, sql: "SELECT * FROM outbox WHERE op_id = ? AND state = 'failed'",
          arguments: [id.dbString])
      else { return }
      let entry = try OutboxEntry(row: row)
      try Outbox.delete(db, id: entry.id)
      // The pull diffs by updated_at; blank it so the entity is fetched again (or purged when it
      // never reached the server) instead of keeping the change the server refused.
      let parts = entry.operation.entityKey.split(separator: ":", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return }
      let table = ["song": "songs", "playlist": "playlists"][parts[0]]
      if let table {
        try db.execute(
          sql: "UPDATE \(table) SET updated_at = '' WHERE id = ?", arguments: [parts[1]])
      }
    }
  }

  /// Name shown for an entity key ("song:<id>" -> title).
  private static func subject(_ db: Database, entityKey: String) throws -> String? {
    let parts = entityKey.split(separator: ":", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return nil }
    let lookup: [String: String] = [
      "song": "SELECT title FROM songs WHERE id = ?",
      "playlist": "SELECT name FROM playlists WHERE id = ?",
      "tag": "SELECT name FROM song_tags WHERE id = ?"
    ]
    guard let sql = lookup[parts[0]] else { return nil }
    return try String.fetchOne(db, sql: sql, arguments: [parts[1]])
  }

  func resolve(_ conflictID: UUID, with resolution: ConflictResolution) async throws {
    let userID = database.userID
    try await database.writer.write { db in
      guard
        let conflictRow = try Row.fetchOne(
          db, sql: "SELECT * FROM conflicts WHERE id = ?", arguments: [conflictID.dbString]),
        let outboxRow = try Row.fetchOne(
          db, sql: "SELECT * FROM outbox WHERE op_id = ?", arguments: [conflictID.dbString])
      else { throw CapoError.notFound }

      let entry = try OutboxEntry(row: outboxRow)
      let songID = conflictRow.uuid("song_id")
      let key = OutboxOperation.key("song", songID)
      let server = (conflictRow["server_json"] as String?).flatMap {
        try? decodeJSON(Song.self, from: $0)
      }
      // Later local edits are included: the current row, not the detection-time snapshot.
      let local =
        try GRDBSongRepository.fetchSong(db, id: songID)
        ?? decodeJSON(Song.self, from: conflictRow["local_json"])

      func dropConflict() throws {
        try db.execute(sql: "DELETE FROM conflicts WHERE id = ?", arguments: [conflictID.dbString])
      }

      /// Discard my unsent edits and adopt the server's state (or the deletion).
      func adoptServer() throws {
        try Outbox.delete(db, id: entry.id)
        try dropConflict()
        if let server {
          try Outbox.delete(db, entityKey: key, kind: "updateSong", states: [.pending, .conflict])
          try server.upsert(db)
        } else {
          try Outbox.delete(db, entityKey: key, states: [.pending, .conflict, .failed])
          try Outbox.pruneSongReferences(db, songID: songID)
          try LocalPurge.song(db, id: songID)
        }
      }

      switch resolution {
      case .keepMine:
        let operation: OutboxOperation =
          server.map { .updateSong(id: songID, patch: local.fullPatch, base: $0.updatedAt) }
          ?? .createSong(local)
        try Outbox.replace(db, id: entry.id, with: operation)
        try db.execute(
          sql: """
            UPDATE outbox SET state = 'pending', attempts = 0, next_attempt_at = 0,
              last_error = NULL WHERE id = ?
            """,
          arguments: [entry.id])
        if let server {
          for later in try Outbox.entries(db, entityKey: key, kind: "updateSong", states: [.pending])
          where later.id != entry.id {
            if case .updateSong(let id, let patch, _) = later.operation {
              try Outbox.replace(
                db, id: later.id, with: .updateSong(id: id, patch: patch, base: server.updatedAt))
            }
          }
        }
        try dropConflict()

      case .keepTheirs:
        try adoptServer()

      case .keepBothAsCopy:
        let now = ServerTimestamp.now()
        var copy = local
        copy.id = UUID()
        copy.title = local.title + " (copy)"
        copy.createdBy = userID
        copy.createdAt = now
        copy.updatedAt = now
        let tagIDs = try Row.fetchAll(
          db, sql: "SELECT tag_id FROM song_tag_assignments WHERE song_id = ? ORDER BY tag_id",
          arguments: [songID.dbString]
        ).map { $0.uuid("tag_id") }
        try adoptServer()
        try copy.upsert(db, localModifiedAt: now)
        for tagID in tagIDs {
          try db.execute(
            sql: "INSERT OR IGNORE INTO song_tag_assignments (song_id, tag_id) VALUES (?, ?)",
            arguments: [copy.id.dbString, tagID.dbString])
        }
        try Outbox.enqueue(db, .createSong(copy))
        if !tagIDs.isEmpty { try Outbox.enqueue(db, .setSongTags(songID: copy.id, tagIDs: tagIDs)) }
      }
    }
  }
}
