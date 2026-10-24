// Port of chordsheetjs 12.3.1 `ChordsOverWordsParser` + `ChordProFormatter` (grammar
// src/parser/chords_over_words/grammar.pegjs and helpers.ts), as the web uses them to turn
// chord-above-lyrics text into ChordPro. Behaviour (including quirks) is pinned by golden tests.

/// Thrown where the PEG grammar rejects its input (the web catches this and keeps the original text).
public struct ChordsOverWordsParseError: Error, Equatable {}

enum ChordsOverWords {
  private enum Item {
    case chord(Chord, column: Int)
    case symbol(UInt16, column: Int)
    var column: Int {
      switch self {
      case .chord(_, let c), .symbol(_, let c): return c
      }
    }
  }

  private enum SheetLine {
    case tag(Units)
    case chords([Item])
    case lyrics(Units)
  }

  private struct Cursor {
    let s: Units
    var i = 0
    var atEnd: Bool { i >= s.count }
    func peek() -> UInt16? { i < s.count ? s[i] : nil }
    mutating func skipBlanks() {
      while i < s.count, s[i] == JS.space || s[i] == JS.tab { i += 1 }
    }
    mutating func newLine() -> Bool {
      if i < s.count, s[i] == JS.lf {
        i += 1
        return true
      }
      return false
    }
  }

  /// `format(parse(text))` with the web's default options.
  static func convert(_ text: String) throws -> String {
    let s = JS.normalizeLineEndings(text.units)
    var c = Cursor(s: s)
    var lines: [Units] = []

    // Metadata? = pairs* trailingPair? separator?
    var meta: [Units] = []
    while true {
      let save = c.i
      if let tag = metadataPair(&c), c.newLine() {
        meta.append(tag)
        continue
      }
      c.i = save
      break
    }
    if let tag = metadataPair(&c) { meta.append(tag) }
    let sep = c.i
    if JS.matches(s, at: c.i, Array("---".utf16)) {
      c.i += 3
      if !c.newLine() { c.i = sep }
    }
    lines.append(contentsOf: meta)

    // ChordSheetContents
    let leadingBlank = c.newLine()
    var sheet: [SheetLine] = []
    while true {
      let save = c.i
      let line = sheetLine(&c)
      if c.newLine() {
        sheet.append(line)
        continue
      }
      c.i = save
      break
    }
    let trailing = sheetLine(&c)
    guard c.atEnd else { throw ChordsOverWordsParseError() }
    sheet.append(trailing)

    if leadingBlank { lines.append([]) }
    var index = 0
    while index < sheet.count {
      switch sheet[index] {
      case .tag(let text):
        lines.append(text)
      case .lyrics(let content):
        lines.append(content)
      case .chords(let items):
        if index + 1 < sheet.count, case .lyrics(let next) = sheet[index + 1], !next.isEmpty {
          lines.append(pair(items, with: next))
          index += 1
        } else {
          lines.append(items.reduce(into: Units()) { $0 += "[".units + chordText($1) + "]".units })
        }
      }
      index += 1
    }
    var out = Units()
    for (n, line) in lines.enumerated() {
      if n > 0 { out.append(JS.lf) }
      out += line
    }
    return String(units: out)
  }

  // MARK: Grammar

  private static func isKeyChar(_ c: UInt16) -> Bool {
    JS.isASCIILetter(c) || JS.isDigit(c) || c == JS.minus || c == JS.underscore
  }

  /// `key _S_ ":" _S_ value` (value = `[^\n\r}]+`). Leaves the cursor after the value.
  private static func keyValue(_ c: inout Cursor) -> (key: Units, value: Units)? {
    let start = c.i
    while let ch = c.peek(), isKeyChar(ch) { c.i += 1 }
    guard c.i > start else { return nil }
    let key = Array(c.s[start..<c.i])
    c.skipBlanks()
    guard c.peek() == JS.colon else { return nil }
    c.i += 1
    c.skipBlanks()
    let valueStart = c.i
    while let ch = c.peek(), ch != JS.lf, ch != JS.cr, ch != JS.closeBrace { c.i += 1 }
    guard c.i > valueStart else { return nil }
    return (key, Array(c.s[valueStart..<c.i]))
  }

  private static func metadataPair(_ c: inout Cursor) -> Units? {
    let save = c.i
    if c.peek() == JS.openBrace {
      c.i += 1
      c.skipBlanks()
      if let (key, value) = keyValue(&c) {
        c.skipBlanks()
        if c.peek() == JS.closeBrace {
          c.i += 1
          return formatTag(key, value)
        }
      }
      c.i = save
    }
    if let (key, value) = keyValue(&c) { return formatTag(key, value) }
    c.i = save
    return nil
  }

  private static let keywords: [Units] = [
    "verse", "chorus", "bridge", "tag", "interlude", "instrumental", "intro"
  ].map { Array($0.utf16) }

  private static func sheetLine(_ c: inout Cursor) -> SheetLine {
    let lineStart = c.i
    var lineEnd = lineStart
    while lineEnd < c.s.count, c.s[lineEnd] != JS.lf { lineEnd += 1 }

    // DirectionLine: _S_ keyword _S_ WordChar* _S_
    var k = lineStart
    while k < lineEnd, c.s[k] == JS.space || c.s[k] == JS.tab { k += 1 }
    if keywords.contains(where: { k + $0.count <= lineEnd && JS.matchesCI(c.s, at: k, $0) }) {
      c.i = lineEnd
      return .tag(formatTag("comment".units, Array(c.s[lineStart..<lineEnd])))
    }
    // InlineMetadata (a prefix match; the caller then fails on a stray `}`)
    var m = c
    if let (key, value) = keyValue(&m) {
      c = m
      return .tag(formatTag(key, value))
    }
    // ChordsLine, only when it spans the whole line
    if let items = chordsLine(c.s, lineStart, lineEnd) {
      c.i = lineEnd
      return .chords(items)
    }
    c.i = lineEnd
    return .lyrics(Array(c.s[lineStart..<lineEnd]))
  }

  private static func chordsLine(_ s: Units, _ start: Int, _ end: Int) -> [Item]? {
    let line = Array(s[..<end])
    var items: [Item] = []
    var i = start
    while true {
      while i < end, line[i] == JS.space || line[i] == JS.tab { i += 1 }
      guard i < end else { break }
      let column = i - start + 1
      let ch = line[i]
      if let (chord, stop) = Chord.parsePrefix(line, at: i, closedSuffix: true), stop > i {
        items.append(.chord(chord, column: column))
        i = stop
      } else if ch == JS.slash || ch == JS.pipe || ch == JS.minus || ch == 0x78 {
        items.append(.symbol(ch, column: column))
        i += 1
      } else {
        return nil
      }
    }
    return items.isEmpty ? nil : items
  }

  // MARK: Output

  private static func formatTag(_ name: Units, _ value: Units) -> Units {
    let trimmed = JS.trim(value)
    var out = "{".units + name
    if !trimmed.isEmpty { out += ": ".units + trimmed }
    return out + "}".units
  }

  private static func chordText(_ item: Item) -> Units {
    switch item {
    case .symbol(let c, _): return [c]
    case .chord(let chord, _):
      let text = (try? chord.toString()) ?? ""
      guard let parsed = Chord.parse(text),
        let normalized = try? parsed.normalize(key: nil, normalizeSuffix: true),
        let rendered = try? normalized.toString()
      else { return text.units }
      return rendered.units
    }
  }

  private static func pair(_ items: [Item], with lyrics: Units) -> Units {
    var out = Units()
    if let first = items.first, first.column > 1 {
      out += lyrics.substring(0, first.column - 1)
    }
    for (n, item) in items.enumerated() {
      let start = item.column - 1
      let end = n + 1 < items.count ? items[n + 1].column - 1 : lyrics.count
      out += "[".units + chordText(item) + "]".units
      out += chopFirstWord(lyrics.substring(start, end))
    }
    return out
  }

  /// `parser_helpers.chopFirstWord` then `${firstWord} ` + soft line breaks on the rest.
  private static func chopFirstWord(_ s: Units) -> Units {
    var i = 0
    while i < s.count {
      if JS.isWhitespace(s[i]) {
        var j = i
        while j < s.count, JS.isWhitespace(s[j]) { j += 1 }
        if j < s.count {
          return JS.trim(Array(s[0..<j])) + [JS.space] + softBreaks(Array(s[j...]))
        }
        i = j
      } else {
        i += 1
      }
    }
    // No second word: `/.+\s+$/` keeps a single trailing space.
    if s.count >= 2, JS.isWhitespace(s[s.count - 1]) { return JS.trim(s) + [JS.space] }
    return s
  }

  /// `rest.split(/\\\s+/)` re-joined with `\ ` (soft line break).
  private static func softBreaks(_ s: Units) -> Units {
    var out = Units()
    var i = 0
    while i < s.count {
      if s[i] == JS.backslash, i + 1 < s.count, JS.isWhitespace(s[i + 1]) {
        var j = i + 1
        while j < s.count, JS.isWhitespace(s[j]) { j += 1 }
        out += [JS.backslash, JS.space]
        i = j
      } else {
        out.append(s[i])
        i += 1
      }
    }
    return out
  }
}

extension Array where Element == UInt16 {
  /// JS `substring(from, to)`: clamps, swaps when reversed.
  fileprivate func substring(_ a: Int, _ b: Int) -> Units {
    let lo = Swift.min(Swift.max(Swift.min(a, b), 0), count)
    let hi = Swift.min(Swift.max(Swift.max(a, b), 0), count)
    return Array(self[lo..<hi])
  }
}
