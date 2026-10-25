import Foundation

/// Unicode clean-up for lyrics. The ChordPro pipeline counts UTF-16 units like the web, so a
/// decomposed accent ("a" + U+0301) can be split from its letter by a chord, and a stray spacing
/// acute ("a´", U+00B4) takes a whole monospace cell of its own. Both render as a misplaced accent.
public enum LyricsText {
  private static let vowels = Set("aeiouAEIOU".unicodeScalars)

  /// Canonical composition only (NFC). Safe before column math on pasted chord-over-lyric text.
  public static func canonical(_ text: String) -> String {
    guard !text.utf8.allSatisfy({ $0 < 0x80 }) else { return text }
    return text.precomposedStringWithCanonicalMapping
  }

  /// NFC plus folding a spacing acute that follows a vowel into a combining acute ("a´" -> "á").
  public static func normalized(_ text: String) -> String {
    guard !text.utf8.allSatisfy({ $0 < 0x80 }) else { return text }
    var folded = String.UnicodeScalarView()
    for scalar in text.unicodeScalars {
      if scalar.value == 0xB4, let last = folded.last, vowels.contains(last) {
        folded.append("\u{0301}")
      } else {
        folded.append(scalar)
      }
    }
    return canonical(String(folded))
  }
}
