import Foundation

/// Port of `features/chords/utils/chord-identifier.ts`: fret positions to chord names.
/// Standard tuning E A D G B E; string index 0 is the low E.
nonisolated enum ChordIdentifier {
  struct Identified: Equatable {
    var root: String
    var suffix: String
    var name: String
    var isExact: Bool
    var missingNotes: Int
  }

  static let openStringNotes = [4, 9, 2, 7, 11, 4]
  static let noteNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

  private static let patterns: [(suffix: String, intervals: [Int])] = [
    ("major", [0, 4, 7]), ("minor", [0, 3, 7]), ("dim", [0, 3, 6]), ("aug", [0, 4, 8]),
    ("sus4", [0, 5, 7]), ("sus2", [0, 2, 7]), ("5", [0, 7]),
    ("7", [0, 4, 7, 10]), ("maj7", [0, 4, 7, 11]), ("m7", [0, 3, 7, 10]),
    ("mmaj7", [0, 3, 7, 11]), ("dim7", [0, 3, 6, 9]), ("m7b5", [0, 3, 6, 10]),
    ("7sus4", [0, 5, 7, 10]), ("6", [0, 4, 7, 9]), ("m6", [0, 3, 7, 9]),
    ("add9", [0, 4, 7, 2]), ("9", [0, 4, 7, 10, 2]), ("maj9", [0, 4, 7, 11, 2]),
    ("m9", [0, 3, 7, 10, 2]), ("69", [0, 4, 7, 9, 2]), ("7b9", [0, 4, 7, 10, 1]),
    ("7#9", [0, 4, 7, 10, 3])
  ]

  /// `frets`: -1 muted, 0 open, 1+ relative to `baseFret`.
  static func playedNotes(_ frets: [Int], baseFret: Int) -> [Int] {
    var seen: [Int] = []
    for i in 0..<min(6, frets.count) where frets[i] >= 0 {
      let absolute = frets[i] == 0 ? 0 : frets[i] + baseFret - 1
      let note = (openStringNotes[i] + absolute) % 12
      if !seen.contains(note) { seen.append(note) }
    }
    return seen
  }

  static func identify(_ frets: [Int], baseFret: Int = 1) -> [Identified] {
    let played = Set(playedNotes(frets, baseFret: baseFret))
    guard played.count >= 2 else { return [] }
    var results: [Identified] = []
    for root in 0..<12 where played.contains(root) {
      for pattern in patterns {
        let tones = Set(pattern.intervals.map { (root + $0) % 12 })
        guard played.isSubset(of: tones) else { continue }
        let missing = tones.subtracting(played).count
        let rootName = noteNames[root]
        results.append(
          Identified(
            root: rootName, suffix: pattern.suffix,
            name: pattern.suffix == "major" ? rootName : rootName + pattern.suffix,
            isExact: missing == 0, missingNotes: missing))
      }
    }
    // Stable: exact first, then fewer missing notes (JS sort is stable).
    let ranked = results.enumerated().sorted { a, b in
      if a.element.isExact != b.element.isExact { return a.element.isExact }
      if a.element.missingNotes != b.element.missingNotes { return a.element.missingNotes < b.element.missingNotes }
      return a.offset < b.offset
    }.map(\.element)
    var seenNames = Set<String>()
    return ranked.filter { seenNames.insert($0.name).inserted }
  }

  /// Unique note names from low to high string, muted strings omitted.
  static func notes(_ frets: [Int], baseFret: Int = 1) -> [String] {
    playedNotes(frets, baseFret: baseFret).map { noteNames[$0] }
  }

  /// Database key for a note name (web `NOTE_TO_DB_KEY`).
  static let dbKey: [String: String] = [
    "C": "C", "C#": "Csharp", "Db": "Csharp", "D": "D", "D#": "Eb", "Eb": "Eb", "E": "E", "F": "F",
    "F#": "Fsharp", "Gb": "Fsharp", "G": "G", "G#": "Ab", "Ab": "Ab", "A": "A", "A#": "Bb", "Bb": "Bb",
    "B": "B"
  ]
}
