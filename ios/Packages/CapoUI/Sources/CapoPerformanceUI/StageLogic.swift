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

/// The controls as one draggable button instead of the docked bar. Persisted per device.
nonisolated enum FloatingControlsPreference {
  static let enabledKey = "ios.stage.floatingControls"
  static let xKey = "ios.stage.floatingControls.x"
  static let yKey = "ios.stage.floatingControls.y"
  /// Bottom-right, above the home indicator, until the player moves it.
  static let defaultFraction = CGPoint(x: 0.88, y: 0.86)
}

/// Where the floating button rests, remembered separately for each orientation and width class,
/// because a spot that suits a portrait phone is wrong on a landscape iPad. Stored as one string,
/// `"p-c=0.88,0.86;l-r=0.9,0.5"`; shapes with no entry fall back to the legacy single position.
nonisolated struct FloatingPlacements: Equatable {
  static let key = "ios.stage.floatingControls.placements"

  /// `p`/`l` for portrait/landscape, `c`/`r` for compact/regular width.
  static func shape(size: CGSize, isRegularWidth: Bool) -> String {
    (size.width > size.height ? "l" : "p") + "-" + (isRegularWidth ? "r" : "c")
  }

  private var values: [String: CGPoint] = [:]

  init(raw: String) {
    for entry in raw.split(separator: ";") {
      let pair = entry.split(separator: "=")
      guard pair.count == 2 else { continue }
      let numbers = pair[1].split(separator: ",").compactMap { Double($0) }
      guard numbers.count == 2 else { continue }
      values[String(pair[0])] = CGPoint(x: numbers[0], y: numbers[1])
    }
  }

  var raw: String {
    values.keys.sorted().map { "\($0)=\(values[$0]!.x),\(values[$0]!.y)" }.joined(separator: ";")
  }

  func fraction(for shape: String, fallback: CGPoint) -> CGPoint { values[shape] ?? fallback }

  mutating func set(_ fraction: CGPoint, for shape: String) { values[shape] = fraction }
}

/// Placement of the floating controls button inside the lyrics area (pure; unit-tested).
nonisolated enum FloatingControlsMath {
  static let buttonSize: CGFloat = 60
  static let margin: CGFloat = 12

  /// Button centre for a stored fraction (0...1 of the area), kept fully inside the area.
  static func center(fraction: CGPoint, in size: CGSize) -> CGPoint {
    clamp(CGPoint(x: fraction.x * size.width, y: fraction.y * size.height), in: size)
  }

  /// Fraction to store for a button centre, clamped to the area.
  static func fraction(center: CGPoint, in size: CGSize) -> CGPoint {
    guard size.width > 0, size.height > 0 else { return FloatingControlsPreference.defaultFraction }
    let c = clamp(center, in: size)
    return CGPoint(x: c.x / size.width, y: c.y / size.height)
  }

  /// The panel opens above the button when it sits in the lower half, below otherwise.
  static func opensAbove(center: CGPoint, in size: CGSize) -> Bool { center.y > size.height / 2 }

  /// `top`/`bottom` keep the button off the status bar and home indicator when the area runs
  /// under them (full screen), without shrinking the area the panel is laid out in.
  static func clamp(_ point: CGPoint, in size: CGSize, top: CGFloat = 0, bottom: CGFloat = 0) -> CGPoint {
    let inset = buttonSize / 2 + margin
    return CGPoint(
      x: min(max(point.x, inset), max(inset, size.width - inset)),
      y: min(max(point.y, inset + top), max(inset + top, size.height - inset - bottom)))
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
