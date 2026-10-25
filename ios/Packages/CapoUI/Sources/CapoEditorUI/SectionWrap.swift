import Foundation

/// Port of `features/lyrics-editor/utils/section-wrap.ts`: wraps the selected lines in a section directive.
nonisolated struct SectionType: Equatable, Identifiable {
  var label: String
  var key: String
  var start: String
  var end: String
  var id: String { key }

  static let all: [SectionType] = [
    SectionType(label: "Verse", key: "verse", start: "sov", end: "eov"),
    SectionType(label: "Pre-Chorus", key: "prechorus", start: "sopc", end: "eopc"),
    SectionType(label: "Chorus", key: "chorus", start: "soc", end: "eoc"),
    SectionType(label: "Bridge", key: "bridge", start: "sob", end: "eob"),
    SectionType(label: "Intro", key: "intro", start: "soi", end: "eoi"),
    SectionType(label: "Outro", key: "outro", start: "soo", end: "eoo")
  ]

  /// "Verse" for the first one, then "Verse 2", "Verse 3": counts `{sov` / `{start_of_verse` openings.
  func sectionName(in lyrics: String) -> String {
    let pattern = "\\{(?:\(start)|start_of_\(key))"
    let count =
      (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))
      .map { $0.numberOfMatches(in: lyrics, range: NSRange(location: 0, length: (lyrics as NSString).length)) }
      ?? 0
    return count == 0 ? label : "\(label) \(count + 1)"
  }

  func wrap(_ selected: String, in fullLyrics: String) -> String {
    "{\(start): \(sectionName(in: fullLyrics))}\n\(selected)\n{\(end)}"
  }
}
