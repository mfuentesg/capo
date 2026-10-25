import Foundation

/// Port of the `chord-fingering` npm package (guitar, standard tuning) as used by chord-diagram.tsx,
/// including `transformGeneratedChord`. Notes are handled as pitch classes / MIDI pitches.
nonisolated enum ChordFingering {
  struct Placement: Equatable {
    var stringIndex: Int
    var fret: Int
    var pitch: Int
    var pitchClass: Int { pitch % 12 }
  }

  struct Fingering {
    var positions: [Placement]
    var barreFret: Int?
    var barreStrings: [Int]
    var difficulty: Double
  }

  static let openStrings = [40, 45, 50, 55, 59, 64]  // E2 A2 D3 G3 B3 E4
  private static let maxFretDistance = 3
  private static let fingerCount = 4

  // MARK: Chord symbol -> notes

  struct Chord {
    var notes: [Int]
    var optionalNotes: [Int]
    var bass: Int
  }

  private static let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

  private static func pitchClass(_ note: Substring) -> Int? {
    guard let letter = note.first, let base = letters[letter] else { return nil }
    let shift = note.dropFirst().first.map { $0 == "#" ? 1 : $0 == "b" ? -1 : 0 } ?? 0
    return ((base + shift) % 12 + 12) % 12
  }

  /// Semitones of an interval such as "3m", "5A", "9M", "12d".
  private static func semitones(_ interval: String) -> Int {
    let quality = interval.last ?? "P"
    let number = Int(interval.dropLast()) ?? 1
    let degree = (number - 1) % 7
    let major = [0, 2, 4, 5, 7, 9, 11][degree]
    let perfect = degree == 0 || degree == 3 || degree == 4
    var value = major
    switch quality {
    case "m": value -= 1
    case "A": value += 1
    case "d": value -= perfect ? 1 : 2
    default: break
    }
    return ((value % 12) + 12) % 12
  }

  static func findChord(_ symbol: String) -> Chord? {
    var base = symbol
    var inverted: Int?
    if let slash = symbol.lastIndex(of: "/") {
      let tail = symbol[symbol.index(after: slash)...]
      if let first = tail.first, "ABCDEFG".contains(first), tail.count <= 2,
        tail.count == 1 || tail.last == "#" || tail.last == "b"
      {
        inverted = pitchClass(tail)
        base = String(symbol[..<slash])
      }
    }
    guard let first = base.first, "ABCDEFG".contains(first) else { return nil }
    var rest = base.dropFirst()
    var tonicName = String(first)
    if let accidental = rest.first, accidental == "#" || accidental == "b" {
      tonicName.append(accidental)
      rest = rest.dropFirst()
    }
    guard let tonic = pitchClass(Substring(tonicName)) else { return nil }
    let type = String(rest)
    let entry =
      ChordFingeringData.entries.first { $0.symbols.contains(type) }
      ?? ChordFingeringData.entries.first { $0.altSymbols.contains(type) }
    guard let entry else { return nil }
    var notes = entry.intervals.map { (tonic + semitones($0)) % 12 }
    let optional = entry.optional.map { (tonic + semitones($0)) % 12 }
    var bass = tonic
    if let inverted {
      bass = inverted
      if !notes.contains(inverted) { notes.append(inverted) }
    }
    return Chord(notes: notes, optionalNotes: optional, bass: bass)
  }

  // MARK: Fingerings

  private static func pressed(_ f: Fingering) -> [Int] { f.positions.map(\.fret).filter { $0 > 0 } }
  private static func minFret(_ f: Fingering) -> Double { pressed(f).min().map(Double.init) ?? .infinity }
  private static func maxFret(_ f: Fingering) -> Double { pressed(f).max().map(Double.init) ?? -.infinity }

  private static func detectBarre(_ positions: [Placement]) -> (fret: Int, strings: [Int])? {
    guard let minPressed = positions.map(\.fret).filter({ $0 > 0 }).min() else { return nil }
    var barred: [Int] = []
    for string in 0..<openStrings.count {
      guard let position = positions.first(where: { $0.stringIndex == string }) else { continue }
      if position.fret == 0 {
        if !barred.isEmpty { return nil }  // no open strings below barre strings
      } else if position.fret == minPressed {
        barred.append(string)
      }
    }
    return barred.count > 1 ? (minPressed, barred) : nil
  }

  private static func difficulty(_ positions: [Placement], barre: (fret: Int, strings: [Int])?) -> Double {
    var considered = positions.filter { p in
      p.fret > 0 && (barre == nil || p.stringIndex == barre!.strings.last || p.fret != barre!.fret)
    }
    if considered.isEmpty { considered = positions }
    let frets = considered.map(\.fret)
    func distFromNut(_ fret: Int) -> Double { 65 - 65 / pow(2, Double(fret) / 12) }
    var total = 0.0
    for index in frets.indices.dropFirst() {
      total += pow(abs(distFromNut(frets[index]) - distFromNut(frets[index - 1])), 1.1)
    }
    let value = max(0, total + (barre != nil ? 5 : 0) + (considered.count <= 3 ? -3 : 0))
    return (value * 100).rounded() / 100
  }

  private static func mutedBetween(_ f: Fingering) -> Int {
    guard let low = f.positions.first?.stringIndex, let high = f.positions.last?.stringIndex else { return 0 }
    return (low...high).filter { string in !f.positions.contains { $0.stringIndex == string } }.count
  }

  private static func distinctRatio(_ f: Fingering) -> Double {
    Double(Set(f.positions.map(\.pitch)).count) / Double(f.positions.count)
  }

  static func fingerings(for chord: Chord) -> [Fingering] {
    let tuning = openStrings
    var all: [[Placement]] = []
    var positions: [Placement] = []
    for (stringIndex, open) in tuning.enumerated() {
      for note in chord.notes {
        let fret = ((note - open) % 12 + 12) % 12
        positions.append(Placement(stringIndex: stringIndex, fret: fret, pitch: open + fret))
      }
    }
    let required = chord.notes.filter { !chord.optionalNotes.contains($0) }
    var maxBassString = tuning.count - required.count
    if !required.contains(chord.bass) { maxBassString -= 1 }
    let bassPositions = positions.filter { $0.pitchClass == chord.bass && $0.stringIndex <= maxBassString }

    for bass in bassPositions {
      var branch: [[Placement]] = [[bass]]
      for stringIndex in (bass.stringIndex + 1)..<tuning.count {
        let onString = positions.filter { $0.stringIndex == stringIndex }
        branch = branch.flatMap { fingering -> [[Placement]] in
          let nonZero = fingering.map(\.fret).filter { $0 != 0 }
          let sensible = onString.filter { p in
            (p.fret == 0 || nonZero.allSatisfy { abs(p.fret - $0) <= maxFretDistance }) && p.pitch >= bass.pitch
          }
          return sensible.isEmpty ? [fingering] : sensible.map { fingering + [$0] }
        }
      }
      all += branch
    }

    let candidates: [Fingering] = all
      .filter { f in required.allSatisfy { note in f.contains { $0.pitchClass == note } } }
      .map { f in
        let barre = detectBarre(f)
        return Fingering(
          positions: f, barreFret: barre?.fret, barreStrings: barre?.strings ?? [], difficulty: 0)
      }
      .filter(enoughFingers)
      .filter(isAnatomical)
      .map { f in
        var f = f
        f.difficulty = difficulty(
          f.positions, barre: f.barreFret.map { ($0, f.barreStrings) })
        return f
      }

    return candidates.enumerated().sorted { lhs, rhs in
      let order = compare(lhs.element, rhs.element)
      return order != 0 ? order < 0 : lhs.offset < rhs.offset
    }.map(\.element)
  }

  private static func enoughFingers(_ f: Fingering) -> Bool {
    let frets = pressed(f)
    if let barre = f.barreFret { return frets.filter { $0 != barre }.count <= fingerCount - 1 }
    return frets.count <= fingerCount
  }

  private static func isAnatomical(_ f: Fingering) -> Bool {
    guard maxFret(f) - minFret(f) >= 3, f.barreFret == nil else { return true }
    let atMin = f.positions.filter { Double($0.fret) == minFret(f) }.count
    let atMax = f.positions.filter { Double($0.fret) == maxFret(f) }.count
    return atMin + atMax != fingerCount
  }

  /// The package's comparator: first non-zero (and non-NaN) criterion wins.
  private static func compare(_ a: Fingering, _ b: Fingering) -> Double {
    let criteria: [Double] = [
      -Double(min(4, a.positions.count) - min(4, b.positions.count)),
      Double(mutedBetween(a) - mutedBetween(b)),
      -(distinctRatio(a) - distinctRatio(b)),
      max(a.difficulty, 14) - max(b.difficulty, 14),
      Double((a.positions.first?.fret ?? 0) - (b.positions.first?.fret ?? 0)),
      max(a.difficulty, 12) - max(b.difficulty, 12),
      maxFret(a) - maxFret(b),
      a.difficulty - b.difficulty
    ]
    return criteria.first { !$0.isNaN && $0 != 0 } ?? 0
  }

  // MARK: transformGeneratedChord

  /// Generated fingerings in the database's shape; empty when the symbol is unknown.
  static func positions(for symbol: String) -> [ChordPosition] {
    guard let chord = findChord(symbol) else { return [] }
    return fingerings(for: chord).map(transform)
  }

  static func transform(_ f: Fingering) -> ChordPosition {
    var frets = Array(repeating: -1, count: openStrings.count)
    for p in f.positions where p.stringIndex >= 0 && p.stringIndex < frets.count {
      frets[p.stringIndex] = p.fret
    }
    var baseFret = 1
    let active = frets.filter { $0 > 0 }
    if let high = active.max(), high > 4, let low = active.min() { baseFret = low }
    let relative = frets.map { $0 <= 0 ? $0 : $0 - baseFret + 1 }
    let barres = f.barreFret.map { [$0 - baseFret + 1] } ?? []
    return ChordPosition(baseFret: baseFret, frets: relative, barres: barres)
  }
}
