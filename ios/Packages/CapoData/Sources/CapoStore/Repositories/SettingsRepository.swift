import CapoCore
import Foundation
import GRDB

struct GRDBSettingsRepository: SettingsRepository {
  let database: CapoDatabase

  private var userID: UserID { database.userID }

  func songSettings(songID: SongID) -> AsyncStream<UserSongSettings?> {
    database.stream { db in
      try Row.fetchOne(
        db, sql: "SELECT * FROM user_song_settings WHERE song_id = ?",
        arguments: [songID.dbString]
      ).map { row in
        UserSongSettings(
          songID: row.uuid("song_id"), transpose: row["transpose"], capo: row["capo"],
          fontSize: row["font_size"], updatedAt: row.optionalTimestamp("updated_at"))
      }
    }
  }

  func saveSongSettings(_ settings: UserSongSettings) async throws {
    guard EffectiveSongSettings.transposeRange.contains(settings.transpose),
      EffectiveSongSettings.capoRange.contains(settings.capo),
      settings.fontSize.map(EffectiveSongSettings.fontSizeRange.contains) ?? true
    else { throw CapoError.invalidInput("settings out of range") }

    let stamped: UserSongSettings = {
      var copy = settings
      copy.updatedAt = .now()  // client-authored LWW value
      return copy
    }()
    let userID = self.userID
    try await database.writer.write { db in
      try db.execute(
        sql: """
          INSERT INTO user_song_settings (song_id, transpose, capo, font_size, updated_at)
          VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(song_id) DO UPDATE SET transpose = excluded.transpose,
            capo = excluded.capo, font_size = excluded.font_size,
            updated_at = excluded.updated_at
          """,
        arguments: [
          stamped.songID.dbString, stamped.transpose, stamped.capo, stamped.fontSize,
          stamped.updatedAt?.raw
        ])
      let key = OutboxOperation.key("settings", stamped.songID)
      try Outbox.dropOlderPending(db, entityKey: key, kind: "upsertSongSettings")
      try Outbox.enqueue(db, .upsertSongSettings(stamped, userID: userID))
    }
  }

  func preferences() -> AsyncStream<UserPreferences> {
    database.stream { db in try Self.fetchPreferences(db) }
  }

  func updatePreferences(_ patch: PreferencesPatch) async throws {
    let userID = self.userID
    try await database.writer.write { db in
      let current = try Self.fetchPreferences(db)
      let json = try jsonString(current.json(applying: patch))
      try db.execute(
        sql: """
          INSERT INTO profile (id, preferences_json, updated_at) VALUES (?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET preferences_json = excluded.preferences_json,
            updated_at = excluded.updated_at
          """,
        arguments: [userID.dbString, json, ServerTimestamp.now().raw])
      // Keep one op, but merge patches so edits to different keys are not lost.
      var merged = patch
      if let entry = try Outbox.latestPending(db, entityKey: "prefs", kind: "updatePreferences"),
        case .updatePreferences(let older, _) = entry.operation
      {
        merged = older.merged(with: patch)
      }
      try Outbox.dropOlderPending(db, entityKey: "prefs", kind: "updatePreferences")
      try Outbox.enqueue(db, .updatePreferences(merged, userID: userID))
    }
  }

  static func fetchPreferences(_ db: Database) throws -> UserPreferences {
    guard
      let json = try String.fetchOne(db, sql: "SELECT preferences_json FROM profile LIMIT 1"),
      let raw = try? decodeJSON([String: JSONValue].self, from: json)
    else { return .default }
    return UserPreferences(json: raw)
  }
}
