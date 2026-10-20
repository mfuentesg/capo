import CapoCore
import Foundation
import Testing

@testable import CapoSupabase

@Suite struct RowsDecodingTests {
  private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try JSONDecoder().decode(T.self, from: try fixture(name))
  }

  @Test func songRowKeepsRawTimestampsAndMapsFields() throws {
    let song = try decode(SongRow.self, "song_row").model
    #expect(song.updatedAt.raw == "2024-05-02T08:30:00.5+00:00")
    #expect(song.createdAt.raw == "2024-05-01T10:00:00.123456+00:00")
    #expect(song.status == .draft)
    #expect(song.teamID == Ids.team)
    #expect(song.userID == nil)
    #expect(song.transpose == -2 && song.capo == 3)
    #expect(song.artist == nil && song.bpm == nil)
  }

  @Test func playlistRow() throws {
    let playlist = try decode(PlaylistRow.self, "playlist_row").model
    #expect(playlist.date == "2024-06-02")
    #expect(playlist.shareCode == "ABCDEF123456")
    #expect(playlist.archivedAt?.raw == "2024-06-03T00:00:00+00:00")
    #expect(playlist.isPublic && !playlist.allowGuestEditing)
  }

  @Test func profileKeepsUnknownPreferenceKeys() throws {
    let profile = try decode(ProfileRow.self, "profile_row").model
    #expect(profile.preferences.lyricsColumns == 1)
    #expect(profile.preferences.theme == .dark)
    #expect(profile.preferences.raw["somethingNew"] == .object(["a": .array([.number(1), .bool(true), .null])]))
    #expect(profile.updatedAt.raw == "2024-01-02T00:00:00.000001+00:00")
  }

  @Test func userSongSettingsRow() throws {
    let settings = try decode(UserSongSettingsRow.self, "user_song_settings_row").model
    #expect(settings.transpose == 2 && settings.capo == 4 && settings.fontSize == 1.25)
    #expect(settings.updatedAt?.raw == "2024-03-02T00:00:00.123+00:00")
  }

  @Test func teamMemberEmbedAsObjectAndAsArray() throws {
    let object = try decode(TeamMemberWithProfileRow.self, "team_member_embedded_object")
    #expect(object.member.role == .admin)
    #expect(object.profile?.fullName == "Ana")
    let array = try decode(TeamMemberWithProfileRow.self, "team_member_embedded_array")
    #expect(array.member.role == .viewer)
    #expect(array.profile?.email == "a@example.test")
    #expect(array.profile?.fullName == nil)
  }

  @Test func pendingInvitationFallsBackToInviterEmail() throws {
    let pending = try decode(PendingInvitationRow.self, "pending_invitation").model
    #expect(pending.teamName == "Worship Team")
    #expect(pending.inviterName == "a@example.test")
    #expect(pending.invitation.token == "tok123")
    #expect(pending.invitation.acceptedAt == nil)
  }

  @Test func songUpdatePayloadMirrorsWebClearing() {
    let body = SongRow.updatePayload(
      SongPatch(title: "T", artist: "", key: "", bpm: 0, lyrics: "", notes: "n", transpose: 2))
    #expect(body["title"] == .string("T"))
    #expect(body["artist"] == .null)
    #expect(body["key"] == .null)
    #expect(body["bpm"] == .null)
    #expect(body["lyrics"] == .null)
    #expect(body["notes"] == .string("n"))
    #expect(body["transpose"] == .number(2))
    #expect(body["capo"] == nil && body["status"] == nil)
  }
}

/// Fails when `lib/supabase/database.types.ts` and the hand-written DTOs disagree.
@Suite struct RowsDriftTests {
  /// Columns of `tables.<name>.<section>` as written in database.types.ts.
  private static func columns(table: String, section: String) throws -> Set<String> {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<6 { url.deleteLastPathComponent() }  // file, tests, Tests, CapoSupabase, Packages, ios
    let text = try String(contentsOf: url.appendingPathComponent("lib/supabase/database.types.ts"), encoding: .utf8)
    let lines = text.components(separatedBy: "\n")
    guard let start = lines.firstIndex(of: "      \(table): {") else {
      throw DriftError.missing("table \(table)")
    }
    guard let sectionStart = lines[start...].firstIndex(of: "        \(section): {") else {
      throw DriftError.missing("\(table).\(section)")
    }
    var keys: Set<String> = []
    for line in lines[(sectionStart + 1)...] {
      if line == "        }" { break }
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard let colon = trimmed.firstIndex(of: ":"), line.hasPrefix("          ") else { continue }
      keys.insert(String(trimmed[..<colon]).replacingOccurrences(of: "?", with: ""))
    }
    if keys.isEmpty { throw DriftError.missing("no keys for \(table).\(section)") }
    return keys
  }

  enum DriftError: Error { case missing(String) }

  private struct Mirror {
    var table: String
    var keys: Set<String>
    var allowlist: Set<String> = []
  }

  private static func keys<K: CaseIterable & RawRepresentable>(_ type: K.Type) -> Set<String>
  where K.RawValue == String {
    Set(K.allCases.map(\.rawValue))
  }

  private static let mirrors: [Mirror] = [
    Mirror(table: "songs", keys: keys(SongRow.CodingKeys.self), allowlist: ["search_vector"]),
    Mirror(table: "playlists", keys: keys(PlaylistRow.CodingKeys.self)),
    Mirror(table: "playlist_songs", keys: keys(PlaylistSongRow.CodingKeys.self)),
    Mirror(table: "profiles", keys: keys(ProfileRow.CodingKeys.self)),
    Mirror(table: "song_tag_assignments", keys: keys(SongTagAssignmentRow.CodingKeys.self)),
    Mirror(table: "song_tags", keys: keys(SongTagRow.CodingKeys.self)),
    Mirror(table: "team_invitations", keys: keys(TeamInvitationRow.CodingKeys.self)),
    Mirror(table: "team_members", keys: keys(TeamMemberRow.CodingKeys.self)),
    Mirror(table: "teams", keys: keys(TeamRow.CodingKeys.self)),
    Mirror(table: "user_song_settings", keys: keys(UserSongSettingsRow.CodingKeys.self))
  ]

  @Test(arguments: mirrors.map(\.table))
  func dtoCoversEveryRowColumn(table: String) throws {
    let mirror = try #require(Self.mirrors.first { $0.table == table })
    let row = try Self.columns(table: table, section: "Row").subtracting(mirror.allowlist)
    #expect(mirror.keys == row, "DTO for \(table) drifted from database.types.ts Row")
  }

  @Test func writePayloadsOnlyUseInsertableColumns() throws {
    let song = makeSong()
    let playlist = Playlist(
      id: Ids.playlist, name: "P", description: nil, date: nil, isPublic: false,
      allowGuestEditing: false, shareCode: nil, shareExpiresAt: nil, archivedAt: nil,
      userID: Ids.user, teamID: nil, createdBy: Ids.user,
      createdAt: ServerTimestamp("2024-01-01T00:00:00Z"), updatedAt: ServerTimestamp("2024-01-01T00:00:00Z"))
    let tag = SongTag(
      id: Ids.tag, name: "t", color: nil, userID: Ids.user, teamID: nil,
      createdAt: ServerTimestamp("2024-01-01T00:00:00Z"))
    let settings = UserSongSettings(songID: Ids.song, transpose: 1, capo: 2, fontSize: 1, updatedAt: nil)

    let cases: [(String, Set<String>)] = [
      ("songs", Set(SongRow.insertPayload(song).keys)),
      ("songs", Set(SongRow.updatePayload(SongPatch(title: "a", artist: "b", key: "c", bpm: 1, lyrics: "d", notes: "e", transpose: 1, capo: 1, status: .draft)).keys)),
      ("playlists", Set(PlaylistRow.insertPayload(playlist, shareCode: "X").keys)),
      ("playlists", Set(PlaylistRow.updatePayload(PlaylistPatch(name: "a", description: "b", date: "c", isPublic: true, allowGuestEditing: true)).keys)),
      ("song_tags", Set(SongTagRow.insertPayload(tag).keys)),
      ("user_song_settings", Set(UserSongSettingsRow.upsertPayload(settings, userID: Ids.user).keys))
    ]
    for (table, keys) in cases {
      let insertable = try Self.columns(table: table, section: "Insert")
      #expect(keys.isSubset(of: insertable), "\(table): \(keys.subtracting(insertable))")
    }
  }
}
