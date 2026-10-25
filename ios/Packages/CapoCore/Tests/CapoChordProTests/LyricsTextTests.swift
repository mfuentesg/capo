import Foundation
import Testing

import CapoChordPro

struct LyricsTextTests {
  @Test func foldsSpacingAcuteAfterVowel() {
    #expect(LyricsText.normalized("a\u{B4}") == "\u{E1}")
    #expect(LyricsText.normalized("cora\u{B4}zo\u{B4}n") == "cor\u{E1}zo\u{B4}n".replacingOccurrences(of: "o\u{B4}", with: "\u{F3}"))
  }

  @Test func leavesAcuteAfterConsonantAlone() {
    #expect(LyricsText.normalized("n\u{B4}") == "n\u{B4}")
  }

  @Test func composesDecomposedAccents() {
    let decomposed = "a\u{301}n\u{303}"
    #expect(LyricsText.normalized(decomposed) == "\u{E1}\u{F1}")
    #expect(LyricsText.normalized(decomposed).unicodeScalars.count == 2)
  }

  @Test func asciiIsUntouched() {
    #expect(LyricsText.normalized("[G]Hello [C]world") == "[G]Hello [C]world")
  }

  @Test func chordAfterDecomposedAccentKeepsAccentWithLetter() {
    let rendered = ChordProEngine.render("Can[G]ci\u{F3}n a\u{301}[C]", options: .init(transpose: 0, capo: 0, sectionLabels: [:], commentLabel: "Comment"))
    let pairs = rendered.segments.compactMap { segment -> [ChordLyricPair]? in
      guard case .normal(let body) = segment, case .chordLyrics(let pairs)? = body.lines.first
      else { return nil }
      return pairs
    }.first ?? []
    #expect(pairs.allSatisfy { !($0.lyrics.unicodeScalars.first.map { (0x300...0x36F).contains($0.value) } ?? false) })
  }
}
