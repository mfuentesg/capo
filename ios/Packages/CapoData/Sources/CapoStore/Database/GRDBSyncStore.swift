import CapoCore
import Foundation
import GRDB

/// `LocalSyncStore` over a `CapoDatabase`.
public struct GRDBSyncStore: LocalSyncStore {
  let database: CapoDatabase

  init(database: CapoDatabase) {
    self.database = database
  }

  public func localVersions(of table: SyncedTable) async throws -> [UUID: ServerTimestamp] {
    try await database.writer.read { db in
      var result: [UUID: ServerTimestamp] = [:]
      for row in try Row.fetchAll(db, sql: "SELECT id, updated_at FROM \(table.rawValue)") {
        result[row.uuid("id")] = row.timestamp("updated_at")
      }
      return result
    }
  }

  public func localPlaylistIDs() async throws -> [PlaylistID] {
    try await database.writer.read { db in
      try Row.fetchAll(db, sql: "SELECT id FROM playlists").map { $0.uuid("id") }
    }
  }

  public func nextPendingOperations(limit: Int, now: Date) async throws -> [OutboxRecord] {
    try await database.writer.read { db in
      // Only the head of each entity's queue is eligible, and only while it is pending: an
      // inflight, conflicted or backed-off head blocks everything behind it.
      let rows = try Row.fetchAll(
        db,
        sql: """
          SELECT o.* FROM outbox o
          WHERE o.state = 'pending' AND o.next_attempt_at <= ?
            AND o.id = (SELECT MIN(id) FROM outbox
                        WHERE entity_key = o.entity_key
                          AND state IN ('pending', 'inflight', 'conflict'))
          ORDER BY o.id LIMIT ?
          """,
        arguments: [now.timeIntervalSince1970, limit])
      return try rows.map { row in
        let entry = try OutboxEntry(row: row)
        return OutboxRecord(
          id: entry.id, opID: entry.opID, operation: entry.operation, attempts: entry.attempts,
          createdAt: entry.createdAt, lastError: entry.lastError)
      }
    }
  }

  public func markInflight(_ id: Int64) async throws {
    try await database.writer.write { db in
      try db.execute(sql: "UPDATE outbox SET state = 'inflight' WHERE id = ?", arguments: [id])
    }
  }

  public func complete(_ id: Int64, outcome: OutboxOutcome) async throws {
    try await database.writer.write { db in
      guard let row = try Row.fetchOne(db, sql: "SELECT * FROM outbox WHERE id = ?", arguments: [id])
      else { return }
      let entry = try OutboxEntry(row: row)
      switch outcome {
      case .applied(let serverSong):
        try Outbox.delete(db, id: id)
        if let serverSong { try Self.rebase(db, onto: serverSong) }
      case .retryLater(let error, let nextAttemptAt):
        try db.execute(
          sql: """
            UPDATE outbox SET state = 'pending', attempts = attempts + 1, last_error = ?,
              next_attempt_at = ? WHERE id = ?
            """,
          arguments: [error, nextAttemptAt.timeIntervalSince1970, id])
      case .rejected(let error):
        try db.execute(
          sql: "UPDATE outbox SET state = 'failed', last_error = ? WHERE id = ?",
          arguments: ["\(error)", id])
      case .conflict(let server):
        try Self.recordConflict(db, entry: entry, server: server)
      }
    }
  }

  /// Takes the server's version stamps onto the local row and rebases queued updates onto it.
  private static func rebase(_ db: Database, onto server: Song) throws {
    let key = OutboxOperation.key("song", server.id)
    try db.execute(
      sql: "UPDATE songs SET updated_at = ?, created_at = ? WHERE id = ?",
      arguments: [server.updatedAt.raw, server.createdAt.raw, server.id.dbString])
    for entry in try Outbox.entries(db, entityKey: key, kind: "updateSong", states: [.pending]) {
      if case .updateSong(let id, let patch, _) = entry.operation {
        try Outbox.replace(
          db, id: entry.id, with: .updateSong(id: id, patch: patch, base: server.updatedAt))
      }
    }
    let stillQueued = try Outbox.entries(db, entityKey: key, states: [.pending, .inflight]).count
    if stillQueued == 0 {
      try db.execute(
        sql: "UPDATE songs SET local_modified_at = NULL WHERE id = ?",
        arguments: [server.id.dbString])
    }
  }

  private static func recordConflict(_ db: Database, entry: OutboxEntry, server: Song?) throws {
    guard case .updateSong(let songID, _, _) = entry.operation,
      let row = try Row.fetchOne(
        db, sql: "SELECT * FROM songs WHERE id = ?", arguments: [songID.dbString])
    else {
      // Not a song edit, or the local song is gone: nothing to resolve by hand.
      try db.execute(
        sql: "UPDATE outbox SET state = 'failed', last_error = 'conflict' WHERE id = ?",
        arguments: [entry.id])
      return
    }
    try db.execute(sql: "UPDATE outbox SET state = 'conflict' WHERE id = ?", arguments: [entry.id])
    try db.execute(
      sql: """
        INSERT OR REPLACE INTO conflicts (id, song_id, local_json, server_json, detected_at)
        VALUES (?, ?, ?, ?, ?)
        """,
      arguments: [
        entry.opID.dbString, songID.dbString, try jsonString(Song(row: row)),
        try server.map { try jsonString($0) }, Date().timeIntervalSince1970
      ])
  }

  public func pendingEntityKeys() async throws -> Set<String> {
    try await database.writer.read { db in
      Set(
        try String.fetchAll(
          db,
          sql: """
            SELECT DISTINCT entity_key FROM outbox
            WHERE state IN ('pending', 'inflight', 'conflict', 'failed')
            """))
    }
  }

  public func outboxChanges() -> AsyncStream<Int> {
    database.stream { db in
      try Int.fetchOne(
        db, sql: "SELECT COUNT(*) FROM outbox WHERE state IN ('pending', 'inflight')") ?? 0
    }
  }

  public func syncMetadata() async throws -> SyncMetadata {
    try await database.writer.read { db in
      guard
        let json = try String.fetchOne(
          db, sql: "SELECT value FROM sync_meta WHERE key = 'sync_metadata'")
      else { return SyncMetadata() }
      return try decodeJSON(SyncMetadata.self, from: json)
    }
  }

  public func saveSyncMetadata(_ metadata: SyncMetadata) async throws {
    try await database.writer.write { db in
      try db.execute(
        sql: "INSERT OR REPLACE INTO sync_meta (key, value) VALUES ('sync_metadata', ?)",
        arguments: [try jsonString(metadata)])
    }
  }

  public func statusCounts() async throws -> (pending: Int, conflicts: Int, failed: Int) {
    try await database.writer.read { db in
      let row = try Row.fetchOne(
        db,
        sql: """
          SELECT
            COALESCE(SUM(state IN ('pending', 'inflight')), 0) AS pending,
            COALESCE(SUM(state = 'conflict'), 0) AS conflicts,
            COALESCE(SUM(state = 'failed'), 0) AS failed
          FROM outbox
          """)
      return (row?["pending"] ?? 0, row?["conflicts"] ?? 0, row?["failed"] ?? 0)
    }
  }
}
