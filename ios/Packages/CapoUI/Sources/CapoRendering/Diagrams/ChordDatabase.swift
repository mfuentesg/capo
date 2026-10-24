import Foundation

/// One fingering: `frets` per string low to high (-1 muted, 0 open, else relative to `baseFret`).
/// `fingers` are 0 (none) or 1...4; all zeros means the renderer assigns them.
public nonisolated struct ChordPosition: Hashable, Sendable, Decodable {
  public let baseFret: Int
  public let frets: [Int]
  public let barres: [Int]
  public let fingers: [Int]

  public init(baseFret: Int, frets: [Int], barres: [Int], fingers: [Int]? = nil) {
    self.baseFret = baseFret
    self.frets = frets
    self.barres = barres
    self.fingers = fingers ?? Array(repeating: 0, count: frets.count)
  }

  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    baseFret = try container.decode(Int.self)
    frets = try container.decode([Int].self)
    barres = try container.decode([Int].self)
    fingers = (try? container.decode([Int].self)) ?? Array(repeating: 0, count: frets.count)
  }

  /// Port of `isValidChordPosition`: a barre lies flat across its span, so a lower fret inside it is unplayable.
  public var isPlayable: Bool {
    for barreFret in barres {
      let barred = frets.enumerated().filter { $0.element == barreFret }.map(\.offset)
      guard barred.count >= 2, let low = barred.min(), let high = barred.max() else { continue }
      for string in low...high where frets[string] > 0 && frets[string] < barreFret { return false }
    }
    return true
  }
}

/// What the diagram dialog shows for a chord name.
public nonisolated struct ChordDiagramResult: Equatable, Sendable {
  public let positions: [ChordPosition]
  /// True when the fingerings come from the algorithmic fallback ("Generated Diagram").
  public let isGenerated: Bool

  public static let empty = ChordDiagramResult(positions: [], isGenerated: false)
}

/// Lookup over the bundled `chords.json` (guitar from @tombatossals/chords-db, as the web uses),
/// with the web's algorithmic and base-chord fallbacks.
public nonisolated struct ChordDatabase: Sendable {
  struct Instrument: Decodable, Sendable {
    let strings: Int
    let chords: [String: [String: [ChordPosition]]]
  }

  let table: [String: [String: [ChordPosition]]]

  public static let shared: ChordDatabase = {
    guard
      let url = Bundle.module.url(forResource: "chords", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let instruments = try? JSONDecoder().decode([String: Instrument].self, from: data),
      let guitar = instruments["guitar"]
    else { return ChordDatabase(table: [:]) }
    return ChordDatabase(table: guitar.chords)
  }()

  /// Database positions for a chord name, slash chords only when the exact slash voicing exists.
  public func positions(for chordName: String) -> [ChordPosition] {
    guard let query = ChordNameParser.parse(chordName) else { return [] }
    return exactPositions(query)
  }

  /// Port of chord-diagram.tsx:280-301: exact DB entry, else generated fingerings, else the base chord.
  public func resolve(_ chordName: String) -> ChordDiagramResult {
    var found: [ChordPosition] = []
    let query = ChordNameParser.parse(chordName)
    if let query { found = exactPositions(query) }

    if found.isEmpty {
      let generated = ChordFingering.positions(for: chordName)
      if !generated.isEmpty { return ChordDiagramResult(positions: generated, isGenerated: true) }
    }
    if found.isEmpty, let query { found = table[query.key]?[query.suffix] ?? [] }
    return ChordDiagramResult(positions: found.filter(\.isPlayable), isGenerated: false)
  }

  private func exactPositions(_ query: ChordNameParser.Query) -> [ChordPosition] {
    if let slash = query.slashSuffix { return table[query.key]?[slash] ?? [] }
    return table[query.key]?[query.suffix] ?? []
  }
}

/// Maps a chord symbol to the database's `key` + `suffix` (port of `parseChord` in chord-diagram.tsx).
public nonisolated enum ChordNameParser {
  public struct Query: Equatable, Sendable {
    /// Database key: "C", "Csharp", "Bb", ...
    public let key: String
    public let suffix: String
    /// Database suffix for slash chords ("m/D"), when a bass note is given.
    public let slashSuffix: String?
  }

  private static let rootMap: [String: String] = [
    "A#": "Bb", "Db": "C#", "D#": "Eb", "Gb": "F#", "G#": "Ab", "Cb": "B", "E#": "F", "Fb": "E",
    "B#": "C"
  ]
  /// Bass labels as the database spells them in slash suffixes.
  private static let bassLabel: [String: String] = ["Eb": "D#", "Ab": "G#", "Db": "C#", "Gb": "F#", "A#": "Bb"]

  private static let suffixMap: [String: String] = [
    "": "major", "maj": "major", "major": "major",
    "m": "minor", "min": "minor", "minor": "minor", "mi": "minor", "-": "minor",
    "ø": "m7b5", "ø7": "m7b5", "m7b5": "m7b5", "-7b5": "m7b5",
    "o7": "dim7", "dim7": "dim7", "°7": "dim7", "o": "dim", "dim": "dim", "°": "dim",
    "+": "aug", "aug": "aug", "+5": "aug", "#5": "aug",
    "sus": "sus4", "sus4": "sus4", "sus2": "sus2", "7sus4": "7sus4", "7sus": "7sus4",
    "6/9": "69", "69": "69", "7": "7", "dom7": "7",
    "M7": "maj7", "maj7": "maj7", "ma7": "maj7", "Δ": "maj7", "Δ7": "maj7",
    "m7": "m7", "min7": "m7", "mi7": "m7", "-7": "m7",
    "mM7": "mmaj7", "m(maj7)": "mmaj7", "mmaj7": "mmaj7", "-Δ7": "mmaj7",
    "9": "9", "M9": "maj9", "maj9": "maj9", "m9": "m9", "min9": "m9", "-9": "m9",
    "add9": "add9", "add2": "add9", "2": "add9", "11": "11", "13": "13",
    "7+9": "7#9", "m11": "m11", "maj13": "maj13", "6": "6", "m6": "m6", "-6": "m6"
  ]

  public static func parse(_ name: String) -> Query? {
    let normalizedInput = name.trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "ø", with: "m7b5").replacingOccurrences(of: "°", with: "dim")
      .replacingOccurrences(of: "Δ", with: "maj7").replacingOccurrences(of: "6/9", with: "69")
    guard let first = normalizedInput.first, "ABCDEFG".contains(first) else { return nil }
    var rest = Substring(normalizedInput.dropFirst())
    var root = String(first)
    if let accidental = rest.first, accidental == "#" || accidental == "b" {
      root.append(accidental)
      rest = rest.dropFirst()
    }
    let key = (rootMap[root] ?? root).replacingOccurrences(of: "#", with: "sharp")

    var suffix = String(rest)
    var bass: String?
    if let slash = suffix.lastIndex(of: "/") {
      let candidate = String(suffix[suffix.index(after: slash)...])
      if let b = candidate.first, "ABCDEFG".contains(b), candidate.count <= 2 {
        bass = candidate
        suffix = String(suffix[..<slash])
      }
    }
    suffix = suffix.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
    let normalized = suffixMap[suffix] ?? suffix

    var slashSuffix: String?
    if let bass {
      let label = bassLabel[bass] ?? bass
      slashSuffix = (normalized == "minor" ? "m" : normalized == "major" ? "" : normalized) + "/" + label
    }
    return Query(key: key, suffix: normalized, slashSuffix: slashSuffix)
  }
}
