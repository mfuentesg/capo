import CapoCore
import Foundation
import GRDB

extension GRDBSyncStore {
  /// Applies a pull in one transaction. Idempotent; entities with unsent local edits are skipped.
  public func apply(_ batch: PullBatch) async throws {
    try await database.writer.write { db in
      let skip = batch.skipEntityKeys

      if let teams = batch.teams {
        try Self.replaceAll(
          db, table: "teams", keep: teams.map { $0.id.dbString }, key: "id")
        for team in teams {
          try db.execute(
            sql: """
              INSERT OR REPLACE INTO teams (id, name, icon, avatar_url, is_public, created_by,
                created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
              """,
            arguments: [
              team.id.dbString, team.name, team.icon, team.avatarURL, team.isPublic,
              team.createdBy.dbString, team.createdAt.raw, team.updatedAt.raw
            ])
        }
      }
      if let memberships = batch.memberships {
        try Self.replaceAll(
          db, table: "team_members", keep: memberships.map { $0.id.dbString }, key: "id")
        for member in memberships {
          try db.execute(
            sql: """
              INSERT OR REPLACE INTO team_members (id, team_id, user_id, role, joined_at)
              VALUES (?, ?, ?, ?, ?)
              """,
            arguments: [
              member.id.dbString, member.teamID.dbString, member.userID.dbString,
              member.role.rawValue, member.joinedAt.raw
            ])
        }
      }

      for id in batch.deleteSongIDs where !skip.contains(OutboxOperation.key("song", id)) {
        try LocalPurge.song(db, id: id)
      }
      for song in batch.upsertSongs where !skip.contains(OutboxOperation.key("song", song.id)) {
        try song.upsert(db)
      }
      for id in batch.deletePlaylistIDs
      where !skip.contains(OutboxOperation.key("playlist", id)) {
        try LocalPurge.playlist(db, id: id)
      }
      for playlist in batch.upsertPlaylists
      where !skip.contains(OutboxOperation.key("playlist", playlist.id)) {
        try playlist.upsert(db)
      }

      if let entries = batch.playlistEntries {
        let skipped = Self.skippedIDs(skip, prefix: "playlist")
        try Self.deleteAll(db, table: "playlist_songs", column: "playlist_id", except: skipped)
        for entry in entries where !skipped.contains(entry.playlistID.dbString) {
          try db.execute(
            sql: """
              INSERT OR REPLACE INTO playlist_songs (id, playlist_id, song_id, position)
              VALUES (?, ?, ?, ?)
              """,
            arguments: [
              entry.id.dbString, entry.playlistID.dbString, entry.songID.dbString, entry.position
            ])
        }
      }

      if let tags = batch.tags {
        let skipped = Self.skippedIDs(skip, prefix: "tag")
        try Self.deleteAll(db, table: "song_tags", column: "id", except: skipped)
        for tag in tags where !skipped.contains(tag.id.dbString) {
          try tag.upsert(db)
        }
      }

      if let assignments = batch.tagAssignments {
        let skipped = Self.skippedIDs(skip, prefix: "song")
        try Self.deleteAll(db, table: "song_tag_assignments", column: "song_id", except: skipped)
        for assignment in assignments where !skipped.contains(assignment.songID.dbString) {
          try db.execute(
            sql: "INSERT OR IGNORE INTO song_tag_assignments (song_id, tag_id) VALUES (?, ?)",
            arguments: [assignment.songID.dbString, assignment.tagID.dbString])
        }
      }

      if let settings = batch.userSongSettings {
        let skipped = Self.skippedIDs(skip, prefix: "settings")
        try Self.deleteAll(db, table: "user_song_settings", column: "song_id", except: skipped)
        for item in settings where !skipped.contains(item.songID.dbString) {
          try db.execute(
            sql: """
              INSERT OR REPLACE INTO user_song_settings (song_id, transpose, capo, font_size,
                updated_at) VALUES (?, ?, ?, ?, ?)
              """,
            arguments: [
              item.songID.dbString, item.transpose, item.capo, item.fontSize, item.updatedAt?.raw
            ])
        }
      }

      if let profile = batch.profile {
        let keepLocalPreferences = skip.contains("prefs")
        let json = try jsonString(profile.preferences.raw)
        try db.execute(
          sql: """
            INSERT INTO profile (id, email, full_name, avatar_url, preferences_json, updated_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET email = excluded.email, full_name = excluded.full_name,
              avatar_url = excluded.avatar_url, updated_at = excluded.updated_at,
              preferences_json = CASE WHEN ? THEN profile.preferences_json
                                      ELSE excluded.preferences_json END
            """,
          arguments: [
            profile.id.dbString, profile.email, profile.fullName, profile.avatarURL, json,
            profile.updatedAt.raw, keepLocalPreferences
          ])
      }
    }
  }

  /// Entity ids under a `kind:` prefix of the skip set, e.g. "playlist:<id>" -> "<id>".
  private static func skippedIDs(_ keys: Set<String>, prefix: String) -> Set<String> {
    let marker = prefix + ":"
    return Set(keys.compactMap { $0.hasPrefix(marker) ? String($0.dropFirst(marker.count)) : nil })
  }

  private static func replaceAll(
    _ db: Database, table: String, keep: [String], key: String
  ) throws {
    try db.execute(sql: "CREATE TEMP TABLE IF NOT EXISTS _keep (id TEXT PRIMARY KEY NOT NULL)")
    try db.execute(sql: "DELETE FROM _keep")
    for id in keep {
      try db.execute(sql: "INSERT OR IGNORE INTO _keep (id) VALUES (?)", arguments: [id])
    }
    try db.execute(sql: "DELETE FROM \(table) WHERE \(key) NOT IN (SELECT id FROM _keep)")
    try db.execute(sql: "DELETE FROM _keep")
  }

  private static func deleteAll(
    _ db: Database, table: String, column: String, except skipped: Set<String>
  ) throws {
    if skipped.isEmpty {
      try db.execute(sql: "DELETE FROM \(table)")
    } else {
      try db.execute(
        sql: "DELETE FROM \(table) WHERE \(column) NOT IN (\(databaseQuestionMarks(count: skipped.count)))",
        arguments: StatementArguments(Array(skipped)))
    }
  }
}
