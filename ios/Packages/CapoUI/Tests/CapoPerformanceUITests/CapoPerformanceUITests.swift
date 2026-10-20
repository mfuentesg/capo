import CapoChordPro
import CapoCore
import CapoFakes
import Foundation
import Testing
import UIKit

@testable import CapoPerformanceUI

@Suite struct AutoScrollSpeedTests {
  @Test func noBpmUsesTheDefault() {
    #expect(AutoScrollSpeed.inferred(bpm: nil, lyrics: "a\nb", scrollableHeight: 900) == 30)
    #expect(AutoScrollSpeed.inferred(bpm: 0, lyrics: "a\nb", scrollableHeight: 900) == 30)
  }

  @Test func countsOnlyLyricLines() {
    let lyrics = "{title: X}\n\n[G]one\n  \n two\n  {soc}\nthree"
    #expect(AutoScrollSpeed.lyricLineCount(lyrics) == 3)
    #expect(AutoScrollSpeed.lyricLineCount("") == 1)
    #expect(AutoScrollSpeed.lyricLineCount(nil) == 1)
  }

  @Test func webFormula() {
    // 10 lines at 120 bpm: 10 * 4 / 2 = 20 s; 1000 px / 20 s = 50 px/s.
    let lyrics = Array(repeating: "la", count: 10).joined(separator: "\n")
    #expect(AutoScrollSpeed.inferred(bpm: 120, lyrics: lyrics, scrollableHeight: 1000) == 50)
    // Math.round: 1010 / 20 = 50.5 -> 51.
    #expect(AutoScrollSpeed.inferred(bpm: 120, lyrics: lyrics, scrollableHeight: 1010) == 51)
  }

  @Test func clampsAndFallsBackOnHeight() {
    let lyrics = Array(repeating: "la", count: 10).joined(separator: "\n")
    #expect(AutoScrollSpeed.inferred(bpm: 30, lyrics: lyrics, scrollableHeight: 10) == 10)
    #expect(AutoScrollSpeed.inferred(bpm: 240, lyrics: lyrics, scrollableHeight: 100_000) == 300)
    // No measurable height: 30 px per line -> 300 px over 20 s = 15 px/s.
    #expect(AutoScrollSpeed.inferred(bpm: 120, lyrics: lyrics, scrollableHeight: 0) == 15)
  }

  @Test func stepsAreClamped() {
    #expect(AutoScrollSpeed.faster(30) == 40)
    #expect(AutoScrollSpeed.faster(295) == 300)
    #expect(AutoScrollSpeed.slower(15) == 10)
    #expect(AutoScrollSpeed.slower(10) == 10)
  }
}

@Suite struct PerformanceSettingsTests {
  @Test func clampsToWebRanges() {
    var settings = PerformanceSettings(transpose: 6, capo: 12, fontSize: 3)
    settings.transposeUp()
    settings.capoUp()
    settings.fontUp()
    #expect(settings == PerformanceSettings(transpose: 6, capo: 12, fontSize: 3))
    settings = PerformanceSettings(transpose: -6, capo: 0, fontSize: 0.5)
    settings.transposeDown()
    settings.capoDown()
    settings.fontDown()
    #expect(settings == PerformanceSettings(transpose: -6, capo: 0, fontSize: 0.5))
  }

  @Test func fontStepIsAQuarter() {
    var settings = PerformanceSettings()
    settings.fontUp()
    #expect(settings.fontSize == 1.25)
    settings.fontDown()
    settings.fontDown()
    #expect(settings.fontSize == 0.75)
  }
}

@Suite struct ScrollMathTests {
  @Test func pagesBy85PercentAndStopsAtEnds() {
    #expect(ScrollMath.pageDown(offset: 0, viewport: 1000, content: 5000) == 850)
    #expect(ScrollMath.pageDown(offset: 3900, viewport: 1000, content: 5000) == 4000)
    #expect(ScrollMath.pageUp(offset: 500, viewport: 1000) == 0)
    #expect(ScrollMath.pageUp(offset: 2000, viewport: 1000) == 1150)
  }

  @Test func bottomHasTwoPointTolerance() {
    #expect(ScrollMath.isAtBottom(offset: 3998, viewport: 1000, content: 5000))
    #expect(!ScrollMath.isAtBottom(offset: 3997, viewport: 1000, content: 5000))
    #expect(ScrollMath.isAtBottom(offset: 0, viewport: 1000, content: 600))
  }
}

@Suite struct KeyMapTests {
  @Test(arguments: [
    (UIKeyCommand.inputDownArrow, PerformanceAction.pageDown),
    (UIKeyCommand.inputPageDown, .pageDown),
    (" ", .pageDown),
    (UIKeyCommand.inputUpArrow, .pageUp),
    (UIKeyCommand.inputPageUp, .pageUp),
    (UIKeyCommand.inputRightArrow, .nextSong),
    (UIKeyCommand.inputLeftArrow, .previousSong),
    ("s", .toggleAutoScroll),
    ("[", .scrollSlower),
    ("]", .scrollFaster),
    ("+", .increaseFont),
    ("=", .increaseFont),
    ("-", .decreaseFont)
  ])
  func mapsKey(_ input: String, _ action: PerformanceAction) {
    #expect(PerformanceKeyMap.action(for: input) == action)
  }

  @Test func everyActionHasAKeyAndInputsAreUnique() {
    let inputs = PerformanceKeyMap.bindings.map(\.input)
    #expect(Set(inputs).count == inputs.count)
    #expect(Set(PerformanceKeyMap.bindings.map(\.action)) == Set(PerformanceAction.allCases))
    #expect(PerformanceKeyMap.action(for: "x") == nil)
  }
}

/// Records every save; lets tests control when debounce sleeps finish.
actor RecordingSettings: SettingsRepository {
  private(set) var saved: [UserSongSettings] = []
  private(set) var patches: [PreferencesPatch] = []

  nonisolated func songSettings(songID: SongID) -> AsyncStream<UserSongSettings?> {
    AsyncStream { $0.finish() }
  }
  func saveSongSettings(_ settings: UserSongSettings) async throws { saved.append(settings) }
  nonisolated func preferences() -> AsyncStream<UserPreferences> { AsyncStream { $0.finish() } }
  func updatePreferences(_ patch: PreferencesPatch) async throws { patches.append(patch) }
}

@MainActor
@Suite struct SongPerformanceModelTests {
  static func song(transpose: Int = 0, capo: Int = 0, key: String? = "G") -> Song {
    Song(
      id: SongID(), title: "T", artist: nil, key: key, bpm: 100,
      lyrics: "[G]Amazing [C]grace", notes: nil, transpose: transpose, capo: capo,
      status: .published, userID: nil, teamID: nil, createdBy: UUID(),
      createdAt: ServerTimestamp("2026-01-01T00:00:00Z"),
      updatedAt: ServerTimestamp("2026-01-01T00:00:00Z"))
  }

  func makeModel(
    _ repository: RecordingSettings, song: Song, delay: Duration = .milliseconds(40)
  ) -> SongPerformanceModel {
    let model = SongPerformanceModel(
      songID: song.id, settingsRepository: repository, sectionLabels: [:], commentLabel: "Note",
      saveDelay: delay)
    model.apply(song: song)
    return model
  }

  func chords(_ model: SongPerformanceModel) -> [String] {
    guard case .normal(let body)? = model.rendered.segments.first,
      case .chordLyrics(let pairs)? = body.lines.first
    else { return [] }
    return pairs.map(\.chord).filter { !$0.isEmpty }
  }

  @Test func usesSongDefaultsThenUserSettings() {
    let repository = RecordingSettings()
    let song = Self.song(transpose: 2)
    let model = makeModel(repository, song: song)
    #expect(model.settings == PerformanceSettings(transpose: 2, capo: 0, fontSize: 1))
    #expect(chords(model) == ["A", "D"])
    model.apply(
      userSettings: UserSongSettings(
        songID: song.id, transpose: 0, capo: 2, fontSize: 1.5, updatedAt: nil))
    #expect(model.settings == PerformanceSettings(transpose: 0, capo: 2, fontSize: 1.5))
    #expect(chords(model) == ["F", "Bb"])
    #expect(model.capoShapeKey == "F")
  }

  @Test func debouncesSavesToTheLastValue() async throws {
    let repository = RecordingSettings()
    let song = Self.song()
    let model = makeModel(repository, song: song)
    model.change { $0.transposeUp() }
    model.change { $0.transposeUp() }
    model.change { $0.capoUp() }
    #expect(await repository.saved.isEmpty)
    try await Task.sleep(for: .milliseconds(300))
    let saved = await repository.saved
    #expect(saved.count == 1)
    #expect(saved.first?.transpose == 2)
    #expect(saved.first?.capo == 1)
    #expect(saved.first?.songID == song.id)
  }

  @Test func pendingLocalChangeIgnoresStoreEcho() {
    let repository = RecordingSettings()
    let song = Self.song()
    let model = makeModel(repository, song: song, delay: .seconds(60))
    model.change { $0.transposeUp() }
    model.apply(
      userSettings: UserSongSettings(songID: song.id, transpose: -3, capo: 0, fontSize: 1, updatedAt: nil))
    #expect(model.settings.transpose == 1)
  }

  @Test func flushSavesImmediately() async {
    let repository = RecordingSettings()
    let model = makeModel(repository, song: Self.song(), delay: .seconds(60))
    model.change { $0.fontUp() }
    await model.flushPendingSave()
    #expect(await repository.saved.map(\.fontSize) == [1.25])
  }

  @Test func resetRestoresAuthoredValues() async {
    let repository = RecordingSettings()
    let song = Self.song(transpose: -1, capo: 3)
    let model = makeModel(repository, song: song, delay: .seconds(60))
    model.change {
      $0.transposeUp()
      $0.fontUp()
    }
    model.reset()
    #expect(model.settings == PerformanceSettings(transpose: -1, capo: 3, fontSize: 1))
    await model.flushPendingSave()
    #expect(await repository.saved.last?.capo == 3)
  }

  @Test func columnsPersistAsPreference() async {
    let repository = RecordingSettings()
    let model = makeModel(repository, song: Self.song())
    #expect(model.columns == 2)
    await model.setColumns(1)
    await model.setColumns(1)
    #expect(model.columns == 1)
    #expect(await repository.patches == [PreferencesPatch(lyricsColumns: 1)])
  }

  @Test func infersSpeedOncePerSong() {
    let model = makeModel(RecordingSettings(), song: Self.song())
    // 1 lyric line at 100 bpm: 2.4 s; 240 px -> 100 px/s.
    model.contentMeasured(scrollableHeight: 240)
    #expect(model.scrollSpeed == 100)
    model.contentMeasured(scrollableHeight: 2400)
    #expect(model.scrollSpeed == 100)
  }

  @Test func worksWithTheFakeBackend() async throws {
    let services = UserServices.fake()
    let model = SongPerformanceModel(
      songID: SongID(), settingsRepository: services.settings, sectionLabels: [:],
      commentLabel: "Note", saveDelay: .milliseconds(10))
    model.apply(song: nil)
    #expect(model.isLoaded)
    #expect(model.song == nil)
    #expect(model.rendered.segments.isEmpty)
  }
}

@MainActor
@Suite struct DebouncerTests {
  @Test func cancelDropsPendingWork() async throws {
    var runs = 0
    let debouncer = Debouncer(delay: .milliseconds(20))
    debouncer.schedule { runs += 1 }
    debouncer.cancel()
    try await Task.sleep(for: .milliseconds(150))
    #expect(runs == 0)
    #expect(!debouncer.hasPending)
  }
}
