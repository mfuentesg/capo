import CapoCore
import Foundation
import Testing

@testable import CapoSupabase

@Suite struct WriterTests {
  private func writer(_ server: StubServer) -> SupabaseRemoteWriter {
    SupabaseRemoteWriter(client: makeClient(server))
  }

  @Test func createSongInsertsWithClientId() async throws {
    let server = StubServer()
    server.handle { _ in .json(201, "[" + songRowJSON() + "]") }
    let result = try await writer(server).apply(.createSong(makeSong()))
    guard case .applied(let song?) = result else { Issue.record("not applied"); return }
    #expect(song.id == Ids.song)
    let request = try #require(server.restRequests.first)
    #expect(request.method == "POST" && request.path == "/rest/v1/songs")
    #expect(request.jsonObject?["id"] as? String == Ids.song.pg)
    #expect(request.header("Prefer")?.contains("return=representation") == true)
  }

  @Test func duplicateCreateRefetchesAndCountsAsApplied() async throws {
    let server = StubServer()
    server.sequence([
      .postgrestError(409, code: "23505"),
      .ok("[" + songRowJSON() + "]")
    ])
    let result = try await writer(server).apply(.createSong(makeSong()))
    guard case .applied(let song?) = result else { Issue.record("not applied"); return }
    #expect(song.title == "Amazing Grace")
    #expect(server.restRequests.map(\.method) == ["POST", "GET"])
  }

  @Test func updateSuccessReturnsServerRow() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[" + songRowJSON(updatedAt: "2024-05-02T00:00:00+00:00") + "]") }
    let result = try await writer(server).apply(
      .updateSong(
        id: Ids.song, patch: SongPatch(title: "New"),
        base: ServerTimestamp("2024-05-01T10:00:00.123456+00:00")))
    guard case .applied(let song?) = result else { Issue.record("not applied"); return }
    #expect(song.updatedAt.raw == "2024-05-02T00:00:00+00:00")
    let request = try #require(server.restRequests.first)
    #expect(request.query["id"] == "eq.\(Ids.song.pg)")
    #expect(request.query["updated_at"] == "eq.2024-05-01T10:00:00.123456+00:00")
    #expect(request.jsonObject?["title"] as? String == "New")
  }

  @Test func emptyPatchResultFetchesServerRowAndReportsConflict() async throws {
    let server = StubServer()
    server.sequence([
      .ok("[]"), .ok("[" + songRowJSON(updatedAt: "2024-06-01T00:00:00+00:00") + "]")
    ])
    let result = try await writer(server).apply(
      .updateSong(
        id: Ids.song, patch: SongPatch(title: "Mine"),
        base: ServerTimestamp("2024-05-01T10:00:00.123456+00:00")))
    guard case .conflict(let server?) = result else { Issue.record("not conflict"); return }
    #expect(server.updatedAt.raw == "2024-06-01T00:00:00+00:00")
  }

  @Test func updateOfDeletedSongIsConflictWithNilServer() async throws {
    let server = StubServer()
    server.sequence([.ok("[]"), .ok("[]")])
    let result = try await writer(server).apply(
      .updateSong(
        id: Ids.song, patch: SongPatch(title: "x"), base: ServerTimestamp("2024-05-01T10:00:00Z")))
    #expect(result == .conflict(server: nil))
  }

  @Test func unchangedServerRowMeansPermissionDenied() async throws {
    let server = StubServer()
    server.sequence([.ok("[]"), .ok("[" + songRowJSON() + "]")])
    let result = try await writer(server).apply(
      .updateSong(
        id: Ids.song, patch: SongPatch(title: "x"),
        base: ServerTimestamp("2024-05-01T10:00:00.123456+00:00")))
    #expect(result == .rejected(.permissionDenied))
  }

  @Test(arguments: [
    (401, "PGRST301", CapoError.permissionDenied),
    (403, "42501", CapoError.permissionDenied),
    (400, "23514", CapoError.invalidInput("error")),
    (400, "22P02", CapoError.invalidInput("error"))
  ])
  func permanentErrorsAreRejected(status: Int, code: String, expected: CapoError) async throws {
    let server = StubServer()
    server.handle { _ in .postgrestError(status, code: code) }
    let result = try await writer(server).apply(.deleteSong(id: Ids.song))
    #expect(result == .rejected(expected))
  }

  @Test func serverErrorsAndNetworkFailuresThrow() async throws {
    let failing = StubServer()
    failing.handle { _ in .postgrestError(500, code: "XX000") }
    await #expect(throws: Error.self) { try await writer(failing).apply(.deleteSong(id: Ids.song)) }

    let offline = StubServer()
    offline.handle { _ in .failure(.notConnectedToInternet) }
    await #expect(throws: Error.self) { try await writer(offline).apply(.deleteSong(id: Ids.song)) }
  }

  @Test func reorderRunsOffsetPhaseBeforeFinalPhase() async throws {
    let server = StubServer()
    server.handle { _ in .json(204, "") }
    _ = try await writer(server).apply(
      .reorderPlaylist(playlistID: Ids.playlist, songIDs: [Ids.song2, Ids.song]))
    let positions = server.restRequests.compactMap { ($0.jsonObject?["position"] as? NSNumber)?.intValue }
    #expect(positions.count == 4)
    #expect(Set(positions[0..<2]) == [10000, 10001])
    #expect(Set(positions[2..<4]) == [0, 1])
  }

  @Test func addSongToPlaylistUsesRpcAndTreatsDuplicateAsApplied() async throws {
    let server = StubServer()
    server.handle { _ in .postgrestError(409, code: "23505") }
    let result = try await writer(server).apply(
      .addSongToPlaylist(playlistID: Ids.playlist, songID: Ids.song))
    #expect(result == .applied(serverSong: nil))
    let request = try #require(server.restRequests.first)
    #expect(request.path == "/rest/v1/rpc/add_song_to_playlist")
    #expect(request.jsonObject?["p_playlist_id"] as? String == Ids.playlist.pg)
  }

  @Test func setSongTagsDeletesThenInserts() async throws {
    let server = StubServer()
    server.handle { _ in .json(204, "") }
    _ = try await writer(server).apply(.setSongTags(songID: Ids.song, tagIDs: [Ids.tag]))
    #expect(server.restRequests.map(\.method) == ["DELETE", "POST"])
    #expect(server.restRequests[1].jsonArray?.first?["tag_id"] as? String == Ids.tag.pg)
  }

  @Test func upsertSettingsUsesCompositeConflictTarget() async throws {
    let server = StubServer()
    server.handle { _ in .json(201, "") }
    let settings = UserSongSettings(
      songID: Ids.song, transpose: 2, capo: 1, fontSize: 1.5,
      updatedAt: ServerTimestamp("2024-07-01T00:00:00.000Z"))
    _ = try await writer(server).apply(.upsertSongSettings(settings, userID: Ids.user))
    let request = try #require(server.restRequests.first)
    #expect(request.query["on_conflict"] == "user_id,song_id")
    #expect(request.header("Prefer")?.contains("resolution=merge-duplicates") == true)
    #expect(request.jsonObject?["updated_at"] as? String == "2024-07-01T00:00:00.000Z")
  }

  @Test func preferencesAreMergedKeepingUnknownKeys() async throws {
    let server = StubServer()
    server.sequence([.ok("[" + (try fixtureString("profile_row")) + "]"), .json(204, "")])
    _ = try await writer(server).apply(
      .updatePreferences(PreferencesPatch(lyricsColumns: 2), userID: Ids.user))
    let update = try #require(server.restRequests.last)
    #expect(update.method == "PATCH")
    let prefs = try #require(update.jsonObject?["preferences"] as? [String: Any])
    #expect((prefs["lyricsColumns"] as? NSNumber)?.intValue == 2)
    #expect(prefs["somethingNew"] != nil)
    #expect(prefs["theme"] as? String == "dark")
  }

  @Test func createPlaylistGeneratesShareCodeAndInsertsEntries() async throws {
    let server = StubServer()
    server.handle { request in
      request.method == "GET" ? .ok("[]") : .json(201, "")
    }
    let playlist = Playlist(
      id: Ids.playlist, name: "Sunday", description: nil, date: nil, isPublic: false,
      allowGuestEditing: false, shareCode: nil, shareExpiresAt: nil, archivedAt: nil,
      userID: Ids.user, teamID: nil, createdBy: Ids.user,
      createdAt: ServerTimestamp("2024-01-01T00:00:00Z"),
      updatedAt: ServerTimestamp("2024-01-01T00:00:00Z"))
    _ = try await writer(server).apply(
      .createPlaylist(playlist, songIDs: [Ids.song, Ids.song2]))
    let insert = try #require(server.restRequests.first)
    let code = try #require(insert.jsonObject?["share_code"] as? String)
    #expect(code.count == 12 && code.allSatisfy { $0.isUppercase || $0.isNumber })
    let entries = try #require(server.restRequests.last?.jsonArray)
    #expect(entries.map { ($0["position"] as? NSNumber)?.intValue } == [0, 1])
  }

  @Test func archiveSetsAndClearsArchivedAt() async throws {
    let server = StubServer()
    server.handle { _ in .json(204, "") }
    _ = try await writer(server).apply(
      .setPlaylistArchived(id: Ids.playlist, archivedAt: ServerTimestamp("2024-08-01T00:00:00Z")))
    _ = try await writer(server).apply(.setPlaylistArchived(id: Ids.playlist, archivedAt: nil))
    #expect(server.restRequests[0].jsonObject?["archived_at"] as? String == "2024-08-01T00:00:00Z")
    #expect(server.restRequests[1].jsonObject?["archived_at"] is NSNull)
  }
}
