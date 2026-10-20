// Port of lib/music-theory.ts.

public enum MusicTheory {
  private static let noteIndex: [String: Int] = [
    "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10,
    "B": 11
  ]
  private static let sharpNotes = [
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
  ]
  private static let flatNotes = [
    "C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"
  ]
  private static let flatToSharp = ["Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"]

  /// `transposeKey`: root `[A-G][#b]?`, sharps when going up or when the root is sharp.
  public static func transposeKey(_ key: String, semitones: Int) -> String {
    if key.isEmpty || semitones == 0 { return key }
    // /^([A-G][#b]?)(.*)?$/ — `.` stops at line terminators, so those keys do not match.
    let units = key.units
    guard units[0] >= 0x41, units[0] <= 0x47, !units.contains(where: JS.isLineTerminator) else {
      return key
    }
    var rootLength = 1
    if units.count > 1, units[1] == JS.hash || units[1] == 0x62 { rootLength = 2 }
    let rootNote = String(units: units[..<rootLength])
    let modifier = String(units: units[rootLength...])
    let normalizedRoot = flatToSharp[rootNote] ?? rootNote
    guard let currentIndex = noteIndex[normalizedRoot] else { return key }
    var newIndex = (currentIndex + semitones) % 12
    if newIndex < 0 { newIndex += 12 }
    let preferSharps = semitones >= 0 || rootNote.contains("#")
    return (preferSharps ? sharpNotes : flatNotes)[newIndex] + modifier
  }

  /// `calculateCapoKey`: the shape key played with the capo on.
  public static func capoKey(_ key: String, capo: Int) -> String {
    if capo == 0 { return key }
    return transposeKey(key, semitones: -capo)
  }

  /// `calculateEffectiveKey`: transpose first, then the capo raises the pitch.
  public static func effectiveKey(_ key: String, transpose: Int, capo: Int) -> String {
    var effective = transposeKey(key, semitones: transpose)
    if capo > 0 { effective = transposeKey(effective, semitones: capo) }
    return effective
  }
}
