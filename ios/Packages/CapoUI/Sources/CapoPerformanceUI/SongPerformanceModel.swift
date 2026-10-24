import CapoChordPro
import CapoCore
import CapoDesign
import Observation

/// State for one song on stage: the song, the user's transpose/capo/font, columns, auto-scroll.
@Observable
final class SongPerformanceModel {
  let songID: SongID
  private(set) var song: Song?
  private(set) var isLoaded = false
  private(set) var settings = PerformanceSettings()
  private(set) var rendered = RenderedSong(segments: [])
  var columns = UserPreferences.default.lyricsColumns
  private(set) var chordHand = UserPreferences.default.resolvedChordHand
  var showChords = true
  var showLyrics = true
  private(set) var tags: [SongTag] = []
  var scrollSpeed = AutoScrollSpeed.fallback
  var isAutoScrolling = false

  @ObservationIgnored private let settingsRepository: any SettingsRepository
  @ObservationIgnored private let sectionLabels: [String: String]
  @ObservationIgnored private let commentLabel: String
  @ObservationIgnored private let saveDebouncer: Debouncer
  @ObservationIgnored private var renderedFor: RenderKey?
  @ObservationIgnored private var userSettings: UserSongSettings?
  @ObservationIgnored private var inferredSpeedForSong: SongID?

  private struct RenderKey: Equatable {
    var lyrics: String
    var transpose: Int
    var capo: Int
  }

  init(
    songID: SongID, settingsRepository: any SettingsRepository,
    sectionLabels: [String: String], commentLabel: String,
    saveDelay: Duration = .milliseconds(500),
    sleep: @escaping Debouncer.Sleep = { try await Task.sleep(for: $0) }
  ) {
    self.songID = songID
    self.settingsRepository = settingsRepository
    self.sectionLabels = sectionLabels
    self.commentLabel = commentLabel
    saveDebouncer = Debouncer(delay: saveDelay, sleep: sleep)
  }

  // MARK: Stream input

  func apply(song: Song?) {
    self.song = song
    isLoaded = true
    if !saveDebouncer.hasPending { resolveSettings() }
    rerender()
  }

  func apply(tags: [SongTag]) { self.tags = tags }

  func apply(userSettings: UserSongSettings?) {
    self.userSettings = userSettings
    // A pending local change wins over whatever the store echoes meanwhile.
    guard !saveDebouncer.hasPending else { return }
    resolveSettings()
    rerender()
  }

  func apply(preferences: UserPreferences) {
    columns = preferences.lyricsColumns == 1 ? 1 : 2
    chordHand = preferences.resolvedChordHand
  }

  private func resolveSettings() {
    guard let song else { return }
    settings = PerformanceSettings(EffectiveSongSettings.resolve(song: song, user: userSettings))
  }

  // MARK: User actions

  func change(_ mutate: (inout PerformanceSettings) -> Void) {
    var next = settings
    mutate(&next)
    guard next != settings else { return }
    settings = next
    rerender()
    scheduleSave()
  }

  /// The song's authored transpose and capo with the default font size.
  var defaults: PerformanceSettings {
    guard let song else { return PerformanceSettings() }
    return PerformanceSettings(EffectiveSongSettings.resolve(song: song, user: nil))
  }

  /// Back to the song's authored transpose and capo, default font size.
  func reset() {
    let defaults = defaults
    change { $0 = defaults }
  }

  func reset(_ kind: DisplaySettingsLogic.Kind) {
    let defaults = defaults
    change { DisplaySettingsLogic.reset(kind, in: &$0, to: defaults) }
  }

  var chips: [DisplaySettingsLogic.Chip] {
    DisplaySettingsLogic.chips(settings: settings, defaults: defaults)
  }

  var isDisplayModified: Bool {
    DisplaySettingsLogic.isModified(
      settings: settings, defaults: defaults, showChords: showChords, showLyrics: showLyrics)
  }

  func setChords(_ value: Bool) {
    guard value || DisplaySettingsLogic.canHide(
      showChords: showChords, showLyrics: showLyrics, hiding: .chords) else { return }
    showChords = value
  }

  func setLyrics(_ value: Bool) {
    guard value || DisplaySettingsLogic.canHide(
      showChords: showChords, showLyrics: showLyrics, hiding: .lyrics) else { return }
    showLyrics = value
  }

  func setColumns(_ value: Int) async {
    let value = value == 1 ? 1 : 2
    guard value != columns else { return }
    columns = value
    try? await settingsRepository.updatePreferences(PreferencesPatch(lyricsColumns: value))
  }

  func setChordHand(_ value: ChordHand) async {
    guard value != chordHand else { return }
    chordHand = value
    try? await settingsRepository.updatePreferences(PreferencesPatch(chordHand: value))
  }

  func flushPendingSave() async {
    await saveDebouncer.flush()
  }

  private func scheduleSave() {
    let snapshot = settings.userSettings(songID: songID)
    let repository = settingsRepository
    saveDebouncer.schedule {
      try? await repository.saveSongSettings(snapshot)
    }
  }

  // MARK: Auto-scroll speed

  /// Infers the speed once per song, as soon as the laid-out height is known.
  func contentMeasured(scrollableHeight: Double) {
    guard let song, inferredSpeedForSong != song.id else { return }
    inferredSpeedForSong = song.id
    scrollSpeed = AutoScrollSpeed.inferred(
      bpm: song.bpm, lyrics: song.lyrics, scrollableHeight: scrollableHeight)
  }

  func scrollFaster() { scrollSpeed = AutoScrollSpeed.faster(scrollSpeed) }
  func scrollSlower() { scrollSpeed = AutoScrollSpeed.slower(scrollSpeed) }

  // MARK: Keys

  var displayKey: String? {
    guard let key = song?.key, !key.isEmpty else { return nil }
    return MusicTheory.transposeKey(key, semitones: settings.transpose)
  }

  /// Chord shapes played with the capo on (web song-detail "Play in").
  var capoShapeKey: String? {
    guard settings.capo > 0, let key = displayKey else { return nil }
    return MusicTheory.capoKey(key, capo: settings.capo)
  }

  // MARK: Rendering

  private func rerender() {
    let key = RenderKey(
      lyrics: song?.lyrics ?? "", transpose: settings.transpose, capo: settings.capo)
    guard key != renderedFor else { return }
    renderedFor = key
    rendered = ChordProEngine.render(
      key.lyrics,
      options: ChordProRenderOptions(
        transpose: key.transpose, capo: key.capo, sectionLabels: sectionLabels,
        commentLabel: commentLabel))
  }
}

extension SongPerformanceModel {
  /// Section labels in the user's language, as the web passes them to the pipeline.
  static var localizedSectionLabels: [String: String] {
    [
      "chorus": L10n.SongSections.chorus, "verse": L10n.SongSections.verse,
      "bridge": L10n.SongSections.bridge, "tab": L10n.SongSections.tab,
      "grid": L10n.SongSections.grid, "intro": L10n.SongSections.intro,
      "outro": L10n.SongSections.outro, "pre_chorus": L10n.SongSections.pre_chorus
    ]
  }
}
