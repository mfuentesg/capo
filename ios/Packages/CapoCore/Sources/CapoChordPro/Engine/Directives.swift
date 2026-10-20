// Hand-written equivalents of the directive regexes in song-pipeline.ts.
//
// All of them have the shape `\{(LITERALS)(?::WS([^}]*|[^}]+))?\}` (colon part optional, required or
// absent). Exactly one literal can match at a position because the next character must be `:` or
// `}`, so alternation order does not matter. Backtracking is reproduced where it can change the
// capture: with `[^}]+`, an empty remainder steals the last whitespace character.

struct DirectiveMatch {
  let start: Int
  let end: Int
  /// Index into the pattern's literals (its lowercase spelling is `directive.toLowerCase()`).
  let literal: Int
  /// The `([^}]*)` capture; nil when the optional colon group did not participate.
  let capture: Range<Int>?
}

struct DirectivePattern {
  enum Value { case none, optional, required }

  let literals: [Units]
  let value: Value
  /// `" *"` instead of `\s*` after the colon.
  let spacesOnly: Bool
  /// 1 for `[^}]+`, 0 for `[^}]*`.
  let minCapture: Int

  init(_ literals: [String], value: Value, spacesOnly: Bool = false, minCapture: Int = 0) {
    self.literals = literals.map(\.units)
    self.value = value
    self.spacesOnly = spacesOnly
    self.minCapture = minCapture
  }

  func match(_ s: Units, at i: Int) -> DirectiveMatch? {
    guard i < s.count, s[i] == JS.openBrace else { return nil }
    for (index, literal) in literals.enumerated() where JS.matchesCI(s, at: i + 1, literal) {
      let j = i + 1 + literal.count
      guard j < s.count else { continue }
      if s[j] == JS.colon, value != .none {
        let k = j + 1
        var w = k
        while w < s.count, spacesOnly ? s[w] == JS.space : JS.isWhitespace(s[w]) { w += 1 }
        if let r = JS.indexOf(JS.closeBrace, in: s, from: w) {
          if r - w >= minCapture {
            return DirectiveMatch(start: i, end: r + 1, literal: index, capture: w..<r)
          }
          if w > k {  // `\s*` gives one character back to `[^}]+`
            return DirectiveMatch(start: i, end: r + 1, literal: index, capture: (w - 1)..<w)
          }
        }
        continue  // the group failed and `}` cannot follow the literal (a `:` does)
      }
      if value != .required, s[j] == JS.closeBrace {
        return DirectiveMatch(start: i, end: j + 1, literal: index, capture: nil)
      }
    }
    return nil
  }

  func firstMatch(_ s: Units, from: Int) -> DirectiveMatch? {
    var i = from
    while let brace = JS.indexOf(JS.openBrace, in: s, from: i) {
      if let m = match(s, at: brace) { return m }
      i = brace + 1
    }
    return nil
  }

  /// `text.replace(regex, fn)` with a global regex.
  func replaceAll(_ s: Units, _ replacement: (DirectiveMatch) throws -> Units) rethrows -> Units {
    var out = Units()
    out.reserveCapacity(s.count)
    var last = 0
    var i = 0
    while let brace = JS.indexOf(JS.openBrace, in: s, from: i) {
      if let m = match(s, at: brace) {
        out.append(contentsOf: s[last..<m.start])
        out.append(contentsOf: try replacement(m))
        last = m.end
        i = m.end
      } else {
        i = brace + 1
      }
    }
    if last == 0 { return s }
    out.append(contentsOf: s[last...])
    return out
  }
}

enum Directives {
  static let sectionTypes: [String: String] = [
    "start_of_chorus": "chorus", "soc": "chorus",
    "start_of_verse": "verse", "sov": "verse",
    "start_of_bridge": "bridge", "sob": "bridge",
    "start_of_tab": "tab", "sot": "tab",
    "start_of_grid": "grid", "sog": "grid",
    "start_of_intro": "intro", "soi": "intro",
    "start_of_outro": "outro", "soo": "outro",
    "start_of_pre_chorus": "pre_chorus", "sopc": "pre_chorus"
  ]

  private static let sectionStarts = [
    "start_of_chorus", "soc", "start_of_verse", "sov", "start_of_bridge", "sob", "start_of_tab",
    "sot", "start_of_grid", "sog", "start_of_intro", "soi", "start_of_outro", "soo",
    "start_of_pre_chorus", "sopc"
  ]
  private static let sectionEnds = [
    "end_of_chorus", "eoc", "end_of_verse", "eov", "end_of_bridge", "eob", "end_of_tab", "eot",
    "end_of_grid", "eog", "end_of_intro", "eoi", "end_of_outro", "eoo", "end_of_pre_chorus", "eopc"
  ]
  private static let comments = ["c", "comment", "comment_italic", "comment_box"]

  /// `/\{c(?:omment(?:_italic|_box)?)?: *([^}]*)\}/gi`
  static let commentToken = DirectivePattern(comments, value: .required, spacesOnly: true)
  /// `/\{note: *([^}]*)\}/gi`
  static let noteToken = DirectivePattern(["note"], value: .required, spacesOnly: true)
  /// SECTION_START_RE
  static let sectionStart = DirectivePattern(sectionStarts, value: .optional, minCapture: 1)
  /// SECTION_END_RE and the end-marker search in buildSegments.
  static let sectionEnd = DirectivePattern(sectionEnds, value: .none)
  /// The opening half of blockRe in buildSectionMap.
  static let namedBlockStart = DirectivePattern(sectionStarts, value: .optional, minCapture: 1)
  /// commentRe in buildSectionMap: `/\{c(...)?: *([^}]+)\}/gi`
  static let namedComment = DirectivePattern(
    comments, value: .required, spacesOnly: true, minCapture: 1)
  /// SEGMENT_SCAN_RE
  static let segmentScan = DirectivePattern(
    sectionStarts + comments + ["repeat", "start_of_extend", "soex"], value: .optional)
  static let extendEnd = DirectivePattern(["end_of_extend", "eoex"], value: .none)
  /// VOLTA_SPLIT_RE halves.
  static let voltaStart = DirectivePattern(["start_of_volta", "sovt"], value: .optional)
  static let voltaEnd = DirectivePattern(["end_of_volta", "eovt"], value: .none)
  static let boxOpen = DirectivePattern(["start_of_box", "sbox"], value: .optional)
  static let boxClose = DirectivePattern(["end_of_box", "ebox"], value: .none)

  private static let boundaryLiterals: [Units] = [
    "c", "comment", "comment_italic", "comment_box", "start_of_chorus", "start_of_verse",
    "start_of_bridge", "start_of_tab", "start_of_grid", "start_of_intro", "start_of_outro",
    "start_of_pre_chorus", "soc", "sov", "sob", "sot", "sog", "soi", "soo", "sopc", "repeat",
    "start_of_extend", "soex"
  ].map(\.units)

  /// SECTION_BOUNDARY_RE (case-sensitive): `\{(?:LITERALS)(?:[:\s}])`. Returns the `{` index.
  static func sectionBoundary(_ s: Units, from: Int) -> Int? {
    var i = from
    while let brace = JS.indexOf(JS.openBrace, in: s, from: i) {
      for literal in boundaryLiterals where JS.matches(s, at: brace + 1, literal) {
        let j = brace + 1 + literal.count
        if j < s.count, s[j] == JS.colon || s[j] == JS.closeBrace || JS.isWhitespace(s[j]) {
          return brace
        }
      }
      i = brace + 1
    }
    return nil
  }
}
