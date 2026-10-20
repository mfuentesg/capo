// Port of chordsheetjs 12.3.1 src/chord.ts and its chord PEG grammar (src/parser/chord).

struct Chord: Sendable {
  var root: Key?
  var suffix: String?
  var bass: Key?

  // MARK: Parsing

  /// `Chord.parse`: trims, then the grammar `Numeral / Numeric / ChordSolfege / ChordSymbol`, which
  /// must consume the whole input. PEG ordered choice: the first alternative that matches wins,
  /// even when it leaves input unconsumed (the parse then fails).
  static func parse(_ string: String) -> Chord? {
    parse(units: string.units)
  }

  static func parse(units: Units) -> Chord? {
    let s = JS.trim(units)
    let parser = ChordGrammar(s: s)
    for alternative in [parser.numeral, parser.numeric, parser.solfege, parser.symbol] {
      if let (ast, end) = alternative() {
        return end == s.count ? Chord(ast: ast) : nil
      }
    }
    return nil
  }

  init(root: Key?, suffix: String?, bass: Key?) {
    self.root = root
    self.suffix = (suffix?.isEmpty ?? true) ? nil : suffix
    self.bass = bass
  }

  private init(ast: ChordGrammar.AST) {
    var root: Key?
    if let base = ast.base {
      root = Key.resolve(
        key: base, type: ast.type,
        minor: Chord.isMinor(base, ast.type, ast.suffix), modifier: ast.modifier)
    }
    var bass: Key?
    if let bassBase = ast.bassBase {
      bass = Key.resolve(key: bassBase, type: ast.type, minor: false, modifier: ast.bassModifier)
    }
    self.init(root: root, suffix: ast.suffix, bass: bass)
  }

  /// utilities.ts `isMinor`.
  private static func isMinor(_ key: String, _ type: ChordType, _ suffix: String?) -> Bool {
    if type == .numeral { return key.lowercased() == key }
    guard let suffix, suffix.utf16.first == 0x6D else { return false }
    let lower = suffix.lowercased()
    return !lower.hasPrefix("ma")
  }

  // MARK: Operations

  func transpose(_ delta: Int) throws -> Chord {
    Chord(root: try root?.transpose(delta), suffix: suffix, bass: try bass?.transpose(delta))
  }

  /// `Chord.normalize(key, { normalizeSuffix })`.
  func normalize(key: Key?, normalizeSuffix: Bool) throws -> Chord {
    let newSuffix = normalizeSuffix ? Chord.normalizeChordSuffix(suffix) : suffix
    var normalizedRoot = root
    if let root {
      normalizedRoot = try root.normalize()
      if let key { normalizedRoot = try normalizedRoot?.normalizeEnharmonics(key) }
    }
    let normalizedBass = try bass?.normalize().normalizeEnharmonics(normalizedRoot)
    return Chord(root: normalizedRoot, suffix: newSuffix, bass: normalizedBass)
  }

  static func normalizeChordSuffix(_ suffix: String?) -> String? {
    guard let suffix else { return nil }
    let mapped = suffixNormalizeMapping[suffix]
    if mapped == "[blank]" { return nil }
    if let mapped, !mapped.isEmpty { return mapped }
    return suffix
  }

  func toString() throws -> String {
    let suffix = self.suffix ?? ""
    let showMinor = suffix.utf16.first != 0x6D
    var chordString = ""
    if let root { chordString = try root.toString(showMinor: showMinor) + suffix }
    if let bass { return chordString + "/" + (try bass.toString()) }
    return chordString
  }
}

/// The chord grammar, rule by rule.
private struct ChordGrammar {
  struct AST {
    var base: String?
    var modifier: Modifier?
    var suffix: String?
    var bassBase: String?
    var bassModifier: Modifier?
    var type: ChordType
  }

  let s: Units

  private func modifier(_ i: Int) -> Modifier? {
    guard i < s.count else { return nil }
    if s[i] == JS.hash { return .sharp }
    if s[i] == 0x62 { return .flat }
    return nil
  }

  private func suffixEnd(_ i: Int) -> Int {
    var j = i
    while j < s.count {
      let c = s[j]
      let ok =
        JS.isASCIILetter(c) || JS.isDigit(c) || c == 0x28 || c == 0x29 || c == JS.hash
        || c == 0x2B || c == JS.minus || c == 0x266D || c == 0x266F || c == 0x0394
      if !ok { break }
      j += 1
    }
    return j
  }

  private func text(_ r: Range<Int>) -> String { String(units: s[r]) }

  /// Shared shape: `prefixModifier? Root Suffix Bass?` / `Bass`.
  private func chord(
    type: ChordType, modifierFirst: Bool, root: (Int) -> Int?, bass: (Int) -> (String, Modifier?, Int)?
  ) -> (AST, Int)? {
    var i = 0
    var mod: Modifier?
    if modifierFirst, let m = modifier(i) {
      mod = m
      i += 1
    }
    if let rootLength = root(i) {
      let base = text(i..<(i + rootLength))
      var j = i + rootLength
      if !modifierFirst, let m = modifier(j) {
        mod = m
        j += 1
      }
      let suffixStart = j
      j = suffixEnd(j)
      var ast = AST(base: base, modifier: mod, suffix: text(suffixStart..<j), type: type)
      if let (bassBase, bassMod, end) = bass(j) {
        ast.bassBase = bassBase
        ast.bassModifier = bassMod
        j = end
      }
      return (ast, j)
    }
    if let (bassBase, bassMod, end) = bass(0) {
      return (AST(bassBase: bassBase, bassModifier: bassMod, type: type), end)
    }
    return nil
  }

  private func numeralRoot(_ i: Int) -> Int? {
    for literal in ["iii", "vii", "ii", "iv", "vi"] where JS.matchesCI(s, at: i, literal.units) {
      return literal.utf16.count
    }
    if i < s.count, [0x49, 0x56, 0x69, 0x76].contains(s[i]) { return 1 }
    return nil
  }

  private func solfegeRoot(_ i: Int) -> Int? {
    for literal in ["do", "re", "mi", "fa", "sol", "la", "si"]
    where JS.matchesCI(s, at: i, literal.units) {
      return literal.utf16.count
    }
    return nil
  }

  private func numericRoot(_ i: Int) -> Int? {
    (i < s.count && s[i] >= 0x31 && s[i] <= 0x37) ? 1 : nil
  }

  private func symbolRoot(_ i: Int) -> Int? {
    guard i < s.count else { return nil }
    let c = s[i]
    return ((c >= 0x41 && c <= 0x47) || (c >= 0x61 && c <= 0x67)) ? 1 : nil
  }

  /// `"/" modifier? Root` (numeral, numeric) or `"/" Root modifier?` (solfege, symbol).
  private func bass(_ i: Int, modifierFirst: Bool, root: (Int) -> Int?) -> (String, Modifier?, Int)? {
    guard i < s.count, s[i] == JS.slash else { return nil }
    var j = i + 1
    var mod: Modifier?
    if modifierFirst, let m = modifier(j) {
      mod = m
      j += 1
    }
    guard let length = root(j) else { return nil }
    let base = text(j..<(j + length))
    j += length
    if !modifierFirst, let m = modifier(j) {
      mod = m
      j += 1
    }
    return (base, mod, j)
  }

  func numeral() -> (AST, Int)? {
    chord(type: .numeral, modifierFirst: true, root: numeralRoot) {
      bass($0, modifierFirst: true, root: numeralRoot)
    }
  }

  func numeric() -> (AST, Int)? {
    chord(type: .numeric, modifierFirst: true, root: numericRoot) {
      bass($0, modifierFirst: true, root: numericRoot)
    }
  }

  func solfege() -> (AST, Int)? {
    chord(type: .solfege, modifierFirst: false, root: solfegeRoot) {
      bass($0, modifierFirst: false, root: solfegeRoot)
    }
  }

  func symbol() -> (AST, Int)? {
    chord(type: .symbol, modifierFirst: false, root: symbolRoot) {
      bass($0, modifierFirst: false, root: symbolRoot)
    }
  }
}
