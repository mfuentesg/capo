import { midiToNote } from "../utils/midi-to-note"

describe("midiToNote", () => {
  it("converts middle C (60) to C4", () => {
    expect(midiToNote(60)).toBe("C4")
  })

  it("converts E2 (40) to E2", () => {
    expect(midiToNote(40)).toBe("E2")
  })

  it("converts A4 (69) to A4", () => {
    expect(midiToNote(69)).toBe("A4")
  })

  it("maps an Am chord midi array to correct note names", () => {
    // Am position 0 from @tombatossals/chords-db: [45, 52, 57, 60, 64]
    expect([45, 52, 57, 60, 64].map(midiToNote)).toEqual(["A2", "E3", "A3", "C4", "E4"])
  })

  it("handles sharps correctly", () => {
    expect(midiToNote(61)).toBe("C#4")
    expect(midiToNote(63)).toBe("D#4")
    expect(midiToNote(66)).toBe("F#4")
  })
})
