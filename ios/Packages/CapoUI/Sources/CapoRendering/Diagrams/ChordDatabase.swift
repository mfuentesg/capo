import Foundation

public nonisolated enum ChordInstrument: String, Sendable, CaseIterable, Identifiable {
  case guitar, ukulele
  public var id: String { rawValue }
}

/// One fingering: `frets` per string low to high (-1 muted, 0 open, else relative to `baseFret`).
public nonisolated struct ChordPosition: Hashable, Sendable, Decodable {
  public let baseFret: Int
  public let frets: [Int]
  public let barres: [Int]

  public init(baseFret: Int, frets: [Int], barres: [Int]) {
    self.baseFret = baseFret
    self.frets = frets
    self.barres = barres
  }

  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    baseFret = try container.decode(Int.self)
    frets = try container.decode([Int].self)
    barres = try container.decode([Int].self)
  }
}

/// Lookup over the bundled `chords.json` (a compact subset of @tombatossals/chords-db, as the web uses).
public nonisolated struct ChordDatabase: Sendable {
  struct Instrument: Decodable, Sendable {
    let strings: Int
    let chords: [String: [String: [ChordPosition]]]
  }

  let instruments: [String: Instrument]

  public static let shared: ChordDatabase = {
    guard
      let url = Bundle.module.url(forResource: "chords", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let instruments = try? JSONDecoder().decode([String: Instrument].self, from: data)
    else { return ChordDatabase(instruments: [:]) }
    return ChordDatabase(instruments: instruments)
  }()

  /// Positions for a chord name such as "F#m7", "Bb/D" or "Cmaj7"; empty when unknown.
  public func positions(for chordName: String, instrument: ChordInstrument) -> [ChordPosition] {
    guard let table = instruments[instrument.rawValue]?.chords,
      let query = ChordNameParser.parse(chordName)
    else { return [] }
    if let slash = query.slashSuffix, let found = table[query.key]?[slash] { return found }
    return table[query.key]?[query.suffix] ?? []
  }
}

/// Maps a chord symbol to the database's `key` + `suffix` (port of `parseChord` in chord-diagram.tsx).
public nonisolated enum ChordNameParser {
  public struct Query: Equatable, Sendable {
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
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard let first = trimmed.first, "ABCDEFG".contains(first) else { return nil }
    var rest = Substring(trimmed.dropFirst())
    var root = String(first)
    if let accidental = rest.first, accidental == "#" || accidental == "b" {
      root.append(accidental)
      rest = rest.dropFirst()
    }
    let key = rootMap[root] ?? root

    var suffix = String(rest)
    var bass: String?
    if let slash = suffix.lastIndex(of: "/"), suffix != "6/9" {
      let candidate = String(suffix[suffix.index(after: slash)...])
      if let b = candidate.first, "ABCDEFG".contains(b), candidate.count <= 2 {
        bass = candidate
        suffix = String(suffix[..<slash])
      }
    }
    suffix = suffix.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
    let normalized = suffixMap[suffix] ?? suffixMap[suffix.lowercased()] ?? suffix

    var slashSuffix: String?
    if let bass {
      let label = bassLabel[bass] ?? bass
      slashSuffix = (normalized == "minor" ? "m" : normalized == "major" ? "" : normalized) + "/" + label
    }
    return Query(key: key, suffix: normalized, slashSuffix: slashSuffix)
  }
}
