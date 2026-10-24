import CapoRendering
import Foundation
import Testing

@testable import CapoChordsUI

@MainActor @Suite struct ChordsLogicTests {
  struct Case: Decodable {
    struct Result: Decodable {
      let root: String
      let suffix: String
      let name: String
      let confidence: String
      let missingNotes: Int
    }
    let frets: [Int]
    let baseFret: Int
    let results: [Result]
    let notes: [String]
  }

  static let cases: [Case] = {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Fixtures/converter/chords.json")
    return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Case].self, from: $0) } ?? []
  }()

  @Test func identifierMatchesWeb() {
    #expect(Self.cases.count == 400)
    for c in Self.cases {
      let actual = ChordIdentifier.identify(c.frets, baseFret: c.baseFret)
      #expect(actual.map(\.name) == c.results.map(\.name), "\(c.frets) @\(c.baseFret)")
      #expect(actual.map(\.isExact) == c.results.map { $0.confidence == "exact" })
      #expect(actual.map(\.missingNotes) == c.results.map(\.missingNotes))
      #expect(ChordIdentifier.notes(c.frets, baseFret: c.baseFret) == c.notes)
    }
  }

  @Test func glossaryCoversTheWholeDatabase() {
    #expect(ChordGlossary.all.count == 529)
    #expect(ChordGlossary.entries(forKey: "A").count == 52)
    for entry in ChordGlossary.all {
      #expect(ChordGlossary.firstPosition(entry) != nil, "\(entry.id)")
    }
  }

  @Test func namesAndSearch() {
    let a = ChordGlossary.entries(forKey: "A")
    #expect(a.prefix(4).map(\.displayName) == ["A", "Am", "Adim", "Adim7"])
    #expect(ChordEntry(key: "Csharp", suffix: "minor").displayName == "C#m")
    #expect(ChordEntry(key: "Csharp", suffix: "minor").webName == "C#minor")
    #expect(ChordGlossary.filter(query: "c#", key: nil).contains { $0.key == "Csharp" })
    #expect(ChordGlossary.filter(query: "", key: "G").count == ChordGlossary.entries(forKey: "G").count)
    #expect(ChordGlossary.filter(query: "zzz", key: nil).isEmpty)
  }

  @Test func analyzerState() {
    let model = ChordAnalyzerModel()
    #expect(!model.hasInput)
    model.tapMarker(string: 1)
    model.tapCell(string: 2, fret: 2)
    #expect(model.frets[1] == 0 && model.frets[2] == 2)
    model.tapCell(string: 2, fret: 2)
    #expect(model.frets[2] == 0)
    model.step(-1)
    #expect(model.baseFret == 1)
    model.reset()
    #expect(!model.hasInput)
  }
}
