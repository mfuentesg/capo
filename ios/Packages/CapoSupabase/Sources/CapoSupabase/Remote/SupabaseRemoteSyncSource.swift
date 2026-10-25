import CapoCore
import Foundation
import Supabase

public final class SupabaseRemoteSyncSource: RemoteSyncSource {
  private let client: SupabaseClient

  public init(client: SupabaseClient) {
    self.client = client
  }

  public func memberships(userID: UserID) async throws -> [TeamMembership] {
    let rows: [TeamMemberRow] = try await RemoteSupport.paged(TeamMemberRow.self) { from, to in
      client.from("team_members").select().eq("user_id", value: userID.pg).order("id")
        .range(from: from, to: to)
    }
    return rows.map(\.model)
  }

  public func teams(ids: [TeamID]) async throws -> [Team] {
    var result: [Team] = []
    for chunk in RemoteSupport.chunks(ids) {
      let rows: [TeamRow] = try await client.from("teams").select()
        .in("id", values: chunk.map(\.pg)).execute().value
      result.append(contentsOf: rows.map(\.model))
    }
    return result
  }

  public func songVersions(scope: SyncScope) async throws -> [RowVersion] {
    try await versions(table: "songs", scope: scope)
  }

  public func songs(ids: [SongID]) async throws -> [Song] {
    var result: [Song] = []
    for chunk in RemoteSupport.chunks(ids) {
      let rows: [SongRow] = try await client.from("songs").select(SongRow.columns)
        .in("id", values: chunk.map(\.pg)).execute().value
      result.append(contentsOf: rows.map(\.model))
    }
    return result
  }

  public func playlistVersions(scope: SyncScope) async throws -> [RowVersion] {
    try await versions(table: "playlists", scope: scope)
  }

  public func playlists(ids: [PlaylistID]) async throws -> [Playlist] {
    var result: [Playlist] = []
    for chunk in RemoteSupport.chunks(ids) {
      let rows: [PlaylistRow] = try await client.from("playlists").select(PlaylistRow.columns)
        .in("id", values: chunk.map(\.pg)).execute().value
      result.append(contentsOf: rows.map(\.model))
    }
    return result
  }

  public func playlistEntries(playlistIDs: [PlaylistID]) async throws -> [PlaylistEntry] {
    var result: [PlaylistEntry] = []
    for chunk in RemoteSupport.chunks(playlistIDs) {
      let rows: [PlaylistSongRow] = try await RemoteSupport.paged(PlaylistSongRow.self) {
        from, to in
        client.from("playlist_songs").select().in("playlist_id", values: chunk.map(\.pg))
          .order("id").range(from: from, to: to)
      }
      result.append(contentsOf: rows.map(\.model))
    }
    return result
  }

  public func tags(scope: SyncScope) async throws -> [SongTag] {
    let rows: [SongTagRow] = try await RemoteSupport.paged(SongTagRow.self) { from, to in
      client.from("song_tags").select().or(RemoteSupport.scopeFilter(scope)).order("id")
        .range(from: from, to: to)
    }
    return rows.map(\.model)
  }

  public func tagAssignments() async throws -> [TagAssignment] {
    let rows: [SongTagAssignmentRow] = try await RemoteSupport.paged(SongTagAssignmentRow.self) {
      from, to in
      client.from("song_tag_assignments").select().order("song_id").order("tag_id")
        .range(from: from, to: to)
    }
    return rows.map(\.model)
  }

  public func userSongSettings(userID: UserID) async throws -> [UserSongSettings] {
    let rows: [UserSongSettingsRow] = try await RemoteSupport.paged(UserSongSettingsRow.self) {
      from, to in
      client.from("user_song_settings").select().eq("user_id", value: userID.pg).order("id")
        .range(from: from, to: to)
    }
    return rows.map(\.model)
  }

  public func profile(userID: UserID) async throws -> Profile {
    let rows: [ProfileRow] = try await client.from("profiles").select()
      .eq("id", value: userID.pg).limit(1).execute().value
    guard let row = rows.first else { throw CapoError.notFound }
    return row.model
  }

  private func versions(table: String, scope: SyncScope) async throws -> [RowVersion] {
    let rows: [VersionRow] = try await RemoteSupport.paged(VersionRow.self) { from, to in
      client.from(table).select("id,updated_at").or(RemoteSupport.scopeFilter(scope)).order("id")
        .range(from: from, to: to)
    }
    return rows.map { RowVersion(id: $0.id, updatedAt: $0.updatedAt) }
  }
}
