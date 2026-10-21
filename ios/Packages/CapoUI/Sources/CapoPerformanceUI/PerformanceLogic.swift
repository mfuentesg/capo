import CapoCore
import Foundation
import UIKit

/// Transpose, capo and font scale with the web's limits (use-lyrics-settings.ts).
nonisolated struct PerformanceSettings: Hashable, Sendable {
  var transpose: Int
  var capo: Int
  var fontSize: Double

  init(transpose: Int = 0, capo: Int = 0, fontSize: Double = 1) {
    self.transpose = transpose
    self.capo = capo
    self.fontSize = fontSize
  }

  init(_ effective: EffectiveSongSettings) {
    self.init(transpose: effective.transpose, capo: effective.capo, fontSize: effective.fontSize)
  }

  private static let transposeRange = EffectiveSongSettings.transposeRange
  private static let capoRange = EffectiveSongSettings.capoRange
  private static let fontRange = EffectiveSongSettings.fontSizeRange
  private static let fontStep = EffectiveSongSettings.fontSizeStep

  mutating func transposeUp() { transpose = min(transpose + 1, Self.transposeRange.upperBound) }
  mutating func transposeDown() { transpose = max(transpose - 1, Self.transposeRange.lowerBound) }
  mutating func capoUp() { capo = min(capo + 1, Self.capoRange.upperBound) }
  mutating func capoDown() { capo = max(capo - 1, Self.capoRange.lowerBound) }
  mutating func fontUp() { fontSize = min(fontSize + Self.fontStep, Self.fontRange.upperBound) }
  mutating func fontDown() { fontSize = max(fontSize - Self.fontStep, Self.fontRange.lowerBound) }

  var canTransposeUp: Bool { transpose < Self.transposeRange.upperBound }
  var canTransposeDown: Bool { transpose > Self.transposeRange.lowerBound }
  var canCapoUp: Bool { capo < Self.capoRange.upperBound }
  var canCapoDown: Bool { capo > Self.capoRange.lowerBound }
  var canFontUp: Bool { fontSize < Self.fontRange.upperBound }
  var canFontDown: Bool { fontSize > Self.fontRange.lowerBound }

  func userSettings(songID: SongID, at timestamp: ServerTimestamp = .now()) -> UserSongSettings {
    UserSongSettings(
      songID: songID, transpose: transpose, capo: capo, fontSize: fontSize, updatedAt: timestamp)
  }
}

/// Auto-scroll speed in px/s, mirroring lyrics-view.tsx.
nonisolated enum AutoScrollSpeed {
  static let minimum = 10
  static let maximum = 300
  static let step = 10
  static let fallback = 30
  static let beatsPerLine = 4.0

  static func faster(_ speed: Int) -> Int { min(speed + step, maximum) }
  static func slower(_ speed: Int) -> Int { max(speed - step, minimum) }

  /// Lines that are neither blank nor directives (`{...}`); at least 1.
  static func lyricLineCount(_ lyrics: String?) -> Int {
    let count = (lyrics ?? "").split(separator: "\n", omittingEmptySubsequences: false).filter {
      let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
      return !trimmed.isEmpty && !trimmed.hasPrefix("{")
    }.count
    return max(count, 1)
  }

  /// With bpm > 0: scrollableHeight / (lines * 4 / (bpm / 60)), rounded and clamped. A
  /// non-positive height falls back to 30 px per line, like the web.
  static func inferred(bpm: Int?, lyrics: String?, scrollableHeight: Double) -> Int {
    guard let bpm, bpm > 0 else { return fallback }
    let lines = lyricLineCount(lyrics)
    let duration = Double(lines) * beatsPerLine / (Double(bpm) / 60)
    let height = scrollableHeight > 0 ? scrollableHeight : Double(lines) * 30
    let speed = Int((height / duration).rounded(.toNearestOrAwayFromZero))
    return min(max(speed, minimum), maximum)
  }
}

/// Paging and bottom detection for the performance scroll view.
nonisolated enum ScrollMath {
  static let pageFraction = 0.85
  /// The web treats "within 2 px of the end" as the bottom.
  static let bottomTolerance = 2.0

  static func maxOffset(viewport: Double, content: Double) -> Double {
    max(content - viewport, 0)
  }

  static func isAtBottom(offset: Double, viewport: Double, content: Double) -> Bool {
    offset + viewport >= content - bottomTolerance
  }

  /// Reduce Motion: the continuous position snaps down to a multiple of half a viewport, so
  /// auto-scroll advances in discrete steps at the same average speed.
  static func steppedOffset(position: Double, viewport: Double, maxOffset: Double) -> Double {
    let step = viewport * 0.5
    guard step > 0 else { return min(position, maxOffset) }
    return min((position / step).rounded(.down) * step, maxOffset)
  }

  static func pageDown(offset: Double, viewport: Double, content: Double) -> Double {
    min(offset + viewport * pageFraction, maxOffset(viewport: viewport, content: content))
  }

  static func pageUp(offset: Double, viewport: Double) -> Double {
    max(offset - viewport * pageFraction, 0)
  }
}

/// What a key press (or pedal) does in the performance screen.
nonisolated enum PerformanceAction: Hashable, Sendable, CaseIterable {
  case pageDown, pageUp, nextSong, previousSong, toggleAutoScroll, scrollSlower, scrollFaster
  case increaseFont, decreaseFont
}

nonisolated struct PerformanceKeyBinding: Hashable, Sendable {
  let input: String
  let action: PerformanceAction
}

/// PLAN §3 WP7b key table. Bluetooth page turners send arrows, page keys or space.
nonisolated enum PerformanceKeyMap {
  static let bindings: [PerformanceKeyBinding] = [
    .init(input: UIKeyCommand.inputDownArrow, action: .pageDown),
    .init(input: UIKeyCommand.inputPageDown, action: .pageDown),
    .init(input: " ", action: .pageDown),
    .init(input: UIKeyCommand.inputUpArrow, action: .pageUp),
    .init(input: UIKeyCommand.inputPageUp, action: .pageUp),
    .init(input: UIKeyCommand.inputRightArrow, action: .nextSong),
    .init(input: UIKeyCommand.inputLeftArrow, action: .previousSong),
    .init(input: "s", action: .toggleAutoScroll),
    .init(input: "[", action: .scrollSlower),
    .init(input: "]", action: .scrollFaster),
    .init(input: "+", action: .increaseFont),
    .init(input: "=", action: .increaseFont),
    .init(input: "-", action: .decreaseFont)
  ]

  static func action(for input: String) -> PerformanceAction? {
    bindings.first { $0.input == input }?.action
  }
}
