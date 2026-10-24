import Testing

@testable import CapoRendering

@MainActor
struct ChordDiagramTests {
  @Test func parsesRootsAndSuffixes() {
    #expect(ChordNameParser.parse("C") == .init(key: "C", suffix: "major", slashSuffix: nil))
    #expect(ChordNameParser.parse("Am")?.suffix == "minor")
    #expect(ChordNameParser.parse("A#m7")?.key == "Bb")
    #expect(ChordNameParser.parse("Dbmaj7")?.key == "Csharp")
    #expect(ChordNameParser.parse("F#m")?.key == "Fsharp")
    #expect(ChordNameParser.parse("Dbmaj7")?.suffix == "maj7")
    #expect(ChordNameParser.parse("G6/9")?.suffix == "69")
    #expect(ChordNameParser.parse("CΔ")?.suffix == "maj7")
    #expect(ChordNameParser.parse("Bø")?.suffix == "m7b5")
    #expect(ChordNameParser.parse("Am/G")?.slashSuffix == "m/G")
    #expect(ChordNameParser.parse("C/Eb")?.slashSuffix == "/D#")
    #expect(ChordNameParser.parse("xyz") == nil)
  }

  @Test func databaseLoadsFromBundle() {
    let db = ChordDatabase.shared
    #expect(db.positions(for: "C").first?.frets == [-1, 3, 2, 0, 1, 0])
    #expect(db.positions(for: "C").first?.fingers == [0, 3, 2, 0, 1, 0])
    #expect(db.table.values.contains { $0.values.contains { $0.count > 4 } })  // every web position kept
    #expect(!db.positions(for: "Am/G").isEmpty)
    #expect(!db.positions(for: "C#m").isEmpty)
    #expect(db.positions(for: "Hm").isEmpty)
  }

  @Test func resolveFallsBackLikeTheWeb() {
    let db = ChordDatabase.shared
    // In the database: verified shape.
    let c = db.resolve("C")
    #expect(!c.isGenerated && !c.positions.isEmpty)
    // Slash chord missing from the database: generated fingerings, never "not found".
    let slash = db.resolve("C/Bb")
    #expect(slash.isGenerated && !slash.positions.isEmpty)
    // Neither source knows it.
    #expect(db.resolve("Hm").positions.isEmpty)
    #expect(db.resolve("").positions.isEmpty)
  }

  @Test func generatedFingeringsMatchTheWebPackage() {
    for golden in goldenFingerings {
      let generated = ChordFingering.positions(for: golden.chord)
      #expect(generated.count == golden.count, "\(golden.chord) count")
      for (index, expected) in golden.first.enumerated() where index < generated.count {
        let actual = generated[index]
        #expect(
          actual.baseFret == expected.0 && actual.frets == expected.1 && actual.barres == expected.2,
          "\(golden.chord) #\(index): \(actual.baseFret) \(actual.frets) \(actual.barres)")
      }
    }
  }

  @Test func unknownSymbolsGenerateNothing() {
    #expect(ChordFingering.positions(for: "Hm").isEmpty)
    #expect(ChordFingering.positions(for: "Cfoo").isEmpty)
  }

  @Test func playabilityFilterRejectsBlockedBarres() {
    #expect(!ChordPosition(baseFret: 1, frets: [2, 2, 1, 2, 2, 2], barres: [2]).isPlayable)
    #expect(ChordPosition(baseFret: 1, frets: [1, 3, 3, 2, 1, 1], barres: [1]).isPlayable)
  }

  @Test func geometryHasTheWebBox() {
    #expect(ChordDiagramGeometry.width == 252)  // PL + 5 * S + PR, as in the web source
    #expect(ChordDiagramGeometry.height == 186)
  }

  @Test func openChordShowsNutMarkersAndFingers() {
    let position = ChordPosition(baseFret: 1, frets: [-1, 3, 2, 0, 1, 0], barres: [])
    let g = ChordDiagramGeometry(position: position, mirror: true)
    #expect(g.isNut && g.nutRect.height == 5)
    #expect(g.baseFretLabel == nil)
    #expect(g.markers.filter(\.isMuted).map(\.string) == [0])
    #expect(g.markers.filter { !$0.isMuted }.map(\.string) == [3, 5])
    #expect(g.dots.map(\.finger) == [3, 2, 1])  // auto-assigned by fret order
    #expect(g.fretLineYs.count == 4 && g.stringXs.count == 6)
  }

  @Test func handMirrorsStringOrder() {
    let position = ChordPosition(baseFret: 1, frets: [-1, 3, 2, 0, 1, 0], barres: [])
    let left = ChordDiagramGeometry(position: position, mirror: true)
    let right = ChordDiagramGeometry(position: position, mirror: false)
    #expect(left.stringXs == [36, 76, 116, 156, 196, 236])  // low E on the left
    #expect(right.stringXs == Array(left.stringXs.reversed()))
    #expect(left.dots.map(\.center.y) == right.dots.map(\.center.y))
    #expect(left.dots.map(\.center.x) != right.dots.map(\.center.x))
  }

  @Test func barreBecomesABarAndHidesCoveredDots() {
    let position = ChordPosition(baseFret: 1, frets: [-1, -1, 0, 2, 1, 1], barres: [1])
    let g = ChordDiagramGeometry(position: position, mirror: true)
    #expect(g.barres.count == 1)
    #expect(g.barres.first?.minString == 4 && g.barres.first?.maxString == 5)
    #expect(g.barres.first?.rect.height == 20)
    #expect(g.dots.map(\.string) == [3])
  }

  @Test func upperPositionsShowTheBaseFret() {
    let position = ChordPosition(baseFret: 5, frets: [-1, 1, 3, 3, 3, 1], barres: [1])
    let g = ChordDiagramGeometry(position: position, mirror: true)
    #expect(!g.isNut && g.nutRect.height == 2)
    #expect(g.baseFretLabel?.value == 5)
  }

  @Test func autoFingersFollowFretOrder() {
    #expect(
      ChordDiagramGeometry.autoAssignFingers(frets: [-1, 0, 2, 2, 1, 0], baseFret: 1)
        == [0, 0, 2, 2, 1, 0])
  }

  @Test func spokenFretsUseAbsoluteFrets() {
    let position = ChordPosition(baseFret: 3, frets: [-1, 0, 1, 2, 2, 1], barres: [])
    #expect(
      ChordDiagramGeometry.spokenFrets(of: position, muted: "m", open: "o") == "m, o, 3, 4, 4, 3")
  }
}
