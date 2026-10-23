import CapoDesign

/// Stage-mode copy; thin wrappers over the generated `L10n.Ios.Stage`.
enum StageStrings {
  static var soundsIn: String { L10n.Ios.Stage.soundsIn }
  static var playShapesIn: String { L10n.Ios.Stage.playShapesIn }
  static var key: String { L10n.Ios.Stage.key }
  static var scroll: String { L10n.Ios.Stage.scroll }
  static var autoScroll: String { L10n.Ios.Stage.autoScroll }
  static var textSize: String { L10n.Ios.Stage.textSize }
  static var layout: String { L10n.Ios.Stage.layout }
  static var next: String { L10n.Ios.Stage.next }
  static var play: String { L10n.Ios.Stage.play }
  static var back: String { L10n.Ios.Stage.back }
  static var more: String { L10n.Ios.Stage.more }
  static var chordsToggle: String { L10n.Ios.Stage.chords }
  static var columnsToggle: String { L10n.Ios.Stage.columns }
  static var enterFullscreen: String { L10n.Ios.Stage.enterFullscreen }
  static var exitFullscreen: String { L10n.Ios.Stage.exitFullscreen }
  static var collapseControls: String { L10n.Ios.Stage.collapseControls }
  static var showControls: String { L10n.Ios.Stage.showControls }
  static var controlsToolbar: String { L10n.Ios.Stage.controlsToolbar }
  static func fromBPM(_ bpm: String) -> String { L10n.Ios.Stage.fromBPM(bpm: bpm) }
  static func nextSong(_ title: String) -> String { L10n.Ios.Stage.nextSong(title: title) }
  static func capoShort(_ fret: Int) -> String { L10n.Ios.Stage.capoShort(fret: String(fret)) }
}
