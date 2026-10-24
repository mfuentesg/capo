import Foundation
import Testing

@testable import CapoChordPro

/// `ios/Fixtures/converter/converter.json`, generated from the web converter by
/// `npx tsx ios/scripts/gen-converter-golden.ts`.
struct ConverterGoldenTests {
  struct Case: Decodable {
    struct Blocks: Decodable {
      let converted: Bool
      let output: String
    }
    let input: String
    let format: String
    let convert: String?
    let blocks: Blocks
  }

  static let cases: [Case] = {
    let url = Fixtures.root.appendingPathComponent("converter/converter.json")
    return (try? JSONDecoder().decode([Case].self, from: Data(contentsOf: url))) ?? []
  }()

  @Test func fixtureLoaded() { #expect(Self.cases.count > 500) }

  @Test func detectFormatMatchesWeb() {
    var bad = Mismatches()
    for c in Self.cases { bad.check(ChordProConverter.detectFormat(c.input).rawValue, c.format, c.input) }
    #expect(bad.count == 0, "\(bad.summary)")
  }

  @Test func convertToChordProMatchesWeb() {
    var bad = Mismatches()
    for c in Self.cases {
      let actual = try? ChordProConverter.convertToChordPro(c.input).output
      bad.check(actual ?? "<throws>", c.convert ?? "<throws>", c.input)
    }
    #expect(bad.count == 0, "\(bad.summary)")
  }

  @Test func convertBlocksMatchesWeb() {
    var bad = Mismatches()
    for c in Self.cases {
      let r = ChordProConverter.convertChordAboveLyricsBlocks(c.input)
      bad.check("\(r.converted)|\(r.output)", "\(c.blocks.converted)|\(c.blocks.output)", c.input)
    }
    #expect(bad.count == 0, "\(bad.summary)")
  }
}
