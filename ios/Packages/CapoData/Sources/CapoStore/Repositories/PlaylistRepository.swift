import CapoCore
import Foundation
import GRDB

struct GRDBPlaylistRepository: PlaylistRepository {
  let database: CapoDatabase

  private var userID: UserID { database.userID }

  func playlists(in context: AppContext, includeArchived: Bool) -> AsyncStream<[PlaylistSummary]> {
    database.stream { db in
      let filter = ContextFilter.clause(context, alias: "p")
      let archived = includeArchived ? "" : " AND p.archived_at IS NULL"
      let rows = try Row.fetchAll(
        db,
        sql: """
          SELECT p.*,
            (SELECT COUNT(*) FROM playlist_songs ps WHERE ps.playlist_id = p.id) AS song_count,
            EXISTS (SELECT 1 FROM offline_pins o WHERE o.playlist_id = p.id) AS pinned,
            NOT EXISTS (SELECT 1 FROM playlist_songs ps LEFT JOIN songs s ON s.id = ps.song_id
                        WHERE ps.playlist_id = p.id AND (s.id IS NULL OR s.lyrics IS NULL))
              AS offline_ready
          FROM playlists p WHERE \(filter.sql)\(archived)
          ORDER BY p.date DESC, p.created_at DESC, p.id
          """,
        arguments: StatementArguments(filter.args))
      return rows.map { row in
        PlaylistSummary(
          playlist: Playlist(row: row), songCount: row["song_count"], isPinned: row["pinned"],
          isFullyAvailableOffline: row["offline_ready"])
      }
    }
  }

  func playlist(id: PlaylistID) -> AsyncStream<PlaylistDetail?> {
    database.stream { db in
      guard
        let row = try Row.fetchOne(
          db, sql: "SELECT * FROM playlists WHERE id = ?", arguments: [id.dbString])
      else { return nil }
      let songs = try GRDBSongRepository.fetchListItems(
        db,
        from: """
          FROM playlist_songs ps JOIN songs s ON s.id = ps.song_id
          WHERE ps.playlist_id = ? ORDER BY ps.position, ps.id
          """,
        arguments: [id.dbString])
      let pinned =
        try Int.fetchOne(
          db, sql: "SELECT COUNT(*) FROM offline_pins WHERE playlist_id = ?",
          arguments: [id.dbString]) ?? 0
      return PlaylistDetail(playlist: Playlist(row: row), songs: songs, isPinned: pinned > 0)
    }
  }

  func create(_ draft: PlaylistDraft, in context: AppContext) async throws -> Playlist {
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.count <= PlaylistLimits.name else { throw CapoError.invalidInput("name") }
    if (draft.description ?? "").count > PlaylistLimits.description {
      throw CapoError.invalidInput("description")
    }
    var owner: UserID?
    var team: TeamID?
    switch context {
    case .personal(let id), .all(let id): owner = id
    case .team(let id): team = id
    }
    let now = ServerTimestamp.now()
    let playlist = Playlist(
      id: UUID(), name: name, description: nonEmpty(draft.description), date: nonEmpty(draft.date),
      isPublic: false, allowGuestEditing: false, shareCode: nil, shareExpiresAt: nil,
      archivedAt: nil, userID: owner, teamID: team, createdBy: userID, createdAt: now,
      updatedAt: now)
    var seen = Set<SongID>()
    let songIDs = draft.songIDs.filter { seen.insert($0).inserted }
    let bucketTeam = team
    try await database.writer.write { db in
      try Self.requireSameBucket(db, songIDs, teamID: bucketTeam)
      try playlist.upsert(db)
      for (index, songID) in songIDs.enumerated() {
        try Self.insertEntry(db, playlistID: playlist.id, songID: songID, position: index)
      }
      try Outbox.enqueue(db, .createPlaylist(playlist, songIDs: songIDs))
    }
    return playlist
  }

  func update(id: PlaylistID, _ patch: PlaylistPatch) async throws {
    if let name = patch.name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw CapoError.invalidInput("name")
    }
    if (patch.name ?? "").count > PlaylistLimits.name
      || (patch.description ?? "").count > PlaylistLimits.description
    {
      throw CapoError.invalidInput("length")
    }
    try await database.writer.write { db in
      guard var playlist = try Self.fetchPlaylist(db, id: id) else { throw CapoError.notFound }
      if let value = patch.name { playlist.name = value }
      if let value = patch.description { playlist.description = nonEmpty(value) }
      if let value = patch.date { playlist.date = nonEmpty(value) }
      if let value = patch.isPublic { playlist.isPublic = value }
      if let value = patch.allowGuestEditing { playlist.allowGuestEditing = value }
      try playlist.upsert(db)

      let key = OutboxOperation.key("playlist", id)
      if let entry = try Outbox.latestPending(db, entityKey: key, kind: "updatePlaylist"),
        case .updatePlaylist(_, let older) = entry.operation
      {
        try Outbox.replace(
          db, id: entry.id, with: .updatePlaylist(id: id, patch: older.merged(with: patch)))
      } else {
        try Outbox.enqueue(db, .updatePlaylist(id: id, patch: patch))
      }
    }
  }

  func delete(id: PlaylistID) async throws {
    try await database.writer.write { db in
      guard try Self.fetchPlaylist(db, id: id) != nil else { throw CapoError.notFound }
      let key = OutboxOperation.key("playlist", id)
      let neverPushed = try Outbox.hasPending(db, entityKey: key, kind: "createPlaylist")
      try Outbox.delete(db, entityKey: key, states: [.pending, .failed])
      try LocalPurge.playlist(db, id: id)
      if !neverPushed { try Outbox.enqueue(db, .deletePlaylist(id: id)) }
    }
  }

  func setArchived(id: PlaylistID, _ archived: Bool) async throws {
    try await database.writer.write { db in
      guard var playlist = try Self.fetchPlaylist(db, id: id) else { throw CapoError.notFound }
      let archivedAt: ServerTimestamp? = archived ? .now() : nil
      playlist.archivedAt = archivedAt
      try playlist.upsert(db)
      let key = OutboxOperation.key("playlist", id)
      try Outbox.dropOlderPending(db, entityKey: key, kind: "setPlaylistArchived")
      try Outbox.enqueue(db, .setPlaylistArchived(id: id, archivedAt: archivedAt))
    }
  }

  func addSongs(_ songIDs: [SongID], to playlistID: PlaylistID) async throws {
    try await database.writer.write { db in
      guard let playlist = try Self.fetchPlaylist(db, id: playlistID) else { throw CapoError.notFound }
      try Self.requireSameBucket(db, songIDs, teamID: playlist.teamID)
      var present = Set(
        try Row.fetchAll(
          db, sql: "SELECT song_id FROM playlist_songs WHERE playlist_id = ?",
          arguments: [playlistID.dbString]
        ).map { $0.uuid("song_id") })
      var next =
        (try Int.fetchOne(
          db, sql: "SELECT MAX(position) FROM playlist_songs WHERE playlist_id = ?",
          arguments: [playlistID.dbString]) ?? -1) + 1
      for songID in songIDs where present.insert(songID).inserted {
        try Self.insertEntry(db, playlistID: playlistID, songID: songID, position: next)
        next += 1
        try Outbox.enqueue(db, .addSongToPlaylist(playlistID: playlistID, songID: songID))
      }
    }
  }

  func removeSong(_ songID: SongID, from playlistID: PlaylistID) async throws {
    try await database.writer.write { db in
      try db.execute(
        sql: "DELETE FROM playlist_songs WHERE playlist_id = ? AND song_id = ?",
        arguments: [playlistID.dbString, songID.dbString])
      // Adding then removing before the add was sent cancels out.
      let key = OutboxOperation.key("playlist", playlistID)
      for entry in try Outbox.entries(
        db, entityKey: key, kind: "addSongToPlaylist", states: [.pending])
      {
        if case .addSongToPlaylist(_, let id) = entry.operation, id == songID {
          try Outbox.delete(db, id: entry.id)
          return
        }
      }
      try Outbox.enqueue(db, .removeSongFromPlaylist(playlistID: playlistID, songID: songID))
    }
  }

  func reorder(playlistID: PlaylistID, songIDs: [SongID]) async throws {
    try await database.writer.write { db in
      guard try Self.fetchPlaylist(db, id: playlistID) != nil else { throw CapoError.notFound }
      for (index, songID) in songIDs.enumerated() {
        try db.execute(
          sql: "UPDATE playlist_songs SET position = ? WHERE playlist_id = ? AND song_id = ?",
          arguments: [index, playlistID.dbString, songID.dbString])
      }
      let key = OutboxOperation.key("playlist", playlistID)
      try Outbox.dropOlderPending(db, entityKey: key, kind: "reorderPlaylist")
      try Outbox.enqueue(db, .reorderPlaylist(playlistID: playlistID, songIDs: songIDs))
    }
  }

  func setPinned(_ pinned: Bool, playlistID: PlaylistID) async throws {
    try await database.writer.write { db in
      if pinned {
        try db.execute(
          sql: "INSERT OR REPLACE INTO offline_pins (playlist_id, pinned_at) VALUES (?, ?)",
          arguments: [playlistID.dbString, Date().timeIntervalSince1970])
      } else {
        try db.execute(
          sql: "DELETE FROM offline_pins WHERE playlist_id = ?", arguments: [playlistID.dbString])
      }
    }
  }

  // MARK: Helpers

  /// A playlist only holds songs of its own bucket (personal or one team): teammates cannot read
  /// anyone's personal songs, and the web picker enforces the same.
  static func requireSameBucket(_ db: Database, _ songIDs: [SongID], teamID: TeamID?) throws {
    for songID in songIDs {
      guard
        let row = try Row.fetchOne(
          db, sql: "SELECT team_id FROM songs WHERE id = ?", arguments: [songID.dbString])
      else { continue }
      let songTeam: String? = row["team_id"]
      if songTeam != teamID?.dbString { throw CapoError.invalidInput("bucket") }
    }
  }

  static func fetchPlaylist(_ db: Database, id: PlaylistID) throws -> Playlist? {
    try Row.fetchOne(db, sql: "SELECT * FROM playlists WHERE id = ?", arguments: [id.dbString])
      .map(Playlist.init(row:))
  }

  static func insertEntry(
    _ db: Database, playlistID: PlaylistID, songID: SongID, position: Int
  ) throws {
    try db.execute(
      sql: "INSERT INTO playlist_songs (id, playlist_id, song_id, position) VALUES (?, ?, ?, ?)",
      arguments: [UUID().dbString, playlistID.dbString, songID.dbString, position])
  }
}
