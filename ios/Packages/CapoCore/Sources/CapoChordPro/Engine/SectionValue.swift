/// song-pipeline.ts `parseSectionValue`: `"Name, N, flag, label: Display"`.
struct SectionValue {
  var name: Units
  var count: Int
  var flags: [SectionFlag]
  var displayLabel: Units?

  private static let labelPrefix = "label:".units

  init(_ raw: Units) {
    let parts = raw.split(separator: JS.comma, omittingEmptySubsequences: false).map {
      JS.trim(Array($0))
    }
    name = JS.stripQuotes(parts[0])
    count = 1
    flags = []
    displayLabel = nil
    for part in parts.dropFirst() {
      // /^label:\s*(.+)/i — the part is trimmed, so `.+` starts at the first non-space character.
      if JS.matchesCI(part, at: 0, SectionValue.labelPrefix) {
        var k = SectionValue.labelPrefix.count
        while k < part.count, JS.isWhitespace(part[k]) { k += 1 }
        var end = k
        while end < part.count, !JS.isLineTerminator(part[end]) { end += 1 }
        if end > k {
          displayLabel = JS.trim(JS.stripQuotes(Array(part[k..<end])))
          continue
        }
      }
      if let n = JS.positiveIntegerValue(part) {
        count = n
        continue
      }
      if let flag = SectionFlag(rawValue: String(units: part)) { flags.append(flag) }
    }
  }
}
