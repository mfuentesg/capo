import Testing

@testable import CapoRendering

@MainActor
struct ChordDiagramTests {
  @Test func parsesRootsAndSuffixes() {
    #expect(ChordNameParser.parse("C") == .init(key: "C", suffix: "major", slashSuffix: nil))
    #expect(ChordNameParser.parse("Am")?.suffix == "minor")
    #expect(ChordNameParser.parse("A#m7")?.key == "Bb")
    #expect(ChordNameParser.parse("Dbmaj7")?.key == "C#")
    #expect(ChordNameParser.parse("Dbmaj7")?.suffix == "maj7")
    #expect(ChordNameParser.parse("G6/9")?.suffix == "69")
    #expect(ChordNameParser.parse("Am/G")?.slashSuffix == "m/G")
    #expect(ChordNameParser.parse("C/Eb")?.slashSuffix == "/D#")
    #expect(ChordNameParser.parse("xyz") == nil)
  }

  @Test func databaseLoadsFromBundle() {
    let c = ChordDatabase.shared.positions(for: "C", instrument: .guitar)
    #expect(c.first?.frets == [-1, 3, 2, 0, 1, 0])
    let uke = ChordDatabase.shared.positions(for: "C", instrument: .ukulele)
    #expect(uke.first?.frets == [0, 0, 0, 3])
    #expect(!ChordDatabase.shared.positions(for: "Am/G", instrument: .guitar).isEmpty)
    #expect(ChordDatabase.shared.positions(for: "Hm", instrument: .guitar).isEmpty)
  }

  @Test func layoutSeparatesOpenMutedAndDots() {
    let layout = FretboardLayout(position: .init(baseFret: 1, frets: [-1, 3, 2, 0, 1, 0], barres: []))
    #expect(layout.mutedStrings == [0])
    #expect(layout.openStrings == [3, 5])
    #expect(layout.dots.count == 3)
    #expect(layout.fretLabel == nil)
  }

  @Test func barreAbsorbsItsDots() {
    let layout = FretboardLayout(
      position: .init(baseFret: 3, frets: [1, 1, 3, 3, 3, 1], barres: [1]))
    #expect(layout.barres == [.init(row: 0, fromString: 0, toString: 5)])
    #expect(layout.dots.map(\.row) == [2, 2, 2])
    #expect(layout.fretLabel == 3)
  }

  @Test func geometryIsEvenlySpaced() {
    let layout = FretboardLayout(position: .init(baseFret: 1, frets: [0, 0, 0, 0, 0, 0], barres: []))
    #expect(layout.stringX(0, width: 100) == 0)
    #expect(layout.stringX(5, width: 100) == 100)
    #expect(layout.rowY(0, height: 80) == 10)
  }
}
