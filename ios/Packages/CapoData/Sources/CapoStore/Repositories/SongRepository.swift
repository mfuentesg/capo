import CapoCore
import Foundation
import GRDB

struct GRDBSongRepository: SongRepository {
  let database: CapoDatabase

  private var userID: UserID { database.userID }

  func songs(_ query: SongQuery) -> AsyncStream<[SongListItem]> {
    database.stream { db in try Self.fetchList(db, query) }
  }

  func song(id: SongID) -> AsyncStream<Song?> {
    database.stream { db in try Self.fetchSong(db, id: id) }
  }

  func fetchSong(id: SongID) async throws -> Song? {
    try await database.writer.read { db in try Self.fetchSong(db, id: id) }
  }

  func tags(forSong id: SongID) -> AsyncStream<[SongTag]> {
    database.stream { db in
      try Row.fetchAll(
        db,
        sql: """
          SELECT t.* FROM song_tag_assignments a JOIN song_tags t ON t.id = a.tag_id
          WHERE a.song_id = ? ORDER BY t.name COLLATE NOCASE, t.id
          """,
        arguments: [id.dbString]
      ).map(SongTag.init(row:))
    }
  }

  func create(_ draft: SongDraft, in context: AppContext) async throws -> Song {
    let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { throw CapoError.invalidInput("title") }
    let now = ServerTimestamp.now()
    var owner: UserID?
    var team: TeamID?
    switch context {
    case .personal(let id), .all(let id): owner = id
    case .team(let id): team = id
    }
    let song = Song(
      id: UUID(), title: title, artist: nonEmpty(draft.artist), key: nonEmpty(draft.key),
      bpm: draft.bpm.flatMap { $0 > 0 ? $0 : nil }, lyrics: draft.lyrics,
      notes: nonEmpty(draft.notes), transpose: draft.transpose, capo: draft.capo,
      status: draft.status, userID: owner, teamID: team, createdBy: userID, createdAt: now,
      updatedAt: now)
    try await database.writer.write { db in
      try song.upsert(db, localModifiedAt: now)
      try Outbox.enqueue(db, .createSong(song))
    }
    return song
  }

  func update(id: SongID, _ patch: SongPatch) async throws {
    if let title = patch.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw CapoError.invalidInput("title")
    }
    try await database.writer.write { db in
      guard var song = try Self.fetchSong(db, id: id) else { throw CapoError.notFound }
      let base = song.updatedAt
      song.apply(patch)
      try song.upsert(db, localModifiedAt: .now())
      try Outbox.enqueueSongUpdate(db, id: id, patch: patch, base: base)
    }
  }

  func delete(id: SongID) async throws {
    try await database.writer.write { db in
      guard try Self.fetchSong(db, id: id) != nil else { throw CapoError.notFound }
      let key = OutboxOperation.key("song", id)
      let neverPushed = try Outbox.hasPending(db, entityKey: key, kind: "createSong")
      // A delete supersedes every unsent edit; an inflight one is left to finish first.
      try Outbox.delete(db, entityKey: key, states: [.pending, .conflict, .failed])
      try Outbox.pruneSongReferences(db, songID: id)
      try LocalPurge.song(db, id: id)
      if !neverPushed { try Outbox.enqueue(db, .deleteSong(id: id)) }
    }
  }

  func setTags(songID: SongID, tagIDs: [TagID]) async throws {
    try await database.writer.write { db in
      guard try Self.fetchSong(db, id: songID) != nil else { throw CapoError.notFound }
      var seen = Set<TagID>()
      let unique = tagIDs.filter { seen.insert($0).inserted }
      try db.execute(
        sql: "DELETE FROM song_tag_assignments WHERE song_id = ?", arguments: [songID.dbString])
      for tagID in unique {
        try db.execute(
          sql: "INSERT INTO song_tag_assignments (song_id, tag_id) VALUES (?, ?)",
          arguments: [songID.dbString, tagID.dbString])
      }
      let key = OutboxOperation.key("song", songID)
      try Outbox.dropOlderPending(db, entityKey: key, kind: "setSongTags")
      try Outbox.enqueue(db, .setSongTags(songID: songID, tagIDs: unique))
    }
  }

  // MARK: Reads

  static func fetchSong(_ db: Database, id: SongID) throws -> Song? {
    try Row.fetchOne(db, sql: "SELECT * FROM songs WHERE id = ?", arguments: [id.dbString])
      .map(Song.init(row:))
  }

  /// Columns for list rows. Excludes `lyrics` so large bodies are never loaded for lists.
  static let listColumns = """
    s.id, s.title, s.artist, s."key", s.bpm, s.status, s.team_id, s.created_at,
    (s.lyrics IS NOT NULL AND s.lyrics <> '') AS has_lyrics,
    EXISTS (SELECT 1 FROM outbox o WHERE o.entity_key = 'song:' || s.id
            AND o.state IN ('pending', 'inflight', 'conflict')) AS has_pending,
    (SELECT COUNT(*) FROM playlist_songs ps JOIN playlists p ON p.id = ps.playlist_id
       WHERE ps.song_id = s.id AND p.team_id IS s.team_id) AS play_count,
    (SELECT MAX(COALESCE(p.date, p.created_at)) FROM playlist_songs ps
       JOIN playlists p ON p.id = ps.playlist_id
       WHERE ps.song_id = s.id AND p.team_id IS s.team_id) AS last_played
    """

  /// Runs `SELECT <listColumns> <from>` and attaches tags.
  static func fetchListItems(
    _ db: Database, from: String, arguments: StatementArguments
  ) throws -> [SongListItem] {
    let rows = try Row.fetchAll(db, sql: "SELECT \(listColumns) \(from)", arguments: arguments)
    if rows.isEmpty { return [] }
    var tagsBySong: [String: [SongTag]] = [:]
    for row in try Row.fetchAll(
      db,
      sql: """
        SELECT a.song_id AS assigned_song, t.* FROM song_tag_assignments a
        JOIN song_tags t ON t.id = a.tag_id ORDER BY t.name COLLATE NOCASE, t.id
        """)
    {
      tagsBySong[row["assigned_song"], default: []].append(SongTag(row: row))
    }
    return rows.map { row in
      let id = row.uuid("id")
      return SongListItem(
        id: id, title: row["title"], artist: row["artist"], key: row["key"], bpm: row["bpm"],
        status: SongStatus(rawValue: row["status"]) ?? .published,
        teamID: row.optionalUUID("team_id"), hasLyrics: row["has_lyrics"],
        tags: tagsBySong[id.dbString] ?? [], hasPendingChanges: row["has_pending"],
        createdAt: row.timestamp("created_at"), playCount: row["play_count"] ?? 0,
        lastPlayed: row["last_played"])
    }
  }

  static func fetchList(_ db: Database, _ query: SongQuery) throws -> [SongListItem] {
    var conditions: [String] = []
    var arguments: [any DatabaseValueConvertible] = []
    var from = "FROM songs s"

    let pattern =
      query.searchText.isEmpty ? nil : FTS5Pattern(matchingAllPrefixesIn: query.searchText)
    if let pattern {
      from += " JOIN songs_fts ON songs_fts.rowid = s.rowid"
      conditions.append("songs_fts MATCH ?")
      arguments.append(pattern)
    }

    let context = ContextFilter.clause(query.context, alias: "s")
    conditions.append(context.sql)
    arguments.append(contentsOf: context.args)

    let statuses = query.statuses.map(\.rawValue).sorted()
    conditions.append("s.status IN (\(databaseQuestionMarks(count: statuses.count)))")
    arguments.append(contentsOf: statuses)

    if let range = query.bpmRange {
      conditions.append("s.bpm BETWEEN ? AND ?")
      arguments.append(range.lowerBound)
      arguments.append(range.upperBound)
    }
    if !query.tagIDs.isEmpty {
      let tagIDs = query.tagIDs.map(\.dbString).sorted()
      conditions.append(
        """
        s.id IN (SELECT song_id FROM song_tag_assignments
                 WHERE tag_id IN (\(databaseQuestionMarks(count: tagIDs.count)))
                 GROUP BY song_id HAVING COUNT(DISTINCT tag_id) = ?)
        """)
      arguments.append(contentsOf: tagIDs)
      arguments.append(tagIDs.count)
    }

    let collation = DatabaseCollation.localizedCaseInsensitiveCompare.name
    let order: String
    switch query.sort {
    case .recent:
      order = "s.created_at DESC, s.id"
    case .title:
      order = "s.title COLLATE \(collation), s.id"
    case .artist:
      order = "s.artist IS NULL, s.artist COLLATE \(collation), s.title COLLATE \(collation), s.id"
    case .relevance:
      order =
        pattern != nil
        ? "bm25(songs_fts, 10, 5, 2, 1), s.title COLLATE \(collation), s.id"
        : "s.created_at DESC, s.id"
    }

    return try fetchListItems(
      db, from: "\(from) WHERE \(conditions.joined(separator: " AND ")) ORDER BY \(order)",
      arguments: StatementArguments(arguments))
  }
}

struct GRDBTagRepository: TagRepository {
  let database: CapoDatabase

  func tags(in context: AppContext) -> AsyncStream<[SongTag]> {
    database.stream { db in
      let filter = ContextFilter.clause(context)
      return try Row.fetchAll(
        db, sql: "SELECT * FROM song_tags WHERE \(filter.sql) ORDER BY name COLLATE NOCASE, id",
        arguments: StatementArguments(filter.args)
      ).map(SongTag.init(row:))
    }
  }

  func create(name: String, color: String?, in context: AppContext) async throws -> SongTag {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw CapoError.invalidInput("name") }
    var owner: UserID?
    var team: TeamID?
    switch context {
    case .personal(let id), .all(let id): owner = id
    case .team(let id): team = id
    }
    let tag = SongTag(
      id: UUID(), name: name, color: nonEmpty(color), userID: owner, teamID: team,
      createdAt: .now())
    try await database.writer.write { db in
      try tag.upsert(db)
      try Outbox.enqueue(db, .createTag(tag))
    }
    return tag
  }

  func delete(id: TagID) async throws {
    try await database.writer.write { db in
      let key = OutboxOperation.key("tag", id)
      let neverPushed = try Outbox.hasPending(db, entityKey: key, kind: "createTag")
      try Outbox.delete(db, entityKey: key, states: [.pending, .failed])
      try Outbox.pruneTagReferences(db, tagID: id)
      try LocalPurge.tag(db, id: id)
      if !neverPushed { try Outbox.enqueue(db, .deleteTag(id: id)) }
    }
  }
}
