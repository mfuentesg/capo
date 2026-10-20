import CapoCore
import Foundation
import GRDB

/// One SQLite database per signed-in user.
public final class CapoDatabase: Sendable {
  public let userID: UserID
  let writer: any DatabaseWriter

  private init(userID: UserID, writer: any DatabaseWriter) throws {
    self.userID = userID
    self.writer = writer
    try Self.migrate(writer)
  }

  public static func open(userID: UserID, directory: URL) throws -> CapoDatabase {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let path = directory.appendingPathComponent("\(userID.dbString).sqlite").path
    return try CapoDatabase(userID: userID, writer: try DatabasePool(path: path))
  }

  public static func inMemory(userID: UserID) throws -> CapoDatabase {
    try CapoDatabase(userID: userID, writer: try DatabaseQueue())
  }

  /// Drops all local data (sign-out with "erase") and recreates the empty schema.
  public func erase() throws {
    try writer.erase()
    try Self.migrate(writer)
  }

  private static func migrate(_ writer: any DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1", migrate: createSchemaV1)
    try migrator.migrate(writer)
    // An operation can only be inflight within one process; anything left over crashed mid-push.
    try writer.write { db in
      try db.execute(sql: "UPDATE outbox SET state = 'pending' WHERE state = 'inflight'")
    }
  }

  /// Re-runs `fetch` whenever any table it reads changes; consecutive duplicates are dropped.
  func stream<T: Sendable & Equatable>(
    _ fetch: @escaping @Sendable (Database) throws -> T
  ) -> AsyncStream<T> {
    let writer = self.writer
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      let task = Task {
        let observation = ValueObservation.tracking(fetch).removeDuplicates()
        do {
          for try await value in observation.values(in: writer) {
            continuation.yield(value)
          }
        } catch {}
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

private func createSchemaV1(_ db: Database) throws {
  try db.execute(
    sql: """
      CREATE TABLE songs (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        artist TEXT,
        "key" TEXT,
        bpm INTEGER,
        lyrics TEXT,
        notes TEXT,
        search_lyrics TEXT NOT NULL DEFAULT '',
        transpose INTEGER NOT NULL DEFAULT 0,
        capo INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        user_id TEXT,
        team_id TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        local_modified_at TEXT
      );
      CREATE INDEX songs_user_id ON songs(user_id);
      CREATE INDEX songs_team_id ON songs(team_id);

      CREATE TABLE song_tags (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        color TEXT,
        user_id TEXT,
        team_id TEXT,
        created_at TEXT NOT NULL
      );

      CREATE TABLE song_tag_assignments (
        song_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (song_id, tag_id)
      );
      CREATE INDEX song_tag_assignments_tag_id ON song_tag_assignments(tag_id);

      CREATE TABLE playlists (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        date TEXT,
        is_public INTEGER NOT NULL DEFAULT 0,
        allow_guest_editing INTEGER NOT NULL DEFAULT 0,
        share_code TEXT,
        share_expires_at TEXT,
        archived_at TEXT,
        user_id TEXT,
        team_id TEXT,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE playlist_songs (
        id TEXT PRIMARY KEY NOT NULL,
        playlist_id TEXT NOT NULL,
        song_id TEXT NOT NULL,
        position INTEGER NOT NULL
      );
      CREATE INDEX playlist_songs_playlist_id ON playlist_songs(playlist_id, position);
      CREATE INDEX playlist_songs_song_id ON playlist_songs(song_id);

      CREATE TABLE teams (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        icon TEXT,
        avatar_url TEXT,
        is_public INTEGER NOT NULL DEFAULT 0,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE TABLE team_members (
        id TEXT PRIMARY KEY NOT NULL,
        team_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        role TEXT NOT NULL,
        joined_at TEXT NOT NULL
      );
      CREATE INDEX team_members_user_id ON team_members(user_id);

      CREATE TABLE user_song_settings (
        song_id TEXT PRIMARY KEY NOT NULL,
        id TEXT,
        transpose INTEGER NOT NULL DEFAULT 0,
        capo INTEGER NOT NULL DEFAULT 0,
        font_size REAL,
        updated_at TEXT
      );

      CREATE TABLE profile (
        id TEXT PRIMARY KEY NOT NULL,
        email TEXT,
        full_name TEXT,
        avatar_url TEXT,
        preferences_json TEXT NOT NULL DEFAULT '{}',
        updated_at TEXT
      );

      CREATE TABLE offline_pins (
        playlist_id TEXT PRIMARY KEY NOT NULL,
        pinned_at REAL NOT NULL
      );

      CREATE TABLE outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        op_id TEXT NOT NULL UNIQUE,
        entity_key TEXT NOT NULL,
        kind TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at REAL NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at REAL NOT NULL
      );
      CREATE INDEX outbox_entity_key ON outbox(entity_key);
      CREATE INDEX outbox_state ON outbox(state);

      CREATE TABLE conflicts (
        id TEXT PRIMARY KEY NOT NULL,
        song_id TEXT NOT NULL,
        local_json TEXT NOT NULL,
        server_json TEXT,
        detected_at REAL NOT NULL
      );
      CREATE INDEX conflicts_song_id ON conflicts(song_id);

      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT
      );
      """)

  try db.create(virtualTable: "songs_fts", using: FTS5()) { t in
    t.synchronize(withTable: "songs")
    t.tokenizer = .unicode61(diacritics: .remove)
    t.column("title")
    t.column("artist")
    t.column("notes")
    t.column("search_lyrics")
  }
}
