import Foundation
import Testing

@testable import CapoCore

private let ts = ServerTimestamp("2026-03-01T15:01:10.123456+00:00")
private let userID = UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!
private let teamID = UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!
private let songID = UUID(uuidString: "00000000-0000-0000-0000-0000000000c1")!
private let playlistID = UUID(uuidString: "00000000-0000-0000-0000-0000000000d1")!
private let tagID = UUID(uuidString: "00000000-0000-0000-0000-0000000000e1")!

private let song = Song(
  id: songID, title: "Canción", artist: "Artista", key: "G", bpm: 92,
  lyrics: "{title: X}\n[G]Hola", notes: nil, transpose: -2, capo: 3, status: .published,
  userID: userID, teamID: nil, createdBy: userID, createdAt: ts, updatedAt: ts)
private let tag = SongTag(
  id: tagID, name: "Worship", color: "#ff0000", userID: nil, teamID: teamID, createdAt: ts)
private let playlist = Playlist(
  id: playlistID, name: "Sunday", description: "Main", date: "2026-03-01", isPublic: true,
  allowGuestEditing: false, shareCode: "ABCDEF123456", shareExpiresAt: nil, archivedAt: ts,
  userID: nil, teamID: teamID, createdBy: userID, createdAt: ts, updatedAt: ts)
private let team = Team(
  id: teamID, name: "Band", icon: "🎸", avatarURL: nil, isPublic: false, createdBy: userID,
  createdAt: ts, updatedAt: ts)
private let preferences = UserPreferences(json: [
  "lyricsColumns": .number(1), "theme": .string("dark"), "unknown": .object(["a": .array([.null, .bool(true)])])
])
private let settings = UserSongSettings(
  songID: songID, transpose: 2, capo: 1, fontSize: 1.25, updatedAt: ts)

private func roundTrip<T: Codable & Equatable>(_ value: T) throws {
  let data = try JSONEncoder().encode(value)
  let decoded = try JSONDecoder().decode(T.self, from: data)
  #expect(decoded == value, "round-trip of \(T.self)")
}

@Suite struct ServerTimestampTests {
  @Test func parsesMicrosecondsAndKeepsRaw() throws {
    let raw = "2026-03-01T15:01:10.123456+00:00"
    let stamp = ServerTimestamp(raw)
    #expect(stamp.raw == raw)
    let date = try #require(stamp.date)
    let expected = Date(timeIntervalSince1970: 1_772_377_270.123456)
    #expect(abs(date.timeIntervalSince1970 - expected.timeIntervalSince1970) < 0.000_01)

    let decoded = try JSONDecoder().decode(
      ServerTimestamp.self, from: Data("\"\(raw)\"".utf8))
    #expect(decoded.raw == raw)
    #expect(String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self) == "\"\(raw)\"")
  }

  @Test(arguments: [
    ("2026-03-01T15:01:10Z", 0.0),
    ("2026-03-01T15:01:10.5Z", 0.5),
    ("2026-03-01 15:01:10.25+00", 0.25),
    ("2026-03-01T17:01:10+02:00", 0.0),
    ("2026-03-01T13:01:10-0200", 0.0)
  ])
  func parsesVariants(raw: String, fraction: Double) throws {
    let date = try #require(ServerTimestamp(raw).date)
    #expect(abs(date.timeIntervalSince1970 - (1_772_377_270 + fraction)) < 0.000_01)
  }

  @Test func rejectsGarbage() {
    #expect(ServerTimestamp("yesterday").date == nil)
    #expect(ServerTimestamp("2026-03-01T15:01:10.").date == nil)
  }

  @Test func ordersByDateThenRaw() {
    #expect(ServerTimestamp("2026-03-01T15:01:10Z") < ServerTimestamp("2026-03-01T15:01:10.000001Z"))
    #expect(ServerTimestamp("2026-03-01T16:00:00+02:00") < ServerTimestamp("2026-03-01T15:00:00Z"))
    #expect(ServerTimestamp.now().date != nil)
  }
}

@Suite struct CodableRoundTripTests {
  @Test func everyModel() throws {
    try roundTrip(ts)
    try roundTrip(AppContext.personal(userID: userID))
    try roundTrip(AppContext.team(teamID: teamID))
    for status in SongStatus.allCases { try roundTrip(status) }
    for role in TeamRole.allCases { try roundTrip(role) }
    for theme in AppTheme.allCases { try roundTrip(theme) }
    try roundTrip(song)
    try roundTrip(tag)
    try roundTrip(TagAssignment(songID: songID, tagID: tagID))
    try roundTrip(SongPatch(title: "T", artist: "", bpm: 0, transpose: 1, status: .draft))
    try roundTrip(playlist)
    try roundTrip(PlaylistEntry(id: UUID(), playlistID: playlistID, songID: songID, position: 3))
    try roundTrip(PlaylistPatch(name: "N", isPublic: false))
    try roundTrip(team)
    try roundTrip(TeamMembership(id: UUID(), teamID: teamID, userID: userID, role: .admin, joinedAt: ts))
    try roundTrip(ProfileSummary(id: userID, email: "a@b.c", fullName: nil, avatarURL: nil))
    try roundTrip(
      TeamInvitation(
        id: UUID(), teamID: teamID, email: "x@y.z", role: .viewer, invitedBy: userID, token: "tok",
        expiresAt: ts, acceptedAt: nil, createdAt: ts))
    try roundTrip(JSONValue.object(["n": .number(1.5), "s": .string("x"), "l": .array([.bool(false), .null])]))
    try roundTrip(preferences)
    try roundTrip(PreferencesPatch(lyricsColumns: 1, locale: "es", theme: .system))
    try roundTrip(
      Profile(id: userID, email: nil, fullName: "Me", avatarURL: nil, preferences: preferences, updatedAt: ts))
    try roundTrip(settings)
  }

  @Test func everyOutboxOperation() throws {
    let ops: [OutboxOperation] = [
      .createSong(song),
      .updateSong(id: songID, patch: SongPatch(lyrics: "x"), base: ts),
      .deleteSong(id: songID),
      .setSongTags(songID: songID, tagIDs: [tagID]),
      .createTag(tag),
      .deleteTag(id: tagID),
      .upsertSongSettings(settings, userID: userID),
      .updatePreferences(PreferencesPatch(lyricsColumns: 2), userID: userID),
      .createPlaylist(playlist, songIDs: [songID]),
      .updatePlaylist(id: playlistID, patch: PlaylistPatch(description: "d")),
      .deletePlaylist(id: playlistID),
      .setPlaylistArchived(id: playlistID, archivedAt: nil),
      .setPlaylistArchived(id: playlistID, archivedAt: ts),
      .addSongToPlaylist(playlistID: playlistID, songID: songID),
      .removeSongFromPlaylist(playlistID: playlistID, songID: songID),
      .reorderPlaylist(playlistID: playlistID, songIDs: [songID, UUID()])
    ]
    for op in ops { try roundTrip(op) }
  }

  @Test func entityKeys() {
    let s = songID.uuidString.lowercased()
    let p = playlistID.uuidString.lowercased()
    #expect(OutboxOperation.deleteSong(id: songID).entityKey == "song:\(s)")
    #expect(OutboxOperation.setSongTags(songID: songID, tagIDs: []).entityKey == "song:\(s)")
    #expect(OutboxOperation.createTag(tag).entityKey == "tag:\(tagID.uuidString.lowercased())")
    #expect(OutboxOperation.upsertSongSettings(settings, userID: userID).entityKey == "settings:\(s)")
    #expect(OutboxOperation.updatePreferences(PreferencesPatch(), userID: userID).entityKey == "prefs")
    #expect(OutboxOperation.reorderPlaylist(playlistID: playlistID, songIDs: []).entityKey == "playlist:\(p)")
  }
}

@Suite struct ModelBehaviourTests {
  @Test func preferencesMirrorWebMapping() {
    #expect(UserPreferences.default.lyricsColumns == 2)
    #expect(preferences.lyricsColumns == 1)
    #expect(preferences.theme == .dark)
    #expect(UserPreferences(json: ["lyricsColumns": .string("1")]).lyricsColumns == 2)
    let json = preferences.json(applying: PreferencesPatch(lyricsColumns: 2, locale: "es"))
    #expect(json["lyricsColumns"] == .number(2))
    #expect(json["locale"] == .string("es"))
    #expect(json["unknown"] == preferences.raw["unknown"])
    #expect(UserPreferences.default.resolvedChordHand == .left)
    let handJSON = preferences.json(applying: PreferencesPatch(chordHand: .right))
    #expect(handJSON["chordHand"] == .string("right"))
    #expect(handJSON["unknown"] == preferences.raw["unknown"])
    #expect(UserPreferences(json: handJSON).resolvedChordHand == .right)
    #expect(UserPreferences(json: ["chordHand": .string("bogus")]).resolvedChordHand == .left)
  }

  @Test func patchMergeKeepsOlderFields() {
    let merged = SongPatch(title: "A", lyrics: "old").merged(with: SongPatch(lyrics: "new", capo: 2))
    #expect(merged == SongPatch(title: "A", lyrics: "new", capo: 2))
  }

  @Test func effectiveSettings() {
    #expect(EffectiveSongSettings.resolve(song: song, user: nil) == .init(transpose: -2, capo: 3, fontSize: 1))
    #expect(EffectiveSongSettings.resolve(song: song, user: settings) == .init(transpose: 2, capo: 1, fontSize: 1.25))
  }

  @Test func rolesAndContext() {
    #expect(!TeamRole.viewer.canEditContent)
    #expect(TeamRole.member.canEditContent)
    #expect(TeamRole.admin.canManageMembers && !TeamRole.member.canManageMembers)
    #expect(AppContext.team(teamID: teamID).teamID == teamID)
    #expect(AppContext.personal(userID: userID).teamID == nil)
  }

  @Test func appConfigFromPlist() {
    #expect(AppConfig.load(from: ["SUPABASE_URL": "http://127.0.0.1:54321"]) == nil)
    let config = AppConfig.load(from: [
      "SUPABASE_URL": "http://127.0.0.1:54321", "SUPABASE_PUBLISHABLE_KEY": "k",
      "CAPO_WEB_URL": "http://localhost:3000", "CAPO_ENV_NAME": "local"
    ])
    #expect(config?.environmentName == "local")
    #expect(config?.authCallbackURL.absoluteString == "capo://auth/callback")
  }
}

@Suite struct ValueSubjectTests {
  @Test func replaysCurrentAndMulticasts() async {
    let subject = ValueSubject(1)
    var a = subject.stream().makeAsyncIterator()
    var b = subject.stream().makeAsyncIterator()
    #expect(await a.next() == 1)
    #expect(await b.next() == 1)
    subject.send(2)
    #expect(await a.next() == 2)
    #expect(await b.next() == 2)
    subject.update { $0 += 1 }
    #expect(subject.value == 3)
    #expect(await a.next() == 3)
  }
}
