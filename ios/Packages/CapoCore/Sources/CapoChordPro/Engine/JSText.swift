// JavaScript string semantics over UTF-16 code units.
//
// The web pipeline runs on JS strings (UTF-16, `\s`, `trim()`, ASCII-only `/i` folding for ASCII
// patterns). Everything in the engine works on `[UInt16]` so lengths, trimming and matching agree
// with the web byte for byte.

typealias Units = [UInt16]

enum JS {
  // Code units used by the scanners.
  static let lf: UInt16 = 0x0A
  static let cr: UInt16 = 0x0D
  static let tab: UInt16 = 0x09
  static let space: UInt16 = 0x20
  static let quote: UInt16 = 0x22  // "
  static let hash: UInt16 = 0x23  // #
  static let percent: UInt16 = 0x25  // %
  static let apostrophe: UInt16 = 0x27  // '
  static let comma: UInt16 = 0x2C
  static let minus: UInt16 = 0x2D
  static let slash: UInt16 = 0x2F
  static let colon: UInt16 = 0x3A
  static let equals: UInt16 = 0x3D
  static let star: UInt16 = 0x2A
  static let openBracket: UInt16 = 0x5B  // [
  static let backslash: UInt16 = 0x5C
  static let closeBracket: UInt16 = 0x5D  // ]
  static let underscore: UInt16 = 0x5F
  static let openBrace: UInt16 = 0x7B  // {
  static let pipe: UInt16 = 0x7C
  static let closeBrace: UInt16 = 0x7D  // }
  static let nbsp: UInt16 = 0xA0

  /// `\s` in a JS regex, and the set `String.prototype.trim` removes.
  @inline(__always)
  static func isWhitespace(_ c: UInt16) -> Bool {
    switch c {
    case 0x09...0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000,
      0xFEFF:
      return true
    default:
      return false
    }
  }

  /// Characters `.` does not match.
  @inline(__always)
  static func isLineTerminator(_ c: UInt16) -> Bool {
    c == 0x0A || c == 0x0D || c == 0x2028 || c == 0x2029
  }

  @inline(__always)
  static func isDigit(_ c: UInt16) -> Bool { c >= 0x30 && c <= 0x39 }

  @inline(__always)
  static func isASCIILetter(_ c: UInt16) -> Bool {
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)
  }

  @inline(__always)
  static func asciiLower(_ c: UInt16) -> UInt16 {
    (c >= 0x41 && c <= 0x5A) ? c + 0x20 : c
  }

  static func trimmedRange(_ s: Units, _ range: Range<Int>) -> Range<Int> {
    var lo = range.lowerBound
    var hi = range.upperBound
    while lo < hi, isWhitespace(s[lo]) { lo += 1 }
    while hi > lo, isWhitespace(s[hi - 1]) { hi -= 1 }
    return lo..<hi
  }

  static func trim(_ s: Units) -> Units {
    let r = trimmedRange(s, 0..<s.count)
    return r.count == s.count ? s : Array(s[r])
  }

  static func trim(_ s: Units, _ range: Range<Int>) -> Units {
    Array(s[trimmedRange(s, range)])
  }

  static func trimStart(_ s: Units) -> Units {
    var lo = 0
    while lo < s.count, isWhitespace(s[lo]) { lo += 1 }
    return lo == 0 ? s : Array(s[lo...])
  }

  static func trimEnd(_ s: Units) -> Units {
    var hi = s.count
    while hi > 0, isWhitespace(s[hi - 1]) { hi -= 1 }
    return hi == s.count ? s : Array(s[..<hi])
  }

  /// `/\r\n?/g -> "\n"`
  static func normalizeLineEndings(_ s: Units) -> Units {
    guard s.contains(cr) else { return s }
    var out = Units()
    out.reserveCapacity(s.count)
    var i = 0
    while i < s.count {
      if s[i] == cr {
        out.append(lf)
        i += (i + 1 < s.count && s[i + 1] == lf) ? 2 : 1
      } else {
        out.append(s[i])
        i += 1
      }
    }
    return out
  }

  /// ASCII case-insensitive comparison of `s[at...]` with a lowercase ASCII literal. Under a
  /// non-unicode `/i` regex an ASCII pattern letter only matches ASCII letters.
  @inline(__always)
  static func matchesCI(_ s: Units, at: Int, _ literal: Units) -> Bool {
    guard at + literal.count <= s.count else { return false }
    for k in 0..<literal.count where asciiLower(s[at + k]) != literal[k] { return false }
    return true
  }

  @inline(__always)
  static func matches(_ s: Units, at: Int, _ literal: Units) -> Bool {
    guard at + literal.count <= s.count else { return false }
    for k in 0..<literal.count where s[at + k] != literal[k] { return false }
    return true
  }

  static func indexOf(_ c: UInt16, in s: Units, from: Int) -> Int? {
    var i = from
    while i < s.count {
      if s[i] == c { return i }
      i += 1
    }
    return nil
  }

  /// `str.replace(/\s{2,}/g, " ")`
  static func collapseWhitespaceRuns(_ s: Units) -> Units {
    var out = Units()
    out.reserveCapacity(s.count)
    var i = 0
    while i < s.count {
      if isWhitespace(s[i]) {
        var j = i + 1
        while j < s.count, isWhitespace(s[j]) { j += 1 }
        if j - i >= 2 {
          out.append(space)
        } else {
          out.append(s[i])
        }
        i = j
      } else {
        out.append(s[i])
        i += 1
      }
    }
    return out
  }

  /// `str.replace(/^["']|["']$/g, "")`
  static func stripQuotes(_ s: Units) -> Units {
    var lo = 0
    var hi = s.count
    if hi > 0, s[0] == quote || s[0] == apostrophe { lo = 1 }
    if hi - 1 >= lo, hi > 0, s[hi - 1] == quote || s[hi - 1] == apostrophe { hi -= 1 }
    return lo == 0 && hi == s.count ? s : Array(s[lo..<hi])
  }

  /// `parseInt` of a run of ASCII digits; nil when it does not fit (it would index nothing).
  static func parseDigits(_ s: Units, _ range: Range<Int>) -> Int? {
    var value = 0
    for i in range {
      let (m, o1) = value.multipliedReportingOverflow(by: 10)
      let (a, o2) = m.addingReportingOverflow(Int(s[i] - 0x30))
      if o1 || o2 { return nil }
      value = a
    }
    return value
  }

  /// JS `Number(str)` restricted to what `parseSectionValue` needs: returns the value when it is a
  /// positive integer, else nil. Mirrors StringToNumber (decimal with sign/fraction/exponent,
  /// `Infinity`, `0x`/`0o`/`0b` literals, surrounding whitespace).
  static func positiveIntegerValue(_ s: Units) -> Int? {
    let body = trim(s)
    if body.isEmpty { return nil }  // Number("") === 0
    if body.count > 2, body[0] == 0x30 {
      let radix: Int?
      switch asciiLower(body[1]) {
      case 0x78: radix = 16  // x
      case 0x6F: radix = 8  // o
      case 0x62: radix = 2  // b
      default: radix = nil
      }
      if let radix {
        var value = 0.0
        for c in body[2...] {
          let d: Int
          if isDigit(c) {
            d = Int(c - 0x30)
          } else if asciiLower(c) >= 0x61, asciiLower(c) <= 0x66 {
            d = Int(asciiLower(c) - 0x61 + 10)
          } else {
            return nil
          }
          if d >= radix { return nil }
          value = value * Double(radix) + Double(d)
        }
        return integerValue(value)
      }
    }
    var i = 0
    if body[i] == 0x2B || body[i] == minus { i += 1 }
    let unsigned = Array(body[i...])
    if unsigned == Array("Infinity".utf16) { return nil }
    // StrUnsignedDecimalLiteral: digits [. digits] [exp] | . digits [exp]
    var j = 0
    var intDigits = 0
    while j < unsigned.count, isDigit(unsigned[j]) {
      j += 1
      intDigits += 1
    }
    var fracDigits = 0
    if j < unsigned.count, unsigned[j] == 0x2E {
      j += 1
      while j < unsigned.count, isDigit(unsigned[j]) {
        j += 1
        fracDigits += 1
      }
    }
    if intDigits == 0 && fracDigits == 0 { return nil }
    if j < unsigned.count, asciiLower(unsigned[j]) == 0x65 {
      j += 1
      if j < unsigned.count, unsigned[j] == 0x2B || unsigned[j] == minus { j += 1 }
      var expDigits = 0
      while j < unsigned.count, isDigit(unsigned[j]) {
        j += 1
        expDigits += 1
      }
      if expDigits == 0 { return nil }
    }
    if j != unsigned.count { return nil }
    guard let value = Double(String(decoding: body, as: UTF16.self)) else { return nil }
    return integerValue(value)
  }

  private static func integerValue(_ value: Double) -> Int? {
    guard value.isFinite, value > 0, value.rounded(.towardZero) == value else { return nil }
    // Beyond Int range the web shows the exponent form; such counts are not representable here.
    guard value < 9.2e18 else { return Int.max }
    return Int(value)
  }
}

extension String {
  @inline(__always)
  var units: Units { Array(utf16) }

  @inline(__always)
  init(units: Units) {
    self.init(decoding: units, as: UTF16.self)
  }

  @inline(__always)
  init(units: ArraySlice<UInt16>) {
    self.init(decoding: units, as: UTF16.self)
  }
}
