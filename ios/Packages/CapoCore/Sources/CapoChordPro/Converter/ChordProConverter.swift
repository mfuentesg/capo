// Port of features/lyrics-editor/utils/chordpro-converter.ts.

public enum DetectedFormat: String, Sendable, Equatable {
  case chordAboveLyrics = "chord-above-lyrics"
  case plainText = "plain-text"
  case chordPro = "chordpro"
}

public enum ChordProConverter {
  /// `/^[A-G][b#]?(m|maj|min|aug|dim|sus|add|M)?[0-9]*(\/[A-G][b#]?)?$/`
  static func isChordToken(_ token: Units) -> Bool {
    var i = 0
    func isRoot(_ c: UInt16) -> Bool { c >= 0x41 && c <= 0x47 }
    func accidental() { if i < token.count, token[i] == 0x62 || token[i] == JS.hash { i += 1 } }
    guard i < token.count, isRoot(token[i]) else { return false }
    i += 1
    accidental()
    // The optional quality is tried in regex order, then the rest must still match; backtrack.
    func tail(_ from: Int) -> Bool {
      var j = from
      while j < token.count, JS.isDigit(token[j]) { j += 1 }
      if j == token.count { return true }
      guard token[j] == JS.slash, j + 1 < token.count, isRoot(token[j + 1]) else { return false }
      j += 2
      if j < token.count, token[j] == 0x62 || token[j] == JS.hash { j += 1 }
      return j == token.count
    }
    let order = ["m", "maj", "min", "aug", "dim", "sus", "add", "M"].map { Array($0.utf16) }
    for w in order where JS.matches(token, at: i, w) {
      if tail(i + w.count) { return true }
    }
    return tail(i)
  }

  static func isChordLine(_ line: Units) -> Bool {
    let trimmed = JS.trim(line)
    var tokens: [Units] = []
    var current = Units()
    for c in trimmed {
      if JS.isWhitespace(c) {
        if !current.isEmpty { tokens.append(current); current = [] }
      } else {
        current.append(c)
      }
    }
    if !current.isEmpty { tokens.append(current) }
    guard !tokens.isEmpty else { return false }
    let chords = tokens.filter(isChordToken).count
    return Double(chords) / Double(tokens.count) >= 0.7
  }

  /// A line with no ChordPro brackets, directives or `#` comments.
  static func isPlainLine(_ line: Units) -> Bool {
    let t = JS.trim(line)
    return !t.contains(JS.openBracket) && t.first != JS.openBrace && t.first != JS.hash
  }

  static func splitLines(_ s: Units) -> [Units] {
    s.split(separator: JS.lf, omittingEmptySubsequences: false).map(Array.init)
  }

  /// `/\[[A-G][^\]]*\]/.test(text)`
  static func hasBracketChord(_ s: Units) -> Bool {
    var i = 0
    while i < s.count {
      if s[i] == JS.openBracket, i + 1 < s.count, s[i + 1] >= 0x41, s[i + 1] <= 0x47 {
        var j = i + 2
        while j < s.count, s[j] != JS.closeBracket { j += 1 }
        if j < s.count { return true }
      }
      i += 1
    }
    return false
  }

  public static func detectFormat(_ text: String) -> DetectedFormat {
    let s = text.units
    if hasBracketChord(s) { return .chordPro }
    let lines = splitLines(s)
    let chordLines = lines.filter(isChordLine).count
    if chordLines > 0, Double(chordLines) >= Double(lines.count) * 0.3 { return .chordAboveLyrics }
    return .plainText
  }

  /// `convertToChordPro`; throws where the web would throw (stray `}` after an inline `key:` line).
  public static func convertToChordPro(_ text: String) throws -> (format: DetectedFormat, output: String) {
    let format = detectFormat(text)
    switch format {
    case .chordPro: return (format, text)
    case .chordAboveLyrics: return (format, try ChordsOverWords.convert(text))
    case .plainText: return (format, text)
    }
  }

  /// Converts unbracketed chord-above-lyrics blocks inside a document that may already hold ChordPro.
  public static func convertChordAboveLyricsBlocks(_ text: String) -> (converted: Bool, output: String) {
    struct Segment {
      var lines: [Units]
      var isPlain: Bool
    }
    var segments: [Segment] = []
    for line in splitLines(text.units) {
      let plain = isPlainLine(line)
      if let last = segments.last, last.isPlain == plain {
        segments[segments.count - 1].lines.append(line)
      } else {
        segments.append(Segment(lines: [line], isPlain: plain))
      }
    }
    var any = false
    var parts: [Units] = []
    func join(_ lines: [Units]) -> Units {
      var out = Units()
      for (n, l) in lines.enumerated() {
        if n > 0 { out.append(JS.lf) }
        out += l
      }
      return out
    }
    for seg in segments {
      guard seg.isPlain else {
        parts.append(join(seg.lines))
        continue
      }
      let hasChord = seg.lines.contains(where: isChordLine)
      let hasLyric = seg.lines.contains { !isChordLine($0) && !JS.trim($0).isEmpty }
      if hasChord, hasLyric, let converted = try? ChordsOverWords.convert(String(units: join(seg.lines))) {
        parts.append(JS.trim(converted.units))
        any = true
      } else {
        parts.append(join(seg.lines))
      }
    }
    return (any, String(units: join(parts)))
  }
}
