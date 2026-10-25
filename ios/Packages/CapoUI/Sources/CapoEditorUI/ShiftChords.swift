import Foundation

/// Port of `features/lyrics-editor/utils/shift-chords.ts`: rewrites the `[chord]` brackets of a ChordPro
/// text by a number of semitones, leaving lyrics, `{directives}` and non-chords untouched. Changes the stored
/// lyrics only; the song's key, capo and transpose settings are not affected.
nonisolated enum ShiftChords {
  private static let sharpNotes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  private static let flatNotes = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
  private static let noteIndex: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

  // root letter, accidental, suffix (no slash), optional bass letter + accidental
  private static let chordRegex = try! NSRegularExpression(pattern: "^([A-G])([#b]?)([^/]*)(?:/([A-G])([#b]?))?$")
  // a `{...}` directive (kept as is) or a `[chord]` bracket
  private static let tokenRegex = try! NSRegularExpression(pattern: "\\{[^}]*\\}|\\[([^\\]\\n]*)\\]")

  private static func shiftNote(_ letter: String, _ accidental: String, _ semitones: Int, flats: Bool) -> String {
    let base = (noteIndex[Character(letter)] ?? 0) + (accidental == "#" ? 1 : accidental == "b" ? -1 : 0)
    let idx = (((base + semitones) % 12) + 12) % 12
    return (flats ? flatNotes : sharpNotes)[idx]
  }

  /// Shifts one chord symbol; non-chords (`N.C.`, `x2`) come back unchanged.
  /// Shifting down spells accidentals as flats, up as sharps.
  static func shiftChord(_ chord: String, by semitones: Int) -> String {
    let trimmed = chord.trimmingCharacters(in: .whitespaces)
    let ns = trimmed as NSString
    guard let m = chordRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) else {
      return chord
    }
    func group(_ i: Int) -> String? {
      let r = m.range(at: i)
      return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
    let flats = semitones < 0
    let root = shiftNote(group(1) ?? "C", group(2) ?? "", semitones, flats: flats)
    let bass = group(4).map { "/" + shiftNote($0, group(5) ?? "", semitones, flats: flats) } ?? ""
    return root + (group(3) ?? "") + bass
  }

  /// Shifts every `[chord]` in `lyrics` by `semitones`.
  static func shiftLyrics(_ lyrics: String, by semitones: Int) -> String {
    guard semitones != 0 else { return lyrics }
    let ns = lyrics as NSString
    var out = ""
    var last = 0
    for m in tokenRegex.matches(in: lyrics, range: NSRange(location: 0, length: ns.length)) {
      out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
      let chordRange = m.range(at: 1)
      if chordRange.location == NSNotFound {
        out += ns.substring(with: m.range)  // directive
      } else {
        out += "[" + shiftChord(ns.substring(with: chordRange), by: semitones) + "]"
      }
      last = m.range.location + m.range.length
    }
    return out + ns.substring(from: last)
  }
}
