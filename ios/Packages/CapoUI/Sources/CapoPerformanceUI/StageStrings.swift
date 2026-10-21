import Foundation

/// Stage-mode copy that has no generated key yet.
// TODO(i18n): move to the shared catalog (`ios.stage.*`).
enum StageStrings {
  static var soundsIn: String { String(localized: "ios.stage.soundsIn", defaultValue: "Sounds in") }
  static var playShapesIn: String {
    String(localized: "ios.stage.playShapesIn", defaultValue: "Play shapes in")
  }
  static var key: String { String(localized: "ios.stage.key", defaultValue: "Key") }
  static var scroll: String { String(localized: "ios.stage.scroll", defaultValue: "Scroll") }
  static var autoScroll: String { String(localized: "ios.stage.autoScroll", defaultValue: "Auto-scroll") }
  static var textSize: String { String(localized: "ios.stage.textSize", defaultValue: "Text size") }
  static var layout: String { String(localized: "ios.stage.layout", defaultValue: "Layout") }
  static var next: String { String(localized: "ios.stage.next", defaultValue: "Next") }
  static var play: String { String(localized: "ios.stage.play", defaultValue: "Play") }
  static var back: String { String(localized: "ios.stage.back", defaultValue: "Back") }
  static var more: String { String(localized: "ios.stage.more", defaultValue: "More") }
  static var chordsToggle: String {
    String(localized: "ios.stage.chords", defaultValue: "Show chords")
  }
  static var columnsToggle: String {
    String(localized: "ios.stage.columns", defaultValue: "Two columns")
  }
  static var enterFullscreen: String {
    String(localized: "ios.stage.enterFullscreen", defaultValue: "Enter full screen")
  }
  static var exitFullscreen: String {
    String(localized: "ios.stage.exitFullscreen", defaultValue: "Exit full screen")
  }
  static var collapseControls: String {
    String(localized: "ios.stage.collapseControls", defaultValue: "Collapse controls")
  }
  static var showControls: String {
    String(localized: "ios.stage.showControls", defaultValue: "Show controls")
  }
  static var controlsToolbar: String {
    String(localized: "ios.stage.controlsToolbar", defaultValue: "Performance controls")
  }
  static func fromBPM(_ bpm: String) -> String {
    String(localized: "ios.stage.fromBPM", defaultValue: "from \(bpm)")
  }
  static func nextSong(_ title: String) -> String {
    String(localized: "ios.stage.nextSong", defaultValue: "Next song: \(title)")
  }
  static func capoShort(_ fret: Int) -> String {
    String(localized: "ios.stage.capoShort", defaultValue: "capo \(fret)")
  }
}
