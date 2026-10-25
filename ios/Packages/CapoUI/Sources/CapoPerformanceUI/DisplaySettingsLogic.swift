import CoreGraphics
import Foundation

/// What the lyrics header shows about the display settings (lyrics-view.tsx): the pinging dot on the
/// settings button and one removable chip per setting that differs from its default.
nonisolated enum DisplaySettingsLogic {
  enum Kind: Hashable, Sendable { case transpose, capo, fontSize }

  struct Chip: Identifiable, Hashable, Sendable {
    let kind: Kind
    /// Value text: "+2", "Fret 3", "1.25".
    let value: String
    var id: Kind { kind }
  }

  /// Chips for every setting that differs from `defaults`, in the web's order.
  static func chips(settings: PerformanceSettings, defaults: PerformanceSettings) -> [Chip] {
    var result: [Chip] = []
    if settings.transpose != defaults.transpose {
      result.append(Chip(kind: .transpose, value: signed(settings.transpose)))
    }
    if settings.capo != defaults.capo {
      result.append(Chip(kind: .capo, value: "\(settings.capo)"))
    }
    if settings.fontSize != defaults.fontSize {
      result.append(Chip(kind: .fontSize, value: fontLabel(settings.fontSize)))
    }
    return result
  }

  /// The ping dot: anything changed, or a visibility toggle is off.
  static func isModified(
    settings: PerformanceSettings, defaults: PerformanceSettings, showChords: Bool,
    showLyrics: Bool
  ) -> Bool {
    settings != defaults || !showChords || !showLyrics
  }

  /// Font size as the web prints it: two decimals.
  static func fontLabel(_ value: Double) -> String { String(format: "%.2f", value) }

  /// "+2", "-1", "0".
  static func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

  /// Applies a chip's reset (the chip's x and the popover's Reset button).
  static func reset(
    _ kind: Kind, in settings: inout PerformanceSettings, to defaults: PerformanceSettings
  ) {
    switch kind {
    case .transpose: settings.transpose = defaults.transpose
    case .capo: settings.capo = defaults.capo
    case .fontSize: settings.fontSize = defaults.fontSize
    }
  }

  /// Hiding both chords and lyrics would leave an empty page, so the toggles keep one on.
  static func canHide(showChords: Bool, showLyrics: Bool, hiding target: Visibility) -> Bool {
    switch target {
    case .chords: showLyrics || !showChords
    case .lyrics: showChords || !showLyrics
    }
  }

  enum Visibility: Sendable { case chords, lyrics }

  /// Tempo glyph of the BPM badge: under 90 slow, up to 120 medium, faster otherwise.
  enum Tempo: Sendable {
    case slow, medium, fast
    init(bpm: Int) { self = bpm < 90 ? .slow : (bpm <= 120 ? .medium : .fast) }
  }
}

/// Two lyric columns on a narrow pane: the text shrinks until a column fits, instead of falling back
/// to a single column (the canvas SongIPad board does the same).
nonisolated enum ColumnFit {
  /// Width one column needs at font scale 1 (about 36 characters of the mono face).
  static let referenceColumnWidth: CGFloat = 340
  static let gap: CGFloat = 40
  /// Panes narrower than this still read better as one column.
  static let narrowestTwoColumnPane: CGFloat = 480
  static let minimumScale = 0.65

  /// Multiplier (at most 1) for the font scale so two columns fit `contentWidth`.
  static func scale(contentWidth: CGFloat, columns: Int, fontScale: Double) -> Double {
    guard columns >= 2 else { return 1 }
    let column = (contentWidth - gap) / 2
    let needed = referenceColumnWidth * fontScale
    guard column > 0, needed > 0, column < needed else { return 1 }
    return max(Double(column / needed), minimumScale)
  }

  /// `SongRenderStyle.minTwoColumnWidth` for a pane: two columns survive down to the narrow limit.
  static func minTwoColumnWidth(pane: CGFloat) -> Double {
    pane >= narrowestTwoColumnPane ? 0 : .infinity
  }
}
