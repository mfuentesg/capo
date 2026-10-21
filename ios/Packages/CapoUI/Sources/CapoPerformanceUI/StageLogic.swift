import CapoChordPro
import CoreGraphics
import Foundation

/// "Sounds in A / play shapes in G": the concert key after transpose, and the chord shapes the
/// player fingers once the capo is on.
nonisolated struct StageKeyInfo: Equatable, Sendable {
  let soundsIn: String
  /// nil when no capo is set (the shapes are the sounding chords).
  let playShapesIn: String?

  init?(key: String?, transpose: Int, capo: Int) {
    guard let key, !key.isEmpty else { return nil }
    let sounds = MusicTheory.transposeKey(key, semitones: transpose)
    soundsIn = sounds
    playShapesIn = capo > 0 ? MusicTheory.capoKey(sounds, capo: capo) : nil
  }
}

/// The stage chrome that can be tucked away. Persisted per device.
nonisolated struct StageDockPreference {
  static let defaultsKey = "ios.stage.dockExpanded"
  let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  /// Expanded unless the player collapsed it.
  var isExpanded: Bool {
    get { defaults.object(forKey: Self.defaultsKey) as? Bool ?? true }
    nonmutating set { defaults.set(newValue, forKey: Self.defaultsKey) }
  }
}

/// Full-screen stage: lyrics grow, chrome hides, the dock shrinks to a pill.
nonisolated enum StageFullscreen {
  /// Extra lyric scale applied on top of the user's own text size.
  static let fontBoost = 1.25

  static func fontScale(base: Double, isFullscreen: Bool) -> Double {
    isFullscreen ? base * fontBoost : base
  }

  /// Full screen (and a phone setlist) use a per-visit choice that starts collapsed; otherwise the
  /// persisted preference decides.
  static func showsFullDock(persisted: Bool, transient: Bool, usesTransient: Bool) -> Bool {
    usesTransient ? transient : persisted
  }

  /// A swipe up of at least this much expands the collapsed pill.
  static let expandSwipeDistance: CGFloat = 24
  static func isExpandSwipe(translation: CGSize) -> Bool {
    -translation.height >= expandSwipeDistance && abs(translation.width) < -translation.height
  }
}

/// The centred title pill shows on entry and on tap, then fades after `duration`.
nonisolated struct TitlePillVisibility: Equatable, Sendable {
  static let duration: TimeInterval = 3

  private(set) var shownAt: Date?

  init(shownAt: Date? = nil) { self.shownAt = shownAt }

  mutating func show(at now: Date = .now) { shownAt = now }
  mutating func hide() { shownAt = nil }

  func isVisible(at now: Date) -> Bool {
    guard let shownAt else { return false }
    return now.timeIntervalSince(shownAt) < Self.duration
  }

  /// Seconds left before the pill should fade, for scheduling the hide.
  func remaining(at now: Date) -> TimeInterval {
    guard let shownAt else { return 0 }
    return max(Self.duration - now.timeIntervalSince(shownAt), 0)
  }
}

/// Scroll position as the progress rail draws it.
nonisolated struct StageScrollMetrics: Equatable, Sendable {
  var offset: Double = 0
  var viewport: Double = 0
  var content: Double = 0

  /// Thumb length as a fraction of the rail; 1 when everything fits.
  var thumbFraction: Double {
    guard content > 0, viewport > 0 else { return 1 }
    return min(max(viewport / content, 0.05), 1)
  }

  /// 0 at the top, 1 at the bottom.
  var progress: Double {
    let range = ScrollMath.maxOffset(viewport: viewport, content: content)
    guard range > 0 else { return 0 }
    return min(max(offset / range, 0), 1)
  }

  /// Leading edge of the thumb as a fraction of the rail.
  var thumbStart: Double { progress * (1 - thumbFraction) }

  var isScrollable: Bool { content - viewport > ScrollMath.bottomTolerance }
}

/// Labels for the auto-scroll readout.
nonisolated enum StageAutoScrollLabel {
  static func speed(_ pxPerSecond: Int) -> String { "\(pxPerSecond) px/s" }

  /// "from 72 BPM", only when the song has a tempo.
  static func tempoSource(bpm: Int?) -> String? {
    guard let bpm, bpm > 0 else { return nil }
    return "\(bpm) BPM"
  }

  static func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }
}
