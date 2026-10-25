import Foundation
import Testing

import CapoChordPro

/// WP1 DoD: rendering a 300-line song takes under 5 ms in release
/// (`swift test -c release --filter Perf`). Debug builds only check a loose bound.
@Suite struct PerfTests {
  static func song(lines: Int) -> String {
    let block = [
      "{sov: Verse}", "[G]Amazing [C]grace, how [G]sweet the [D]sound",
      "That [G]saved a [Em]wretch like [D/F#]me", "{eov}", "{soc: Chorus, 2, forte}",
      "[C]I once was [G]lost, but [D]now am [G]found", "Was [Em7]blind but [Cadd9]now I [Dsus4]see",
      "{eoc}", "{c: Interlude}", "[Am7][D7][Gmaj7][Cmaj7]", "{sovt: 1.}", "[G]First [D]ending",
      "{eovt}", "{repeat: Chorus}", "Plain lyric line without chords", ""
    ]
    var out: [String] = []
    while out.count < lines { out.append(contentsOf: block) }
    return out.prefix(lines).joined(separator: "\n")
  }

  @Test func render300Lines() {
    let lyrics = PerfTests.song(lines: 300)
    let options = ChordProRenderOptions(
      transpose: 2, capo: 3, sectionLabels: ["chorus": "Chorus", "verse": "Verse"],
      commentLabel: "Note")
    let clock = ContinuousClock()
    _ = ChordProEngine.render(lyrics, options: options)  // warm up
    var samples: [Duration] = []
    for _ in 0..<15 {
      samples.append(clock.measure { _ = ChordProEngine.render(lyrics, options: options) })
    }
    let median = samples.sorted()[samples.count / 2]
    #if DEBUG
      let limit = Duration.milliseconds(100)
    #else
      let limit = Duration.milliseconds(5)
    #endif
    print("render 300 lines: median \(median)")
    #expect(median < limit, "median \(median) exceeds \(limit)")
  }
}
