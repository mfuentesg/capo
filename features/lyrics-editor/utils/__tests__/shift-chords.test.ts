import { shiftChord, shiftLyricsChords } from "../shift-chords"

describe("shiftChord", () => {
  it("shifts down using flats", () => {
    expect(shiftChord("B", -1)).toBe("Bb")
    expect(shiftChord("F#m7", -1)).toBe("Fm7")
    expect(shiftChord("E/G#", -2)).toBe("D/Gb")
    expect(shiftChord("Bsus4", -2)).toBe("Asus4")
  })

  it("shifts up using sharps", () => {
    expect(shiftChord("A", 1)).toBe("A#")
    expect(shiftChord("Bb", 2)).toBe("C")
  })

  it("wraps around the octave", () => {
    expect(shiftChord("C", -1)).toBe("B")
    expect(shiftChord("B", 1)).toBe("C")
  })

  it("leaves non-chords untouched", () => {
    expect(shiftChord("N.C.", -1)).toBe("N.C.")
    expect(shiftChord("x2", -1)).toBe("x2")
  })
})

describe("shiftLyricsChords", () => {
  it("only rewrites bracketed chords, not lyrics or directives", () => {
    const input = "{title: Bb song}\n{c: Verse}\n[B]Be a [F#m]light [N.C.]now"
    expect(shiftLyricsChords(input, -1)).toBe(
      "{title: Bb song}\n{c: Verse}\n[Bb]Be a [Fm]light [N.C.]now"
    )
  })

  it("is a no-op for 0 and reversible for a round trip without accidentals", () => {
    const input = "[C]a [G]b [Am]c"
    expect(shiftLyricsChords(input, 0)).toBe(input)
    expect(shiftLyricsChords(shiftLyricsChords(input, -2), 2)).toBe(input)
  })
})
