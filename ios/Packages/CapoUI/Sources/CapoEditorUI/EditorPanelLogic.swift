import CoreGraphics
import Foundation

// MARK: Preview panel layout

/// Width and collapsed state of the iPad live-preview panel. Pure so clamping and persistence
/// are testable without a view.
struct PreviewPanelLayout: Equatable {
  static let minWidth: CGFloat = 280
  static let maxWidth: CGFloat = 640
  static let defaultWidth: CGFloat = 440
  /// The editor column never shrinks below this, whatever the panel width.
  static let minEditorWidth: CGFloat = 360

  var width: CGFloat = defaultWidth
  var isCollapsed = false

  /// Clamps `proposed` to the panel range and to what the container can spare.
  static func clamp(_ proposed: CGFloat, containerWidth: CGFloat) -> CGFloat {
    let upper = max(minWidth, min(maxWidth, containerWidth - minEditorWidth))
    return min(max(proposed, minWidth), upper)
  }

  func resolvedWidth(containerWidth: CGFloat) -> CGFloat {
    Self.clamp(width, containerWidth: containerWidth)
  }

  private enum Key {
    static let width = "editor.previewPanel.width"
    static let collapsed = "editor.previewPanel.collapsed"
  }

  static func load(from defaults: UserDefaults = .standard) -> PreviewPanelLayout {
    var layout = PreviewPanelLayout()
    let stored = defaults.double(forKey: Key.width)
    if stored > 0 { layout.width = min(max(CGFloat(stored), minWidth), maxWidth) }
    layout.isCollapsed = defaults.bool(forKey: Key.collapsed)
    return layout
  }

  func save(to defaults: UserDefaults = .standard) {
    defaults.set(Double(width), forKey: Key.width)
    defaults.set(isCollapsed, forKey: Key.collapsed)
  }
}

// MARK: Accessory chips

/// One button on the accessory bar above the keyboard.
struct AccessoryChip: Identifiable, Equatable {
  enum Kind: Equatable { case plain, directive, chord }

  var id: String { label }
  var label: String
  var kind: Kind
  /// Same `$0` caret convention as `DirectiveSnippet`.
  var template: String

  func resolved() -> (text: String, caretOffset: Int) {
    DirectiveSnippet(label: label, template: template).resolved()
  }

  static let fixed: [AccessoryChip] = [
    AccessoryChip(label: "[ ]", kind: .plain, template: "[$0]"),
    AccessoryChip(label: "{ }", kind: .plain, template: "{$0}"),
    AccessoryChip(label: "{sov}", kind: .directive, template: "{sov: $0}\n\n{eov}"),
    AccessoryChip(label: "{soc}", kind: .directive, template: "{soc: $0}\n\n{eoc}"),
    AccessoryChip(label: "{sob}", kind: .directive, template: "{sob: $0}\n\n{eob}"),
    AccessoryChip(label: "{c:}", kind: .directive, template: "{c: $0}"),
    AccessoryChip(label: "{repeat:}", kind: .directive, template: "{repeat: $0}")
  ]

  static func chord(_ name: String) -> AccessoryChip {
    AccessoryChip(label: name, kind: .chord, template: "[\(name)]")
  }

  /// Fixed chips followed by quick chord chips for the song's key.
  static func all(forKey key: String) -> [AccessoryChip] {
    fixed + QuickChords.chords(forKey: key).map(chord)
  }
}

enum QuickChords {
  static let fallback = ["G", "C", "D", "Em", "Am"]
  private static let sharps = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  private static let flats = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
  private static let flatKeys: Set<String> = ["F", "Bb", "Eb", "Ab", "Db", "Gb"]

  /// I, IV, V, vi, ii of a major key; i, iv, v, VI, III of a minor key. `fallback` for an
  /// empty or unrecognised key.
  static func chords(forKey key: String) -> [String] {
    var root = key.trimmingCharacters(in: .whitespaces)
    let minor = root.hasSuffix("m")
    if minor { root.removeLast() }
    let all = sharps.firstIndex(of: root) ?? flats.firstIndex(of: root)
    guard let tonic = all else { return fallback }
    let useFlats = flatKeys.contains(root) || (minor && ["D", "G", "C", "F"].contains(root))
    let names = useFlats ? flats : sharps
    func note(_ semitones: Int) -> String { names[(tonic + semitones) % 12] }
    if minor {
      return [note(0) + "m", note(5) + "m", note(7) + "m", note(8), note(3)]
    }
    return [note(0), note(5), note(7), note(9) + "m", note(2) + "m"]
  }
}

// MARK: Section names

extension LyricsHighlighter {
  private static let sectionDirectives: Set<String> = [
    "sov", "start_of_verse", "soc", "start_of_chorus", "sob", "start_of_bridge",
    "sopc", "start_of_pre_chorus", "sot", "start_of_tab", "sog", "start_of_grid",
    "repeat"
  ]

  /// Ranges of the label inside a section directive, e.g. `Verse 1` in `{sov: Verse 1}` and in
  /// `{repeat: Verse 1, 2}` (up to the comma). `directive` is the full `{...}` text.
  static func sectionNameRange(inDirective directive: String) -> Range<Int>? {
    guard directive.hasPrefix("{"), directive.hasSuffix("}"),
      let colon = directive.firstIndex(of: ":")
    else { return nil }
    let name = directive[directive.index(after: directive.startIndex)..<colon]
      .trimmingCharacters(in: .whitespaces).lowercased()
    guard sectionDirectives.contains(name) else { return nil }
    var start = directive.index(after: colon)
    var end = directive.index(before: directive.endIndex)
    if name == "repeat", let comma = directive[start..<end].firstIndex(of: ",") { end = comma }
    while start < end, directive[start] == " " { start = directive.index(after: start) }
    while end > start, directive[directive.index(before: end)] == " " {
      end = directive.index(before: end)
    }
    guard start < end else { return nil }
    return directive.utf16.distance(from: directive.startIndex, to: start)
      ..< directive.utf16.distance(from: directive.startIndex, to: end)
  }
}
