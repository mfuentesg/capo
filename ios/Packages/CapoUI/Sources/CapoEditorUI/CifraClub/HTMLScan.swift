import Foundation

/// Minimal HTML scanner (htmlparser2-like): tags, raw-text `script`/`style`, comments and entity
/// decoding. It exposes only what the CifraClub parser reads.
nonisolated struct HTMLScan {
  enum Token {
    case text(String)
    case start(name: String, attrs: [String: String], raw: Bool)
    case end(name: String)
  }

  let tokens: [Token]

  init(_ html: String) {
    tokens = Self.tokenize(Array(html.utf16))
  }

  // MARK: Queries

  /// Text of each `<pre>`, comments excluded, entities decoded.
  var preTexts: [String] {
    var result: [String] = []
    var current: String?
    for token in tokens {
      switch token {
      case .start(let name, _, _) where name == "pre":
        if current == nil { current = "" }
      case .end(let name) where name == "pre":
        if let text = current { result.append(text) }
        current = nil
      case .text(let t):
        if current != nil { current! += t }
      default: break
      }
    }
    if let text = current { result.append(text) }
    return result
  }

  /// Text content of the first `<tag>` element.
  func firstText(of tag: String) -> String? {
    var depthText: String?
    for token in tokens {
      switch token {
      case .start(let name, _, _) where name == tag && depthText == nil: depthText = ""
      case .end(let name) where name == tag && depthText != nil: return depthText
      case .text(let t): if depthText != nil { depthText! += t }
      default: break
      }
    }
    return depthText
  }

  /// Raw contents of `<script type=...>` elements.
  func scripts(ofType type: String) -> [String] {
    var result: [String] = []
    var index = 0
    while index < tokens.count {
      if case .start(let name, let attrs, _) = tokens[index], name == "script", attrs["type"] == type {
        var body = ""
        var j = index + 1
        while j < tokens.count {
          if case .text(let t) = tokens[j] { body += t }
          if case .end(let n) = tokens[j], n == "script" { break }
          j += 1
        }
        result.append(body)
        index = j
      }
      index += 1
    }
    return result
  }

  func metaContent(property: String) -> String? {
    for token in tokens {
      if case .start(let name, let attrs, _) = token, name == "meta", attrs["property"] == property {
        return attrs["content"]
      }
    }
    return nil
  }

  /// Visible text of `<body>`: scripts, styles and comments removed.
  var bodyText: String {
    var inBody = false
    var skip = 0
    var out = ""
    for token in tokens {
      switch token {
      case .start(let name, _, _):
        if name == "body" { inBody = true }
        if name == "script" || name == "style" { skip += 1 }
      case .end(let name):
        if name == "body" { inBody = false }
        if (name == "script" || name == "style") && skip > 0 { skip -= 1 }
      case .text(let t):
        if inBody && skip == 0 { out += t }
      }
    }
    return out
  }

  // MARK: Tokenizer

  private static func tokenize(_ s: [UInt16]) -> [Token] {
    var tokens: [Token] = []
    var text = [UInt16]()
    var i = 0
    func flush(decode: Bool = true) {
      guard !text.isEmpty else { return }
      let raw = String(decoding: text, as: UTF16.self)
      tokens.append(.text(decode ? decodeEntities(raw) : raw))
      text = []
    }
    func isNameStart(_ c: UInt16) -> Bool { (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A }
    while i < s.count {
      let c = s[i]
      guard c == 0x3C else {
        text.append(c)
        i += 1
        continue
      }
      // Comment
      if matches(s, i, "<!--") {
        flush()
        if let end = find(s, "-->", from: i + 4) { i = end + 3 } else { i = s.count }
        continue
      }
      // Declarations and processing instructions
      if i + 1 < s.count, s[i + 1] == 0x21 || s[i + 1] == 0x3F {
        flush()
        i = (s[(i + 1)...].firstIndex(of: 0x3E) ?? s.count - 1) + 1
        continue
      }
      // End tag
      if i + 2 < s.count, s[i + 1] == 0x2F, isNameStart(s[i + 2]) {
        flush()
        var j = i + 2
        while j < s.count, !isSpace(s[j]), s[j] != 0x3E, s[j] != 0x2F { j += 1 }
        tokens.append(.end(name: String(decoding: s[(i + 2)..<j], as: UTF16.self).lowercased()))
        i = (s[j...].firstIndex(of: 0x3E) ?? s.count - 1) + 1
        continue
      }
      // Start tag
      if i + 1 < s.count, isNameStart(s[i + 1]) {
        flush()
        var j = i + 1
        while j < s.count, !isSpace(s[j]), s[j] != 0x3E, s[j] != 0x2F { j += 1 }
        let name = String(decoding: s[(i + 1)..<j], as: UTF16.self).lowercased()
        var attrs: [String: String] = [:]
        // Attributes until '>'
        while j < s.count, s[j] != 0x3E {
          while j < s.count, isSpace(s[j]) || s[j] == 0x2F { j += 1 }
          guard j < s.count, s[j] != 0x3E else { break }
          let nameStart = j
          while j < s.count, !isSpace(s[j]), s[j] != 0x3D, s[j] != 0x3E, s[j] != 0x2F { j += 1 }
          let attrName = String(decoding: s[nameStart..<j], as: UTF16.self).lowercased()
          while j < s.count, isSpace(s[j]) { j += 1 }
          var value = ""
          if j < s.count, s[j] == 0x3D {
            j += 1
            while j < s.count, isSpace(s[j]) { j += 1 }
            if j < s.count, s[j] == 0x22 || s[j] == 0x27 {
              let quote = s[j]
              let start = j + 1
              j = start
              while j < s.count, s[j] != quote { j += 1 }
              value = String(decoding: s[start..<min(j, s.count)], as: UTF16.self)
              j = min(j + 1, s.count)
            } else {
              let start = j
              while j < s.count, !isSpace(s[j]), s[j] != 0x3E { j += 1 }
              value = String(decoding: s[start..<j], as: UTF16.self)
            }
          }
          if !attrName.isEmpty, attrs[attrName] == nil { attrs[attrName] = decodeEntities(value) }
        }
        i = min(j + 1, s.count)
        let raw = name == "script" || name == "style"
        tokens.append(.start(name: name, attrs: attrs, raw: raw))
        if raw {
          let closing = "</" + name
          var k = i
          var end = s.count
          while k < s.count {
            if matches(s, k, closing) { end = k; break }
            k += 1
          }
          if end > i { tokens.append(.text(String(decoding: s[i..<end], as: UTF16.self))) }
          i = end
        }
        continue
      }
      text.append(c)
      i += 1
    }
    flush()
    return tokens
  }

  private static func isSpace(_ c: UInt16) -> Bool { c == 0x20 || (0x09...0x0D).contains(c) }

  private static func matches(_ s: [UInt16], _ i: Int, _ literal: String) -> Bool {
    let lit = Array(literal.utf16)
    guard i + lit.count <= s.count else { return false }
    for k in 0..<lit.count {
      var c = s[i + k]
      if c >= 0x41 && c <= 0x5A { c += 0x20 }
      if c != lit[k] { return false }
    }
    return true
  }

  private static func find(_ s: [UInt16], _ literal: String, from: Int) -> Int? {
    var k = from
    while k < s.count {
      if matches(s, k, literal) { return k }
      k += 1
    }
    return nil
  }

  // MARK: Entities

  private static let named: [String: String] = {
    var table: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'"]
    let latin1 = [
      "nbsp", "iexcl", "cent", "pound", "curren", "yen", "brvbar", "sect", "uml", "copy", "ordf",
      "laquo", "not", "shy", "reg", "macr", "deg", "plusmn", "sup2", "sup3", "acute", "micro", "para",
      "middot", "cedil", "sup1", "ordm", "raquo", "frac14", "frac12", "frac34", "iquest", "Agrave",
      "Aacute", "Acirc", "Atilde", "Auml", "Aring", "AElig", "Ccedil", "Egrave", "Eacute", "Ecirc",
      "Euml", "Igrave", "Iacute", "Icirc", "Iuml", "ETH", "Ntilde", "Ograve", "Oacute", "Ocirc",
      "Otilde", "Ouml", "times", "Oslash", "Ugrave", "Uacute", "Ucirc", "Uuml", "Yacute", "THORN",
      "szlig", "agrave", "aacute", "acirc", "atilde", "auml", "aring", "aelig", "ccedil", "egrave",
      "eacute", "ecirc", "euml", "igrave", "iacute", "icirc", "iuml", "eth", "ntilde", "ograve",
      "oacute", "ocirc", "otilde", "ouml", "divide", "oslash", "ugrave", "uacute", "ucirc", "uuml",
      "yacute", "thorn", "yuml"
    ]
    for (offset, name) in latin1.enumerated() {
      table[name] = String(UnicodeScalar(UInt32(160 + offset))!)
    }
    return table
  }()

  static func decodeEntities(_ s: String) -> String {
    guard s.contains("&") else { return s }
    var out = ""
    var rest = Substring(s)
    while let amp = rest.firstIndex(of: "&") {
      out += rest[..<amp]
      let after = rest[rest.index(after: amp)...]
      if let semi = after.prefix(12).firstIndex(of: ";") {
        let body = after[..<semi]
        var decoded: String?
        if body.hasPrefix("#") {
          let digits = body.dropFirst()
          let value: UInt32? =
            digits.first == "x" || digits.first == "X"
            ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
          decoded = value.flatMap(UnicodeScalar.init).map { String($0) }
        } else {
          decoded = named[String(body)]
        }
        if let decoded {
          out += decoded
          rest = after[after.index(after: semi)...]
          continue
        }
      }
      out += "&"
      rest = after
    }
    out += rest
    return out
  }
}
