import Testing

@testable import CapoRendering

@Suite struct ChordAudioTests {
  /// Same cases as `features/chord-audio/__tests__/midi-to-note.test.ts`.
  @Test func midiToNoteMatchesTheWeb() {
    #expect(ChordAudioMath.midiToNote(60) == "C4")
    #expect(ChordAudioMath.midiToNote(40) == "E2")
    #expect(ChordAudioMath.midiToNote(69) == "A4")
    #expect([45, 52, 57, 60, 64].map(ChordAudioMath.midiToNote) == ["A2", "E3", "A3", "C4", "E4"])
    #expect([61, 63, 66].map(ChordAudioMath.midiToNote) == ["C#4", "D#4", "F#4"])
  }

  @Test func voicingFollowsTheDiagramLikeTheWeb() {
    // Am open: x 0 2 2 1 0 -> A2 E3 A3 C4 E4
    let am = ChordPosition(baseFret: 1, frets: [-1, 0, 2, 2, 1, 0], barres: [])
    #expect(ChordAudioMath.midiNotes(for: am) == [45, 52, 57, 60, 64])
    // F barre, base fret 3: actual fret = relative + base - 1
    let f = ChordPosition(baseFret: 3, frets: [1, 3, 3, 2, 1, 1], barres: [1])
    #expect(ChordAudioMath.midiNotes(for: f) == [43, 50, 55, 59, 62, 67])
  }

  @Test func timingConstantsMatchTheWeb() {
    #expect(ChordAudioMath.noteDuration == 1.5 && ChordAudioMath.stagger == 0.025)
    #expect(ChordAudioMath.playingIndicator == 1.5)
  }

  @Test func synthesisIsBoundedAndPitched() {
    let a4 = ChordAudioMath.pluck(frequency: ChordAudioMath.frequency(midi: 69), duration: 0.5, sampleRate: 44_100)
    #expect(a4.count == 22_050 && a4.allSatisfy { abs($0) <= 1 } && a4.contains { abs($0) > 0.1 })
    #expect(abs(ChordAudioMath.frequency(midi: 69) - 440) < 1e-9)
    let mixed = ChordAudioMath.mix(midi: [45, 52, 57], sampleRate: 44_100)
    #expect(mixed.count == Int((1.5 + 0.05) * 44_100) && mixed.allSatisfy { abs($0) <= 1 })
  }
}
