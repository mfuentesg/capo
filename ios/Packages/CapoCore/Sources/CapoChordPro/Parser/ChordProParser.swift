// Port of the chordsheetjs 12.3.1 ChordPro grammar (src/parser/chord_pro/peg_parser.ts, helpers.ts)
// plus the parts of ChordSheetSerializer/SongBuilder/Tag that affect what the pipeline reads.
//
// Rules are ported one to one with PEG semantics: ordered choice commits to the first alternative
// that matches, repetition is greedy, and the whole input must be consumed or parsing throws
// (the web then falls back to raw lyrics).

/// The item kinds the pipeline distinguishes.
enum SongItem: Sendable {
  case pair(chords: Units, lyrics: Units)
  /// `name` is the tag name as `Tag.name` reports it (trimmed); `value` is untrimmed.
  case tag(name: Units, value: Units)
  case comment(Units)
  /// SoftLineBreak, Ternary, Literal: never rendered.
  case other
}

typealias SongLine = [SongItem]

struct ChordProParser {
  private let s: Units
  private var pos = 0

  private init(_ s: Units) { self.s = s }

  static func parse(_ text: Units) throws -> [SongLine] {
    var parser = ChordProParser(JS.normalizeLineEndings(text))
    return try parser.parseChordSheet()
  }

  // MARK: Character helpers

  @inline(__always) private func at(_ i: Int) -> UInt16? { i < s.count ? s[i] : nil }

  @inline(__always) private func isWS(_ c: UInt16) -> Bool {
    c == JS.space || c == JS.tab || c == JS.lf || c == JS.cr
  }

  /// `_`
  private mutating func skipWS() { while let c = at(pos), isWS(c) { pos += 1 } }

  /// `__`
  private mutating func requireWS() -> Bool {
    let start = pos
    skipWS()
    return pos > start
  }

  @inline(__always) private mutating func literal(_ lit: Units) -> Bool {
    if JS.matches(s, at: pos, lit) {
      pos += lit.count
      return true
    }
    return false
  }

  @inline(__always) private mutating func char(_ c: UInt16) -> Bool {
    if at(pos) == c {
      pos += 1
      return true
    }
    return false
  }

  // MARK: ChordSheet

  private mutating func parseChordSheet() throws -> [SongLine] {
    var lines: [SongLine] = []
    while true {
      let component = try parseComponent()
      lines.append(contentsOf: component)
      if let c = at(pos), c == JS.lf || c == JS.cr {
        pos += 1
        continue
      }
      break
    }
    guard pos == s.count else { throw ChordProFailure() }
    return lines
  }

  private mutating func parseComponent() throws -> [SongLine] {
    if let section = try parseSection() { return section }
    return [try parseLine()]
  }

  // MARK: Line

  private mutating func parseLine() throws -> SongLine {
    var items: SongLine = []
    let start = pos
    if parseLyrics() != nil {
      items.append(.pair(chords: [], lyrics: Array(s[start..<pos])))
    }
    while let token = try parseToken() { items.append(contentsOf: token) }
    if let chords = parseChord(), !chords.isEmpty {
      items.append(.pair(chords: chords, lyrics: []))
    }
    if let comment = parseComment(), !comment.isEmpty { items.append(.comment(comment)) }
    while parseSpace() {}
    return items
  }

  private mutating func parseToken() throws -> [SongItem]? {
    if parseChordDefinition() { return [.other] }
    if let tag = try parseTag() { return [tag] }
    if let pair = parseAnnotationLyricsPair() { return [pair] }
    if let pairs = parseChordLyricsPair() { return pairs }
    if parseMetaTernary() { return [.other] }
    if let lyrics = parseLyrics() { return applySoftLineBreaks(lyrics) }
    return nil
  }

  /// `Space? "#" [^\r\n]*`
  private mutating func parseComment() -> Units? {
    let start = pos
    _ = parseSpace()
    guard char(JS.hash) else {
      pos = start
      return nil
    }
    let textStart = pos
    while let c = at(pos), c != JS.lf, c != JS.cr { pos += 1 }
    return Array(s[textStart..<pos])
  }

  /// `[ \t]+`
  @discardableResult
  private mutating func parseSpace() -> Bool {
    let start = pos
    while let c = at(pos), c == JS.space || c == JS.tab { pos += 1 }
    return pos > start
  }

  /// `WordChar`: plain character or a recognised escape.
  private mutating func parseWordChar() -> UInt16? {
    guard let c = at(pos) else { return nil }
    switch c {
    case JS.pipe, JS.openBracket, JS.closeBracket, JS.openBrace, JS.closeBrace, JS.percent,
      JS.hash, JS.cr, JS.lf, JS.tab, JS.space:
      return nil
    case JS.backslash:
      guard let next = at(pos + 1) else { return nil }
      switch next {
      case JS.backslash, JS.pipe, JS.openBracket, JS.closeBracket, JS.openBrace, JS.closeBrace,
        JS.percent, JS.hash, JS.space:
        pos += 2
        return next
      default:
        return nil
      }
    default:
      pos += 1
      return c
    }
  }

  /// `LyricsChar = WordChar / "%" !"{" / "]" / "|" / "}"`
  private mutating func parseLyricsChar() -> UInt16? {
    if let c = parseWordChar() { return c }
    guard let c = at(pos) else { return nil }
    if c == JS.percent {
      if at(pos + 1) == JS.openBrace { return nil }
      pos += 1
      return c
    }
    if c == JS.closeBracket || c == JS.pipe || c == JS.closeBrace {
      pos += 1
      return c
    }
    return nil
  }

  /// `Lyrics = (LyricsChar / Space)+`, returning the unescaped text.
  private mutating func parseLyrics() -> Units? {
    var out = Units()
    while true {
      if let c = parseLyricsChar() {
        out.append(c)
        continue
      }
      let start = pos
      if parseSpace() {
        out.append(contentsOf: s[start..<pos])
        continue
      }
      break
    }
    return out.isEmpty ? nil : out
  }

  /// `"[" ChordChar* "]"`; ChordChar is anything but `]`, CR, LF.
  private mutating func parseChord() -> Units? {
    guard at(pos) == JS.openBracket else { return nil }
    var j = pos + 1
    while let c = at(j), c != JS.closeBracket, c != JS.lf, c != JS.cr { j += 1 }
    guard at(j) == JS.closeBracket else { return nil }
    let chords = Array(s[(pos + 1)..<j])
    pos = j + 1
    return chords
  }

  /// `"[*" ChordChar+ "]" $(Lyrics*) $(Space*)` -> pair without chords (annotation dropped).
  private mutating func parseAnnotationLyricsPair() -> SongItem? {
    guard at(pos) == JS.openBracket, at(pos + 1) == JS.star else { return nil }
    var j = pos + 2
    while let c = at(j), c != JS.closeBracket, c != JS.lf, c != JS.cr { j += 1 }
    guard j > pos + 2, at(j) == JS.closeBracket else { return nil }
    pos = j + 1
    let lyricsStart = pos
    while parseLyrics() != nil {}
    while parseSpace() {}
    return .pair(chords: [], lyrics: Array(s[lyricsStart..<pos]))
  }

  /// `Chord LyricsChar* $(Space*)`
  private mutating func parseChordLyricsPair() -> [SongItem]? {
    guard let chords = parseChord() else { return nil }
    var lyrics = Units()
    while let c = parseLyricsChar() { lyrics.append(c) }
    let spaceStart = pos
    while parseSpace() {}
    lyrics.append(contentsOf: s[spaceStart..<pos])
    return breakChordLyricsPairOnSoftLineBreak(chords, lyrics)
  }

  private func applySoftLineBreaks(_ lyrics: Units) -> [SongItem] {
    guard lyrics.contains(JS.nbsp) else { return [.pair(chords: [], lyrics: lyrics)] }
    var items: [SongItem] = []
    var current = Units()
    for c in lyrics {
      if c == JS.nbsp {
        if !current.isEmpty { items.append(.pair(chords: [], lyrics: current)) }
        current = []
        items.append(.other)
      } else {
        current.append(c)
      }
    }
    if !current.isEmpty { items.append(.pair(chords: [], lyrics: current)) }
    return items
  }

  private func breakChordLyricsPairOnSoftLineBreak(_ chords: Units, _ lyrics: Units) -> [SongItem] {
    var pairs = applySoftLineBreaks(lyrics)
    if !chords.isEmpty {
      if case .pair(_, let firstLyrics)? = pairs.first {
        pairs[0] = .pair(chords: chords, lyrics: firstLyrics)
      } else {
        pairs.insert(.pair(chords: chords, lyrics: []), at: 0)
      }
    }
    return pairs
  }

  // MARK: Tags

  private static func isTagNameChar(_ c: UInt16) -> Bool { JS.isASCIILetter(c) || c == JS.underscore }

  /// `TagSelector = "-" [a-zA-Z0-9\-_]+ "!"?`
  private mutating func parseTagSelector() -> Bool {
    let start = pos
    guard char(JS.minus) else { return false }
    let valueStart = pos
    while let c = at(pos), JS.isASCIILetter(c) || JS.isDigit(c) || c == JS.minus || c == JS.underscore {
      pos += 1
    }
    guard pos > valueStart else {
      pos = start
      return false
    }
    _ = char(0x21)
    return true
  }

  /// `":" TagValue`; returns the simple value ('' for attribute values), nil when absent.
  private mutating func parseTagColonWithValue() -> Units? {
    guard char(JS.colon) else { return nil }
    if parseTagAttributes() { return [] }
    // TagSimpleValue = _ TagValueChar*
    skipWS()
    var value = Units()
    while let c = at(pos) {
      if c == JS.closeBrace || c == JS.lf || c == JS.cr { break }
      if c == JS.backslash {
        guard let next = at(pos + 1), next == JS.backslash || next == JS.closeBrace || next == JS.openBrace
        else { break }
        value.append(next)
        pos += 2
        continue
      }
      value.append(c)
      pos += 1
    }
    return value
  }

  /// `(__ TagAttribute)+`
  private mutating func parseTagAttributes() -> Bool {
    var count = 0
    while true {
      let start = pos
      guard requireWS(), parseTagAttribute() else {
        pos = start
        break
      }
      count += 1
    }
    return count > 0
  }

  /// `[a-zA-Z\-_]+ _ "=" _ "\"" [^"}]* "\""`
  private mutating func parseTagAttribute() -> Bool {
    let start = pos
    while let c = at(pos), JS.isASCIILetter(c) || c == JS.minus || c == JS.underscore { pos += 1 }
    guard pos > start else { return false }
    skipWS()
    guard char(JS.equals) else {
      pos = start
      return false
    }
    skipWS()
    guard char(JS.quote) else {
      pos = start
      return false
    }
    while let c = at(pos), c != JS.quote, c != JS.closeBrace { pos += 1 }
    guard char(JS.quote) else {
      pos = start
      return false
    }
    return true
  }

  /// `"{" _ TagName TagSelector? _ TagColonWithValue? "}"`
  private mutating func parseTag() throws -> SongItem? {
    let start = pos
    guard char(JS.openBrace) else { return nil }
    skipWS()
    let nameStart = pos
    while let c = at(pos), ChordProParser.isTagNameChar(c) { pos += 1 }
    guard pos > nameStart else {
      pos = start
      return nil
    }
    let name = Array(s[nameStart..<pos])
    _ = parseTagSelector()
    skipWS()
    let value = parseTagColonWithValue() ?? []
    guard char(JS.closeBrace) else {
      pos = start
      return nil
    }
    return try ChordProParser.makeTag(name: name, value: value)
  }

  private static let metaName = "meta".units
  /// `Object.prototype` members: `name in ALIASES` finds them and `Tag.name` then throws.
  private static let prototypeNames: Set<Units> = Set(
    [
      "constructor", "__defineGetter__", "__defineSetter__", "hasOwnProperty", "__lookupGetter__",
      "__lookupSetter__", "isPrototypeOf", "propertyIsEnumerable", "toString", "valueOf",
      "__proto__", "toLocaleString"
    ].map(\.units))

  /// `new Tag(name, value)` and the `Tag.name` getter SongBuilder calls right after.
  static func makeTag(name: Units, value: Units) throws -> SongItem {
    var tagName = name
    var tagValue = value
    if name == metaName {
      // parseMetaTag: value.split(/\s(.+)/)
      if value.isEmpty { throw ChordProFailure() }
      var split: Int?
      var i = 0
      while i + 1 < value.count {
        if JS.isWhitespace(value[i]), !JS.isLineTerminator(value[i + 1]) {
          split = i
          break
        }
        i += 1
      }
      if let split {
        tagName = Array(value[..<split])
        var end = split + 1
        while end < value.count, !JS.isLineTerminator(value[end]) { end += 1 }
        tagValue = Array(value[(split + 1)..<end])
      } else {
        tagName = value
        tagValue = []
      }
    }
    let trimmedName = JS.trim(tagName)
    if prototypeNames.contains(trimmedName) { throw ChordProFailure() }
    return .tag(name: trimmedName, value: tagValue)
  }

  // MARK: Chord definitions

  private static let chordLit = "chord".units
  private static let defineLit = "define".units
  private static let fretsLit = "frets".units
  private static let baseFretLit = "base-fret".units
  private static let fingersLit = "fingers".units

  /// `"{" _ ("chord" / "define") TagSelector? _ ":" _ ChordDefinitionValue _ "}"`
  private mutating func parseChordDefinition() -> Bool {
    let start = pos
    guard char(JS.openBrace) else { return false }
    skipWS()
    guard literal(ChordProParser.chordLit) || literal(ChordProParser.defineLit) else {
      pos = start
      return false
    }
    _ = parseTagSelector()
    skipWS()
    guard char(JS.colon) else {
      pos = start
      return false
    }
    skipWS()
    guard parseChordDefinitionValue() else {
      pos = start
      return false
    }
    skipWS()
    guard char(JS.closeBrace) else {
      pos = start
      return false
    }
    return true
  }

  private mutating func parseChordDefinitionNote() -> Bool {
    guard let c = at(pos), (c >= 0x41 && c <= 0x47) || (c >= 0x61 && c <= 0x67) else { return false }
    pos += 1
    if let m = at(pos), m == 0x62 || m == JS.hash || m == 0x266D || m == 0x266F {
      pos += 1
    } else if !literal("es".units), !char(0x73) {
      _ = literal("is".units)
    }
    return true
  }

  private mutating func parseChordDefinitionValue() -> Bool {
    let start = pos
    // ChordDefinitionName = Note Suffix? ("/" Note)?
    guard parseChordDefinitionNote() else { return false }
    while let c = at(pos),
      JS.isASCIILetter(c) || JS.isDigit(c) || c == JS.hash || c == 0x266F || c == 0x266D
        || c == 0x28 || c == 0x29 || c == 0x2B || c == JS.minus || c == JS.slash || c == 0xF8
        || c == 0x0394 || c == 0x2212
    {
      pos += 1
    }
    let bassStart = pos
    if !(char(JS.slash) && parseChordDefinitionNote()) { pos = bassStart }
    skipWS()
    // BaseFret = "base-fret" __ [0-9] __
    let baseStart = pos
    if !(literal(ChordProParser.baseFretLit) && requireWS() && digit() && requireWS()) {
      pos = baseStart
    }
    guard literal(ChordProParser.fretsLit) else {
      pos = start
      return false
    }
    var frets = 0
    while true {
      let fretStart = pos
      // __ Fret, Fret = _ ([0-9] / "-1" / [NXnx])
      guard requireWS() else { break }
      skipWS()
      if digit() || literal("-1".units) || [0x4E, 0x58, 0x6E, 0x78].contains(at(pos) ?? 0) && advance() {
        frets += 1
      } else {
        pos = fretStart
        break
      }
    }
    guard frets > 0 else {
      pos = start
      return false
    }
    // Fingers = __ "fingers" (__ Finger)+
    let fingersStart = pos
    if requireWS(), literal(ChordProParser.fingersLit) {
      var fingers = 0
      while true {
        let fingerStart = pos
        guard requireWS() else { break }
        if let c = at(pos), JS.isDigit(c) || c == JS.minus || JS.isASCIILetter(c) {
          pos += 1
          fingers += 1
        } else {
          pos = fingerStart
          break
        }
      }
      if fingers == 0 { pos = fingersStart }
    } else {
      pos = fingersStart
    }
    return true
  }

  private mutating func digit() -> Bool {
    if let c = at(pos), JS.isDigit(c) {
      pos += 1
      return true
    }
    return false
  }

  private mutating func advance() -> Bool {
    pos += 1
    return true
  }

  // MARK: Meta ternary

  /// `Char = WordChar / Space`, one or more.
  private mutating func parseChars() -> Bool {
    let start = pos
    while parseWordChar() != nil || parseSpace() {}
    return pos > start
  }

  /// `"%{" _ VariableName? ValueTest? _ TrueFalse? _ "}"`
  private mutating func parseMetaTernary() -> Bool {
    let start = pos
    guard at(pos) == JS.percent, at(pos + 1) == JS.openBrace else { return false }
    pos += 2
    skipWS()
    while let c = at(pos), JS.isASCIILetter(c) || JS.isDigit(c) || c == JS.minus || c == JS.underscore {
      pos += 1
    }
    // ValueTest = "=" _ Char+
    let testStart = pos
    if char(JS.equals) {
      skipWS()
      if !parseChars() { pos = testStart }
    }
    skipWS()
    // TrueFalse = "|" _ Expr _ ("|" _ Expr)? _
    let tfStart = pos
    if char(JS.pipe) {
      skipWS()
      if parseMetaExpression() {
        skipWS()
        let falseStart = pos
        if char(JS.pipe) {
          skipWS()
          if !parseMetaExpression() { pos = falseStart }
        }
        skipWS()
      } else {
        pos = tfStart
      }
    }
    skipWS()
    guard char(JS.closeBrace) else {
      pos = start
      return false
    }
    return true
  }

  /// `(Char+ / MetaTernary)+`
  private mutating func parseMetaExpression() -> Bool {
    var count = 0
    while parseChars() || parseMetaTernary() { count += 1 }
    return count > 0
  }

  // MARK: Sections (abc, grid, ly, tab)

  private static let sections: [(start: [Units], end: [Units])] = [
    (["start_of_abc".units], ["end_of_abc".units]),
    (["start_of_grid".units, "sog".units], ["end_of_grid".units, "eog".units]),
    (["start_of_ly".units], ["end_of_ly".units]),
    (["start_of_tab".units, "sot".units], ["end_of_tab".units, "eot".units])
  ]

  private mutating func parseSection() throws -> [SongLine]? {
    for section in ChordProParser.sections {
      let start = pos
      if parseSectionStartTag(section.start), let c = at(pos), c == JS.lf || c == JS.cr {
        pos += 1
        let contentStart = pos
        var j = pos
        while j <= s.count {
          var probe = self
          probe.pos = j
          if probe.parseSectionEndTag(section.end) {
            var content = Array(s[contentStart..<j])
            if content.last == JS.lf { content.removeLast() }
            var lines: [SongLine] = [[.other]]
            lines.append(contentsOf: content.split(separator: JS.lf, omittingEmptySubsequences: false).map { _ in [.other] })
            lines.append([.other])
            pos = probe.pos
            return lines
          }
          j += 1
        }
      }
      pos = start
    }
    return nil
  }

  /// `"{" _ Name TagSelector? _ TagColonWithValue? _ "}"`
  private mutating func parseSectionStartTag(_ names: [Units]) -> Bool {
    let start = pos
    guard char(JS.openBrace) else { return false }
    skipWS()
    guard let name = names.first(where: { JS.matches(s, at: pos, $0) }) else {
      pos = start
      return false
    }
    pos += name.count
    _ = parseTagSelector()
    skipWS()
    _ = parseTagColonWithValue()
    skipWS()
    guard char(JS.closeBrace) else {
      pos = start
      return false
    }
    return true
  }

  /// `"{" _ Name _ "}"`
  private mutating func parseSectionEndTag(_ names: [Units]) -> Bool {
    let start = pos
    guard char(JS.openBrace) else { return false }
    skipWS()
    guard let name = names.first(where: { JS.matches(s, at: pos, $0) }) else {
      pos = start
      return false
    }
    pos += name.count
    skipWS()
    guard char(JS.closeBrace) else {
      pos = start
      return false
    }
    return true
  }
}
