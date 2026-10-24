import CapoChordPro
import Foundation

// Port of features/songs/utils/cifraclub/{validate-url,parse-html}.ts and the types in
// features/songs/types/cifraclub-import.types.ts. The web parses with cheerio/htmlparser2; this
// uses a small tag scanner that covers what the parser reads (pre, h1, meta, ld+json, body text).

public nonisolated enum CifraClubError: String, Error, Sendable, Equatable {
  case invalidURL = "invalid_url"
  case wrongHost = "wrong_host"
  case network
  case httpStatus = "http_status"
  case noChordBlock = "no_chord_block"
  case rateLimited = "rate_limited"
  case unexpected
}

public nonisolated struct CifraClubSong: Sendable, Equatable {
  public var title: String
  public var artist: String
  public var key: String
  public var lyrics: String
  public var keyFound: Bool
}

public nonisolated enum CifraClubParser {
  /// Exact-match allowlist, as on the web.
  static let allowedHosts: Set<String> = ["cifraclub.com", "cifraclub.com.br"]

  public static func validate(_ input: String) -> Result<URL, CifraClubError> {
    guard let url = URL(string: input), url.scheme == "https", let host = url.host(percentEncoded: true)
    else { return .failure(.invalidURL) }
    var hostname = host.lowercased()
    if hostname.hasPrefix("www.") { hostname.removeFirst(4) }
    return allowedHosts.contains(hostname) ? .success(url) : .failure(.wrongHost)
  }

  public static func parse(html: String, url: URL) -> Result<CifraClubSong, CifraClubError> {
    let doc = HTMLScan(html)
    guard let block = chordBlock(doc) else { return .failure(.noChordBlock) }

    let fromURL = titleArtist(from: url)
    let fromLD = jsonLd(doc)
    let fromH1 = doc.firstText(of: "h1").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .flatMap { $0.isEmpty ? nil : $0 }
    let fromOG = ogTitle(doc)

    let title = [fromURL.title, fromLD.title, fromH1, fromOG.title].compactMap { $0 }
      .first { !$0.isEmpty } ?? ""
    let artist = [fromURL.artist, fromLD.artist, fromOG.artist].compactMap { $0 }
      .first { !$0.isEmpty } ?? ""
    let (key, keyFound) = readKey(doc)

    // "[Estribillo]" style labels are not chords: drop the brackets before converting.
    let unbracketed = stripSectionBrackets(block)
    let trimmed = String(units: JSTrim.trim(unbracketed.utf16.map { $0 }))
    let lyrics = ChordProConverter.convertChordAboveLyricsBlocks(trimmed).output
    return .success(CifraClubSong(title: title, artist: artist, key: key, lyrics: lyrics, keyFound: keyFound))
  }

  // MARK: Title and artist

  static func humanize(_ slug: String) -> String {
    slug.split(separator: "-").filter { !$0.isEmpty }.map { word in
      word.prefix(1).uppercased() + word.dropFirst()
    }.joined(separator: " ")
  }

  static func titleArtist(from url: URL) -> (title: String?, artist: String?) {
    let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
    let segments = path.split(separator: "/").map(String.init)
    return (
      segments.count > 1 ? humanize(segments[1]) : nil,
      segments.first.map(humanize)
    )
  }

  static func jsonLd(_ doc: HTMLScan) -> (title: String?, artist: String?) {
    var title: String?
    var artist: String?
    for raw in doc.scripts(ofType: "application/ld+json") {
      guard let data = raw.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: data)
      else { continue }
      let entries = (json as? [Any]) ?? [json]
      for entry in entries {
        guard let record = entry as? [String: Any] else { continue }
        let type = record["@type"]
        let types: [Any] = (type as? [Any]) ?? [type as Any]
        let name = record["name"] as? String
        let byArtist = (record["byArtist"] as? [String: Any])?["name"] as? String
        if title == nil, types.contains(where: { ($0 as? String) == "MusicComposition" }), let name, !name.isEmpty {
          title = name
        }
        if artist == nil, let byArtist, !byArtist.isEmpty { artist = byArtist }
      }
    }
    return (title, artist)
  }

  /// "Title - Artist - Cifra Club"
  static func ogTitle(_ doc: HTMLScan) -> (title: String?, artist: String?) {
    guard let raw = doc.metaContent(property: "og:title")?.trimmingCharacters(in: .whitespacesAndNewlines),
      !raw.isEmpty
    else { return (nil, nil) }
    var text = raw
    if let range = text.range(
      of: #"\s*-\s*Cifra Club\s*$"#, options: [.regularExpression, .caseInsensitive])
    {
      text.removeSubrange(range)
    }
    let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " - ")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    return (parts.first.flatMap { $0.isEmpty ? nil : $0 }, parts.dropFirst().first.flatMap { $0.isEmpty ? nil : $0 })
  }

  // MARK: Key and chord block

  /// `/Tom:\s*([A-G][#b]?m?)/i` over the visible body text.
  static func readKey(_ doc: HTMLScan) -> (key: String, found: Bool) {
    let text = Array(doc.bodyText.utf16)
    var i = 0
    while i + 4 <= text.count {
      if JSMatch.ci(text, i, "tom:") {
        var j = i + 4
        while j < text.count, JSTrim.isWhitespace(text[j]) { j += 1 }
        if j < text.count, (0x41...0x47).contains(text[j]) || (0x61...0x67).contains(text[j]) {
          var end = j + 1
          if end < text.count, text[end] == 0x23 || text[end] == 0x62 || text[end] == 0x42 { end += 1 }
          if end < text.count, text[end] == 0x6D || text[end] == 0x4D { end += 1 }
          return (String(utf16CodeUnits: Array(text[j..<end]), count: end - j), true)
        }
      }
      i += 1
    }
    return ("", false)
  }

  /// Largest `<pre>` text, provided it has at least two non-empty lines.
  static func chordBlock(_ doc: HTMLScan) -> String? {
    let pres = doc.preTexts
    guard var best = pres.first else { return nil }
    for text in pres.dropFirst() where text.utf16.count > best.utf16.count { best = text }
    let lines = best.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    return lines.count >= 2 ? best : nil
  }

  /// `text.replace(/\[([^\]]*)\]/g, "$1")`
  static func stripSectionBrackets(_ text: String) -> String {
    text.replacingOccurrences(of: #"\[([^\]]*)\]"#, with: "$1", options: .regularExpression)
  }
}

/// JS-flavoured helpers kept local so the UI package does not reach into CapoChordPro internals.
nonisolated enum JSTrim {
  static func isWhitespace(_ c: UInt16) -> Bool {
    switch c {
    case 0x09...0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
      return true
    default: return false
    }
  }

  static func trim(_ s: [UInt16]) -> [UInt16] {
    var lo = 0
    var hi = s.count
    while lo < hi, isWhitespace(s[lo]) { lo += 1 }
    while hi > lo, isWhitespace(s[hi - 1]) { hi -= 1 }
    return Array(s[lo..<hi])
  }
}

extension String {
  nonisolated init(units: [UInt16]) { self.init(decoding: units, as: UTF16.self) }
}

nonisolated enum JSMatch {
  /// ASCII case-insensitive literal match at `i`.
  static func ci(_ s: [UInt16], _ i: Int, _ literal: String) -> Bool {
    let lit = Array(literal.utf16)
    guard i + lit.count <= s.count else { return false }
    for k in 0..<lit.count {
      var c = s[i + k]
      if c >= 0x41 && c <= 0x5A { c += 0x20 }
      if c != lit[k] { return false }
    }
    return true
  }
}
