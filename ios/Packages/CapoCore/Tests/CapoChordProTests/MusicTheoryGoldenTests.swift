import Foundation
import Testing

import CapoChordPro

/// ios/Fixtures/golden/music-theory.json (lib/__tests__/music-theory-golden.test.ts).
@Suite(.enabled(if: Fixtures.exists("music-theory.json"), "music-theory.json not generated yet"))
struct MusicTheoryGoldenTests {
  struct Golden: Decodable {
    let transposeKey: [String: [String: String]]
    let calculateCapoKey: [String: [String: String]]
    let calculateEffectiveKey: [String: [String: String]]
  }

  let golden: Golden

  init() throws {
    golden = try Fixtures.decode(Golden.self, "music-theory.json")
  }

  @Test func transposeKey() {
    var mismatches = Mismatches()
    for (key, table) in golden.transposeKey {
      for (n, expected) in table {
        mismatches.check(
          MusicTheory.transposeKey(key, semitones: Int(n)!), expected, "\(key) \(n)")
      }
    }
    #expect(mismatches.count == 0, "\(mismatches.summary)")
  }

  @Test func capoKey() {
    var mismatches = Mismatches()
    for (key, table) in golden.calculateCapoKey {
      for (capo, expected) in table {
        mismatches.check(MusicTheory.capoKey(key, capo: Int(capo)!), expected, "\(key) \(capo)")
      }
    }
    #expect(mismatches.count == 0, "\(mismatches.summary)")
  }

  @Test func effectiveKey() {
    var mismatches = Mismatches()
    for (key, table) in golden.calculateEffectiveKey {
      for (grid, expected) in table {
        let parts = grid.split(separator: "@").map { Int($0)! }
        mismatches.check(
          MusicTheory.effectiveKey(key, transpose: parts[0], capo: parts[1]), expected,
          "\(key) \(grid)")
      }
    }
    #expect(mismatches.count == 0, "\(mismatches.summary)")
  }
}
