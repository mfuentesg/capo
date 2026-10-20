import Foundation
import Testing

@testable import CapoChordPro

/// ios/Fixtures/golden/chords.json (features/lyrics-editor/utils/__tests__/chord-transpose-golden.test.ts).
@Suite(.enabled(if: Fixtures.exists("chords.json"), "chords.json not generated yet"))
struct ChordGoldenTests {
  struct Golden: Decodable {
    let symbols: [String]
    let keys: [String]
    let parses: [String: Bool]
    let transpose: [String: [String: String]]
    let normalize: [String: [String: String]]
    let normalizeNoSuffix: [String: [String: String]]
    let twoPass: [String: [String: String]]
  }

  let golden: Golden

  init() throws {
    golden = try Fixtures.decode(Golden.self, "chords.json")
  }

  @Test func parses() {
    var mismatches = Mismatches()
    for symbol in golden.symbols {
      mismatches.check(
        String(ChordTransposer.parses(symbol)), String(golden.parses[symbol]!), symbol)
    }
    #expect(mismatches.count == 0, "\(mismatches.summary)")
  }

  @Test func transpose() {
    var mismatches = Mismatches()
    for (symbol, table) in golden.transpose {
      for (delta, expected) in table {
        mismatches.check(
          ChordTransposer.transpose(symbol, by: Int(delta)!), expected, "\(symbol) \(delta)")
      }
    }
    #expect(mismatches.count == 0, "\(mismatches.summary)")
  }

  @Test func normalize() {
    var mismatches = Mismatches()
    for (symbol, table) in golden.normalize {
      for (key, expected) in table {
        mismatches.check(ChordTransposer.normalize(symbol, toKey: key), expected, "\(symbol) \(key)")
      }
    }
    for (symbol, table) in golden.normalizeNoSuffix {
      for (key, expected) in table {
        mismatches.check(
          ChordTransposer.normalize(symbol, toKey: key, normalizeSuffix: false), expected,
          "\(symbol) \(key) (no suffix)")
      }
    }
    #expect(mismatches.count == 0, "\(mismatches.summary)")
  }

  /// `[symbol]x` through the full engine: Song.transpose(t) then Song.transpose(-capo).
  @Test func twoPassPipeline() {
    var mismatches = Mismatches()
    for (symbol, table) in golden.twoPass {
      for (grid, expected) in table {
        let parts = grid.split(separator: "@").map { Int($0)! }
        let options = ChordProRenderOptions(
          transpose: parts[0], capo: parts[1], sectionLabels: [:], commentLabel: "")
        let rendered = ChordProEngine.render("[\(symbol)]x", options: options)
        var chord = "<none>"
        if case .normal(let body)? = rendered.segments.first,
          case .chordLyrics(let pairs)? = body.lines.first
        {
          chord = pairs.first?.chord ?? "<none>"
        }
        mismatches.check(chord, expected, "\(symbol) \(grid)")
      }
    }
    #expect(mismatches.count == 0, "\(mismatches.summary)")
  }
}
