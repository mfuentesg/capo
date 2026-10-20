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
    case .deleteSong(let id):
      try await client.from("songs").delete(returning: .minimal).eq("id", value: id.pg).execute()
      return .applied(serverSong: nil)
    case .setSongTags(let songID, let tagIDs): return try await setSongTags(songID, tagIDs)
    case .createTag(let tag): return try await createTag(tag)
    case .deleteTag(let id):
      try await client.from("song_tags").delete(returning: .minimal).eq("id", value: id.pg)
        .execute()
      return .applied(serverSong: nil)
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
    case .deletePlaylist(let id):
      try await client.from("playlists").delete(returning: .minimal).eq("id", value: id.pg)
        .execute()
      return .applied(serverSong: nil)
    case .setPlaylistArchived(let id, let archivedAt):
      try await client.from("playlists")
        .update(
          ["archived_at": JSONValue.optionalString(archivedAt?.raw)], returning: .minimal
        )
        .eq("id", value: id.pg).execute()
      return .applied(serverSong: nil)
    case .addSongToPlaylist(let playlistID, let songID):
      return try await addSongToPlaylist(playlistID, songID)
    case .removeSongFromPlaylist(let playlistID, let songID):
      try await client.from("playlist_songs").delete(returning: .minimal)
        .eq("playlist_id", value: playlistID.pg).eq("song_id", value: songID.pg).execute()
      return .applied(serverSong: nil)
    case .reorderPlaylist(let playlistID, let songIDs): return try await reorder(playlistID, songIDs)
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

  private func setSongTags(_ songID: SongID, _ tagIDs: [TagID]) async throws -> RemoteApplyResult {
    try await client.from("song_tag_assignments").delete(returning: .minimal)
      .eq("song_id", value: songID.pg).execute()
    if !tagIDs.isEmpty {
      let rows = tagIDs.map { ["song_id": songID.pg, "tag_id": $0.pg] }
      do {
        try await client.from("song_tag_assignments").insert(rows, returning: .minimal).execute()
      } catch where RemoteErrors.isUniqueViolation(error) {}
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
    try await client.from("playlists").update(body, returning: .minimal).eq("id", value: id.pg)
      .execute()
    return .applied(serverSong: nil)
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
      try await withThrowingTaskGroup(of: Void.self) { group in
        for (position, songID) in songIDs.enumerated() {
          group.addTask { [client] in
            try await client.from("playlist_songs")
              .update(["position": JSONValue.number(Double(position + phaseOffset))], returning: .minimal)
              .eq("playlist_id", value: playlistID.pg).eq("song_id", value: songID.pg).execute()
          }
        }
        try await group.waitForAll()
      }
    }
    return .applied(serverSong: nil)
  }
}
