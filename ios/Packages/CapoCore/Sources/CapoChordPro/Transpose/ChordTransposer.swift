// Single-chord entry points, equivalent to the chordsheetjs calls recorded in chords.json.

public enum ChordTransposer {
  /// `Chord.parse(chord)?.transpose(delta).toString() ?? chord`; unparseable chords are unchanged.
  public static func transpose(_ chord: String, by delta: Int) -> String {
    guard let parsed = Chord.parse(chord) else { return chord }
    return (try? parsed.transpose(delta).toString()) ?? chord
  }

  /// `Chord.parse(chord).normalize(key)` with chordsheetjs' default suffix normalization.
  public static func normalize(_ chord: String, toKey key: String) -> String {
    normalize(chord, toKey: key, normalizeSuffix: true)
  }

  static func normalize(_ chord: String, toKey key: String, normalizeSuffix: Bool) -> String {
    guard let parsed = Chord.parse(chord) else { return chord }
    do {
      // `if (key)`: an empty key string skips enharmonic normalization; others must parse (only
      // looked at when the chord has a root).
      let keyObject = key.isEmpty || parsed.root == nil ? nil : try Key.parseOrFail(key)
      return try parsed.normalize(key: keyObject, normalizeSuffix: normalizeSuffix).toString()
    } catch {
      return chord
    }
  }

  static func parses(_ chord: String) -> Bool { Chord.parse(chord) != nil }
}
