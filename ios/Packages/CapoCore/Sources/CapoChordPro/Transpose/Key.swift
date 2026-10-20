// Port of chordsheetjs 12.3.1 src/key.ts.
//
// Kept deliberately literal: stepwise transposition, `useModifier(originalModifier)` at the end,
// the truthiness check on `referenceKeyGrade`, and every place the JS throws (those make the web
// render fall back to raw lyrics, so the engine must fail in the same places).

struct ChordProFailure: Error {}

struct Key: Sendable {
  var grade: Int?
  var number: Int?
  var modifier: Modifier?
  var type: ChordType
  var minor: Bool
  var referenceKeyGrade: Int?
  var preferredModifier: Modifier?

  // MARK: Parsing

  /// `Key.parse`: symbol, solfege, numeric, numeral, in that order.
  static func parse(_ string: String) -> Key? {
    let trimmed = JS.trim(string.units)
    if trimmed.isEmpty { return nil }
    return parseSymbol(trimmed) ?? parseSolfege(trimmed) ?? parseNumeric(trimmed)
      ?? parseNumeral(trimmed)
  }

  static func parseOrFail(_ string: String) throws -> Key {
    guard let key = parse(string) else { throw ChordProFailure() }
    return key
  }

  /// Splits an optional `(#|b)?(m)?` tail.
  private static func modifierAndMinor(_ s: Units, from i: Int) -> (Modifier?, Bool)? {
    var j = i
    var modifier: Modifier?
    if j < s.count, s[j] == JS.hash {
      modifier = .sharp
      j += 1
    } else if j < s.count, s[j] == 0x62 {
      modifier = .flat
      j += 1
    }
    var minor = false
    if j < s.count, s[j] == 0x6D {
      minor = true
      j += 1
    }
    return j == s.count ? (modifier, minor) : nil
  }

  private static func parseSymbol(_ s: Units) -> Key? {
    let c = s[0]
    guard (c >= 0x41 && c <= 0x47) || (c >= 0x61 && c <= 0x67) else { return nil }
    guard let (modifier, minor) = modifierAndMinor(s, from: 1) else { return nil }
    return resolve(key: String(units: [c]), type: .symbol, minor: minor, modifier: modifier)
  }

  private static let solfegeNotes: [Units] = [
    "Do", "Re", "Mi", "Fa", "Sol", "La", "Si", "do", "re", "mi", "fa", "sol", "la", "si"
  ].map(\.units)

  private static func parseSolfege(_ s: Units) -> Key? {
    for note in solfegeNotes where JS.matches(s, at: 0, note) {
      if let (modifier, minor) = modifierAndMinor(s, from: note.count) {
        return resolve(key: String(units: note), type: .solfege, minor: minor, modifier: modifier)
      }
    }
    return nil
  }

  private static func parseNumeric(_ s: Units) -> Key? {
    var i = 0
    var modifier: Modifier?
    if s[0] == JS.hash {
      modifier = .sharp
      i = 1
    } else if s[0] == 0x62 {
      modifier = .flat
      i = 1
    }
    guard i < s.count, s[i] >= 0x31, s[i] <= 0x37 else { return nil }
    let digit = s[i]
    var minor = false
    if i + 1 < s.count {
      guard i + 2 == s.count, s[i + 1] == 0x6D else { return nil }
      minor = true
    }
    return resolve(key: String(units: [digit]), type: .numeric, minor: minor, modifier: modifier)
  }

  private static let numerals: Set<String> = [
    "I", "II", "III", "IV", "V", "VI", "VII", "i", "ii", "iii", "iv", "v", "vi", "vii"
  ]

  private static func parseNumeral(_ s: Units) -> Key? {
    var i = 0
    var modifier: Modifier?
    if s[0] == JS.hash {
      modifier = .sharp
      i = 1
    } else if s[0] == 0x62 {
      modifier = .flat
      i = 1
    }
    let note = String(units: s[i...])
    guard numerals.contains(note) else { return nil }
    return resolve(key: note, type: .numeral, minor: false, modifier: modifier)
  }

  /// `Key.resolve`. `minor` is the parsed minor flag; numerals derive it from their case.
  static func resolve(key: String, type: ChordType, minor: Bool, modifier: Modifier?) -> Key {
    let isMinor = type == .numeral ? key.lowercased() == key : minor
    if type == .symbol || type == .solfege {
      if let grade = toGrade(key, ModifierKey(modifier), type, isMinor) {
        return Key(
          grade: 0, number: nil, modifier: modifier, type: type, minor: isMinor,
          referenceKeyGrade: grade, preferredModifier: modifier)
      }
    }
    let number: Int
    if type == .numeric {
      number = Int(key) ?? 0
    } else {
      number = (Scales.romanNumerals.firstIndex(of: key.uppercased()) ?? -1) + 1
    }
    return Key(
      grade: nil, number: number, modifier: modifier, type: type, minor: isMinor,
      referenceKeyGrade: nil, preferredModifier: modifier)
  }

  static func toGrade(_ key: String, _ modifier: ModifierKey, _ type: ChordType, _ minor: Bool)
    -> Int?
  {
    let grades = Scales.keyToGrade(type, minor: minor, modifier)
    return grades[key] ?? grades[key.uppercased()]
  }

  static func shiftGrade(_ grade: Int) -> Int {
    var g = grade
    while g < 0 { g += 12 }
    return g % 12
  }

  // MARK: Grade bookkeeping

  mutating func ensureGrade() throws {
    if grade == nil {
      guard let number else { throw ChordProFailure() }
      grade = Key.toGrade(String(number), ModifierKey(modifier), .numeric, minor)
      self.number = nil
    }
  }

  func effectiveGrade() throws -> Int {
    guard let grade else { throw ChordProFailure() }
    return Key.shiftGrade(grade + (referenceKeyGrade ?? 0))
  }

  func changeGrade(_ delta: Int) throws -> Key {
    var key = self
    if let reference = referenceKeyGrade, reference != 0 {
      key.referenceKeyGrade = Key.shiftGrade(reference + delta)
      return key
    }
    try key.ensureGrade()
    key.grade = Key.shiftGrade((key.grade ?? 0) + delta)
    return key
  }

  func canBeFlat() throws -> Bool {
    if let number { return number != 1 && number != 4 }
    let grade = try effectiveGrade()
    return grade != 4 && grade != 11
  }

  func canBeSharp() throws -> Bool {
    if let number { return number != 3 && number != 7 }
    let grade = try effectiveGrade()
    return grade != 5 && grade != 0
  }

  func useModifier(_ newModifier: Modifier?) throws -> Key {
    var key = self
    try key.ensureGrade()
    key.modifier = newModifier
    return key
  }

  func normalize() throws -> Key {
    var key = self
    try key.ensureGrade()
    if key.modifier == .sharp, try !key.canBeSharp() {
      key.modifier = nil
    } else if key.modifier == .flat, try !key.canBeFlat() {
      key.modifier = nil
    }
    return key
  }

  // MARK: Transposition

  func transpose(_ delta: Int) throws -> Key {
    if delta == 0 { return self }
    let originalModifier = modifier
    var key = self
    for _ in 0..<abs(delta) {
      key = delta < 0 ? try key.transposeDown() : try key.transposeUp()
    }
    return try key.useModifier(originalModifier)
  }

  func transposeUp() throws -> Key {
    var key = try normalize().changeGrade(1)
    if try modifier != nil || !key.canBeSharp() {
      key = try key.useModifier(nil)
    } else {
      key = try key.useModifier(.sharp)
    }
    key.preferredModifier = .sharp
    return try key.normalize()
  }

  func transposeDown() throws -> Key {
    var key = try normalize().changeGrade(-1)
    if try modifier != nil || !key.canBeFlat() {
      key = try key.useModifier(nil)
    } else {
      key = try key.useModifier(.flat)
    }
    key.preferredModifier = .flat
    return key
  }

  // MARK: Output

  func note() throws -> String {
    guard grade != nil else { return try noteForNumber() }
    if (type == .symbol || type == .solfege) && referenceKeyGrade == nil {
      throw ChordProFailure()
    }
    let grade = try effectiveGrade()
    let lookup: (ModifierKey) -> String? = {
      Scales.gradeToKey(self.type, minor: self.minor, $0)[grade]
    }
    var note: String?
    if let modifier { note = lookup(ModifierKey(modifier)) }
    if note == nil { note = lookup(.none) }
    if note == nil, let preferredModifier { note = lookup(ModifierKey(preferredModifier)) }
    if note == nil { note = lookup(.sharp) }
    guard var result = note else { throw ChordProFailure() }
    if minor && type == .numeral { result = result.lowercased() }
    return result
  }

  private func noteForNumber() throws -> String {
    guard let number else { throw ChordProFailure() }
    let prefix = modifier?.string ?? ""
    if type == .numeric { return prefix + String(number) }
    let numeral = (1...7).contains(number) ? Scales.romanNumerals[number - 1] : nil
    if minor {
      guard let numeral else { throw ChordProFailure() }  // undefined.toLowerCase()
      return prefix + numeral.lowercased()
    }
    return prefix + (numeral ?? "undefined")
  }

  func minorSign() throws -> String {
    if !minor { return "" }
    switch type {
    case .symbol, .solfege: return "m"
    case .numeric: return try isNaturalMinor() ? "" : "m"
    case .numeral: return ""
    }
  }

  private func isNaturalMinor() throws -> Bool {
    var key = self
    try key.ensureGrade()
    guard let grade = key.grade, grade != 0 else { throw ChordProFailure() }
    return [1, 2, 3, 4, 5, 8, 9, 10].contains(grade)
  }

  func toString(showMinor: Bool = true) throws -> String {
    let note = try note()
    return showMinor ? note + (try minorSign()) : note
  }

  func normalizeEnharmonics(_ key: Key?) throws -> Key {
    guard let key else { return self }
    let rootKeyString = try key.toString(showMinor: true)
    let thisKeyString = try toString(showMinor: false)
    if let mapping = Scales.enharmonics[rootKeyString], let target = mapping[thisKeyString] {
      var parsed = try Key.parseOrFail(target)
      parsed.minor = minor
      return parsed
    }
    return self
  }
}
