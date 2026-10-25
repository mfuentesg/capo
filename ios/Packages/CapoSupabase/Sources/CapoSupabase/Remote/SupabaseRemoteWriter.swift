import CapoCore
import Foundation
import Supabase

public final class SupabaseRemoteWriter: RemoteWriter {
  private let client: SupabaseClient

  public init(client: SupabaseClient) {
    self.client = client
  }

  /// Applies one outbox operation. Permanent failures return `.rejected`; anything transient
  /// (network, 5xx, unrecognised) is rethrown so the outbox retries.
  public func apply(_ op: OutboxOperation) async throws -> RemoteApplyResult {
    do {
      return try await perform(op)
    } catch {
      if let rejection = RemoteErrors.rejection(for: error) { return .rejected(rejection) }
      throw error
    }
  }

  private func perform(_ op: OutboxOperation) async throws -> RemoteApplyResult {
    switch op {
    case .createSong(let song): return try await createSong(song)
    case .updateSong(let id, let patch, let base): return try await updateSong(id, patch, base)
    case .deleteSong(let id): return try await deleteRows("songs", [("id", id.pg)])
    case .setSongTags(let songID, let tagIDs): return try await setSongTags(songID, tagIDs)
    case .createTag(let tag): return try await createTag(tag)
    case .deleteTag(let id): return try await deleteRows("song_tags", [("id", id.pg)])
    case .upsertSongSettings(let settings, let userID):
      try await client.from("user_song_settings")
        .upsert(
          UserSongSettingsRow.upsertPayload(settings, userID: userID),
          onConflict: "user_id,song_id", returning: .minimal
        )
        .execute()
      return .applied(serverSong: nil)
    case .updatePreferences(let patch, let userID): return try await updatePreferences(patch, userID)
    case .createPlaylist(let playlist, let songIDs): return try await createPlaylist(playlist, songIDs)
    case .updatePlaylist(let id, let patch): return try await updatePlaylist(id, patch)
    case .deletePlaylist(let id): return try await deleteRows("playlists", [("id", id.pg)])
    case .setPlaylistArchived(let id, let archivedAt):
      return try await updatePlaylistRow(
        id, ["archived_at": JSONValue.optionalString(archivedAt?.raw)])
    case .addSongToPlaylist(let playlistID, let songID):
      return try await addSongToPlaylist(playlistID, songID)
    case .removeSongFromPlaylist(let playlistID, let songID):
      return try await deleteRows(
        "playlist_songs", [("playlist_id", playlistID.pg), ("song_id", songID.pg)],
        column: "playlist_id")
    case .reorderPlaylist(let playlistID, let songIDs): return try await reorder(playlistID, songIDs)
    }
  }

  // MARK: Silent RLS rejections

  /// A row that RLS hides from UPDATE/DELETE is "affected" by zero rows with no error. Zero rows
  /// is only success when the row is really gone; if it is still visible the write was refused.
  private struct Touched: Decodable {}

  private func verdict(touched: Int, stillThere: () async throws -> Bool) async throws
    -> RemoteApplyResult
  {
    if touched > 0 { return .applied(serverSong: nil) }
    return try await stillThere() ? .rejected(.permissionDenied) : .applied(serverSong: nil)
  }

  private func exists(_ table: String, _ filters: [(String, String)], column: String) async throws
    -> Bool
  {
    var query = client.from(table).select(column)
    for (name, value) in filters { query = query.eq(name, value: value) }
    let rows: [Touched] = try await query.limit(1).execute().value
    return !rows.isEmpty
  }

  private func deleteRows(_ table: String, _ filters: [(String, String)], column: String = "id")
    async throws -> RemoteApplyResult
  {
    var query = client.from(table).delete()
    for (name, value) in filters { query = query.eq(name, value: value) }
    let rows: [Touched] = try await query.select(column).execute().value
    return try await verdict(touched: rows.count) {
      try await exists(table, filters, column: column)
    }
  }

  private func updatePlaylistRow(_ id: PlaylistID, _ body: [String: JSONValue]) async throws
    -> RemoteApplyResult
  {
    let rows: [Touched] = try await client.from("playlists").update(body)
      .eq("id", value: id.pg).select("id").execute().value
    return try await verdict(touched: rows.count) {
      try await exists("playlists", [("id", id.pg)], column: "id")
    }
  }

  // MARK: Songs

  private func createSong(_ song: Song) async throws -> RemoteApplyResult {
    do {
      let rows: [SongRow] = try await client.from("songs")
        .insert(SongRow.insertPayload(song), returning: .representation)
        .select(SongRow.columns).execute().value
      if let row = rows.first { return .applied(serverSong: row.model) }
    } catch where RemoteErrors.isUniqueViolation(error) {
      // Replay of an insert that already landed.
    }
    return .applied(serverSong: try await fetchSong(song.id))
  }

  private func updateSong(_ id: SongID, _ patch: SongPatch, _ base: ServerTimestamp) async throws
    -> RemoteApplyResult
  {
    let body = SongRow.updatePayload(patch)
    guard !body.isEmpty else { return .applied(serverSong: try await fetchSong(id)) }

    let rows: [SongRow] = try await client.from("songs")
      .update(body, returning: .representation)
      .eq("id", value: id.pg).eq("updated_at", value: base.raw)
      .select(SongRow.columns).execute().value
    if let row = rows.first { return .applied(serverSong: row.model) }

    // Nothing matched: either someone else wrote first, the row is gone, or RLS hides/forbids it.
    guard let server = try await fetchSong(id) else { return .conflict(server: nil) }
    if server.updatedAt == base { return .rejected(.permissionDenied) }
    return .conflict(server: server)
  }

  private func fetchSong(_ id: SongID) async throws -> Song? {
    let rows: [SongRow] = try await client.from("songs").select(SongRow.columns)
      .eq("id", value: id.pg).limit(1).execute().value
    return rows.first?.model
  }

  private struct AssignmentRow: Decodable {
    let tagID: UUID
    enum CodingKeys: String, CodingKey { case tagID = "tag_id" }
  }

  /// Adds the missing assignments first and only then removes the stale ones, so a rejected
  /// insert never leaves the song without its server tags.
  private func setSongTags(_ songID: SongID, _ tagIDs: [TagID]) async throws -> RemoteApplyResult {
    let current: [AssignmentRow] = try await client.from("song_tag_assignments").select("tag_id")
      .eq("song_id", value: songID.pg).execute().value
    let have = Set(current.map(\.tagID))
    let want = Set(tagIDs)
    let missing = want.subtracting(have)
    let stale = have.subtracting(want)
    if !missing.isEmpty {
      let rows = missing.map { ["song_id": songID.pg, "tag_id": $0.pg] }
      do {
        try await client.from("song_tag_assignments").insert(rows, returning: .minimal).execute()
      } catch where RemoteErrors.isUniqueViolation(error) {}
    }
    if !stale.isEmpty {
      let removed: [Touched] = try await client.from("song_tag_assignments").delete()
        .eq("song_id", value: songID.pg).in("tag_id", values: stale.map(\.pg))
        .select("tag_id").execute().value
      if removed.isEmpty { return .rejected(.permissionDenied) }
    }
    return .applied(serverSong: nil)
  }

  private func createTag(_ tag: SongTag) async throws -> RemoteApplyResult {
    do {
      try await client.from("song_tags").insert(SongTagRow.insertPayload(tag), returning: .minimal)
        .execute()
    } catch where RemoteErrors.isUniqueViolation(error) {
      // Same id already there (replay) counts as applied; a name clash with another id does not.
      let rows: [SongTagRow] = try await client.from("song_tags").select()
        .eq("id", value: tag.id.pg).limit(1).execute().value
      if rows.isEmpty { return .rejected(.invalidInput("tag name already exists")) }
    }
    return .applied(serverSong: nil)
  }

  // MARK: Preferences

  private func updatePreferences(_ patch: PreferencesPatch, _ userID: UserID) async throws
    -> RemoteApplyResult
  {
    let rows: [ProfileRow] = try await client.from("profiles").select()
      .eq("id", value: userID.pg).limit(1).execute().value
    guard let profile = rows.first else { return .rejected(.notFound) }
    let merged = UserPreferences(json: profile.preferences ?? [:]).json(applying: patch)
    try await client.from("profiles")
      .update(["preferences": JSONValue.object(merged)], returning: .minimal)
      .eq("id", value: userID.pg).execute()
    return .applied(serverSong: nil)
  }

  // MARK: Playlists

  static let shareCodeAlphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")

  static func generateShareCode(length: Int = 12) -> String {
    String((0..<length).map { _ in shareCodeAlphabet.randomElement()! })
  }

  private func createPlaylist(_ playlist: Playlist, _ songIDs: [SongID]) async throws
    -> RemoteApplyResult
  {
    var shareCode = playlist.shareCode ?? Self.generateShareCode()
    var attempts = 0
    while true {
      do {
        try await client.from("playlists")
          .insert(PlaylistRow.insertPayload(playlist, shareCode: shareCode), returning: .minimal)
          .execute()
        break
      } catch where RemoteErrors.isUniqueViolation(error) {
        // Replay (same id) or a share-code collision; only the latter needs a new code.
        if try await playlistExists(playlist.id) { break }
        attempts += 1
        if attempts >= 3 { throw error }
        shareCode = Self.generateShareCode()
      }
    }

    guard !songIDs.isEmpty else { return .applied(serverSong: nil) }
    let existing: [PlaylistSongRow] = try await client.from("playlist_songs").select()
      .eq("playlist_id", value: playlist.id.pg).execute().value
    let present = Set(existing.map(\.songID))
    let missing = songIDs.enumerated().filter { !present.contains($0.element) }
    if !missing.isEmpty {
      let payload: [[String: JSONValue]] = missing.map {
        [
          "playlist_id": .string(playlist.id.pg), "song_id": .string($0.element.pg),
          "position": .number(Double($0.offset))
        ]
      }
      do {
        try await client.from("playlist_songs").insert(payload, returning: .minimal).execute()
      } catch where RemoteErrors.isUniqueViolation(error) {}
    }
    return .applied(serverSong: nil)
  }

  private func playlistExists(_ id: PlaylistID) async throws -> Bool {
    let rows: [VersionRow] = try await client.from("playlists").select("id,updated_at")
      .eq("id", value: id.pg).limit(1).execute().value
    return !rows.isEmpty
  }

  private func updatePlaylist(_ id: PlaylistID, _ patch: PlaylistPatch) async throws
    -> RemoteApplyResult
  {
    var body = PlaylistRow.updatePayload(patch)
    guard !body.isEmpty else { return .applied(serverSong: nil) }
    if patch.isPublic == true {
      // Public playlists must carry a share code (web does the same before updating).
      let rows: [PlaylistRow] = try await client.from("playlists").select(PlaylistRow.columns)
        .eq("id", value: id.pg).limit(1).execute().value
      if let current = rows.first, current.shareCode == nil {
        body["share_code"] = .string(Self.generateShareCode())
      }
    }
    return try await updatePlaylistRow(id, body)
  }

  private func addSongToPlaylist(_ playlistID: PlaylistID, _ songID: SongID) async throws
    -> RemoteApplyResult
  {
    do {
      try await client.rpc(
        "add_song_to_playlist",
        params: ["p_playlist_id": playlistID.pg, "p_song_id": songID.pg]
      ).execute()
    } catch where RemoteErrors.isUniqueViolation(error) {}
    return .applied(serverSong: nil)
  }

  /// Two phases (final + 10000, then final) so `(playlist_id, position)` is never duplicated.
  private func reorder(_ playlistID: PlaylistID, _ songIDs: [SongID]) async throws
    -> RemoteApplyResult
  {
    let offset = 10000
    for phaseOffset in [offset, 0] {
      let touched = try await withThrowingTaskGroup(of: Int.self) { group in
        for (position, songID) in songIDs.enumerated() {
          group.addTask { [client] in
            let rows: [Touched] = try await client.from("playlist_songs")
              .update(["position": JSONValue.number(Double(position + phaseOffset))])
              .eq("playlist_id", value: playlistID.pg).eq("song_id", value: songID.pg)
              .select("playlist_id").execute().value
            return rows.count
          }
        }
        return try await group.reduce(0, +)
      }
      if touched == 0, !songIDs.isEmpty {
        let result = try await verdict(touched: 0) {
          try await exists(
            "playlist_songs", [("playlist_id", playlistID.pg)], column: "playlist_id")
        }
        if case .rejected = result { return result }
      }
    }
    return .applied(serverSong: nil)
  }
}
