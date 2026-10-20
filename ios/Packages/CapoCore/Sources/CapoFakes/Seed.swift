import CapoCore
import Foundation

/// Deterministic ids used by the demo seed, previews and tests.
public enum FakeIDs {
  public static let user = id(0xA1)
  public static let otherUser = id(0xA2)
  public static let team = id(0xB1)
  public static let songs: [SongID] = (1...12).map { id(0xC00 + $0) }
  public static let playlists: [PlaylistID] = [id(0xD01), id(0xD02)]
  public static let tags: [TagID] = (1...4).map { id(0xE00 + $0) }
  public static let membership = id(0xF01)

  public static func id(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", n))!
  }
}

/// The full in-memory data set behind every fake.
public struct BackendState: Sendable, Hashable {
  public var songs: [Song] = []
  public var tags: [SongTag] = []
  public var tagAssignments: [TagAssignment] = []
  public var playlists: [Playlist] = []
  public var playlistEntries: [PlaylistEntry] = []
  public var teams: [Team] = []
  public var memberships: [TeamMembership] = []
  public var invitations: [TeamInvitation] = []
  public var profiles: [ProfileSummary] = []
  public var userSongSettings: [UserSongSettings] = []
  public var profile: Profile?
  public var pinnedPlaylistIDs: Set<PlaylistID> = []
  public var pendingSongIDs: Set<SongID> = []
  public var conflicts: [SongConflict] = []

  public init() {}
}

public enum FakeSeed {
  public static let baseTimestamp = "2026-03-01T15:01:10.123456+00:00"

  static func timestamp(minutesAgo: Int) -> ServerTimestamp {
    let date = Date(timeIntervalSince1970: 1_772_377_270 - Double(minutesAgo * 60))
    return ServerTimestamp(Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(date))
  }

  /// 12 songs (the 4 original corpus files plus Spanish titles), 2 playlists, 1 team, 4 tags.
  public static func demo(userID: UserID = FakeIDs.user) -> BackendState {
    let ts = ServerTimestamp(baseTimestamp)
    var state = BackendState()

    let team = Team(
      id: FakeIDs.team, name: "Banda del Domingo", icon: "🎸", avatarURL: nil, isPublic: false,
      createdBy: userID, createdAt: ts, updatedAt: ts)
    state.teams = [team]
    state.memberships = [
      TeamMembership(id: FakeIDs.membership, teamID: team.id, userID: userID, role: .owner, joinedAt: ts),
      TeamMembership(
        id: FakeIDs.id(0xF02), teamID: team.id, userID: FakeIDs.otherUser, role: .member, joinedAt: ts)
    ]
    state.profiles = [
      ProfileSummary(id: userID, email: "demo@capo.app", fullName: "Demo User", avatarURL: nil),
      ProfileSummary(id: FakeIDs.otherUser, email: "ana@capo.app", fullName: "Ana", avatarURL: nil)
    ]

    typealias Spec = (title: String, artist: String?, key: String?, bpm: Int?, lyrics: String, team: Bool)
    let specs: [Spec] = [
      ("Amazing Grace", "John Newton", "G", 72, CorpusLyrics.basicVerseChorus, false),
      ("Puente de Fuego", "Capo Demo", "E", 128, CorpusLyrics.flagsAndInline, false),
      ("Repite el Coro", "Capo Demo", "A", 96, CorpusLyrics.repeatAndExtend, false),
      ("Caja y Volta", "Capo Demo", "D", 110, CorpusLyrics.voltaBoxComment, false),
      ("Canción del Mar", "Marea", "C", 84, simple("C", "Am", "F", "G", "Canta el mar su canción"), false),
      ("Gracias Señor", "Coro Unido", "D", 100, simple("D", "A", "Bm", "G", "Gracias te doy, Señor"), false),
      ("Cuán Grande Es Él", "Tradicional", "Bb", 68, simple("Bb", "Eb", "F", "Gm", "Cuán grande es Él"), false),
      ("Mañana de Sol", nil, "F", 140, simple("F", "C", "Dm", "Bb", "La mañana brilla ya"), false),
      ("Ven Espíritu", "Banda del Domingo", "E", 76, simple("E", "B", "C#m", "A", "Ven, Espíritu, ven"), true),
      ("Aleluya", "Banda del Domingo", "G", 118, simple("G", "D", "Em", "C", "Aleluya, aleluya"), true),
      ("Mi Refugio", "Banda del Domingo", "A", 92, simple("A", "E", "F#m", "D", "Tú eres mi refugio"), true),
      ("Santo", nil, nil, nil, simple("C", "G", "Am", "F", "Santo, santo, santo"), true)
    ]
    state.songs = specs.enumerated().map { index, spec in
      let stamp = timestamp(minutesAgo: index * 90)
      return Song(
        id: FakeIDs.songs[index], title: spec.title, artist: spec.artist, key: spec.key,
        bpm: spec.bpm, lyrics: spec.lyrics, notes: index == 0 ? "Hymn, 1779" : nil, transpose: 0,
        capo: index == 4 ? 2 : 0, status: index == 7 ? .draft : .published,
        userID: spec.team ? nil : userID, teamID: spec.team ? team.id : nil, createdBy: userID,
        createdAt: stamp, updatedAt: stamp)
    }

    let tagSpecs: [(String, String?, Bool)] = [
      ("Adoración", "#8b5cf6", false), ("Rápida", "#ef4444", false), ("Lenta", nil, false),
      ("Domingo", "#10b981", true)
    ]
    state.tags = tagSpecs.enumerated().map { index, spec in
      SongTag(
        id: FakeIDs.tags[index], name: spec.0, color: spec.1, userID: spec.2 ? nil : userID,
        teamID: spec.2 ? team.id : nil, createdAt: ts)
    }
    state.tagAssignments = [
      (0, 0), (0, 2), (1, 1), (4, 2), (5, 0), (6, 0), (6, 2), (7, 1), (8, 3), (9, 3), (10, 3)
    ].map { TagAssignment(songID: FakeIDs.songs[$0.0], tagID: FakeIDs.tags[$0.1]) }

    state.playlists = [
      Playlist(
        id: FakeIDs.playlists[0], name: "Ensayo del Jueves", description: "Repertorio personal",
        date: "2026-03-05", isPublic: false, allowGuestEditing: false, shareCode: nil,
        shareExpiresAt: nil, archivedAt: nil, userID: userID, teamID: nil, createdBy: userID,
        createdAt: ts, updatedAt: ts),
      Playlist(
        id: FakeIDs.playlists[1], name: "Domingo 8 de marzo", description: nil,
        date: "2026-03-08", isPublic: true, allowGuestEditing: false, shareCode: "DEMO12345678",
        shareExpiresAt: nil, archivedAt: nil, userID: nil, teamID: team.id, createdBy: userID,
        createdAt: ts, updatedAt: ts)
    ]
    let personal = [0, 4, 5, 1, 6]
    let teamSet = [8, 9, 10, 11]
    state.playlistEntries =
      personal.enumerated().map { pos, song in
        PlaylistEntry(
          id: FakeIDs.id(0x1000 + pos), playlistID: FakeIDs.playlists[0],
          songID: FakeIDs.songs[song], position: pos)
      }
      + teamSet.enumerated().map { pos, song in
        PlaylistEntry(
          id: FakeIDs.id(0x2000 + pos), playlistID: FakeIDs.playlists[1],
          songID: FakeIDs.songs[song], position: pos)
      }
    state.pinnedPlaylistIDs = [FakeIDs.playlists[1]]
    state.userSongSettings = [
      UserSongSettings(songID: FakeIDs.songs[0], transpose: 2, capo: 0, fontSize: 1.25, updatedAt: ts)
    ]
    state.profile = Profile(
      id: userID, email: "demo@capo.app", fullName: "Demo User", avatarURL: nil,
      preferences: UserPreferences(json: ["lyricsColumns": .number(2), "theme": .string("system")]),
      updatedAt: ts)
    return state
  }

  private static func simple(_ a: String, _ b: String, _ c: String, _ d: String, _ line: String) -> String {
    """
    {sov: Verso 1}
    [\(a)]\(line), [\(b)]con el corazón
    [\(c)]Levanto mi [\(d)]voz
    {eov}
    {soc: Coro}
    [\(d)]\(line) [\(a)]hoy
    [\(b)]Para siem[\(c)]pre, [\(a)]amén
    {eoc}
    {c: Repetir coro}
    """
  }
}
