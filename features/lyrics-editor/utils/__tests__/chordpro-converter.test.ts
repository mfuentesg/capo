import { convertToChordPro, detectFormat } from "../chordpro-converter"

const CHORDS_OVER_WORDS = `       Am         C/G        F          C
Let it be, let it be, let it be, let it be
C                G              F  C/E Dm C
Whisper words of wisdom, let it be`

const ALREADY_CHORDPRO = `Let it [Am]be, let it [C/G]be`

const PLAIN_TEXT = `This is just regular prose without any chords or musical notation here.`

describe("detectFormat", () => {
  it("detects chordpro when input has bracket chords", () => {
    expect(detectFormat(ALREADY_CHORDPRO)).toBe("chordpro")
  })

  it("detects chord-above-lyrics for chords-over-words input", () => {
    expect(detectFormat(CHORDS_OVER_WORDS)).toBe("chord-above-lyrics")
  })

  it("falls back to plain-text for prose without chords", () => {
    expect(detectFormat(PLAIN_TEXT)).toBe("plain-text")
  })

  it("detects chord-above-lyrics when only chord lines present", () => {
    expect(detectFormat("Am G F C")).toBe("chord-above-lyrics")
  })
})

describe("convertToChordPro", () => {
  it("passes chordpro input through unchanged", () => {
    const result = convertToChordPro(ALREADY_CHORDPRO)
    expect(result.format).toBe("chordpro")
    expect(result.output).toBe(ALREADY_CHORDPRO)
  })

  it("passes plain-text through unchanged", () => {
    const result = convertToChordPro(PLAIN_TEXT)
    expect(result.format).toBe("plain-text")
    expect(result.output).toBe(PLAIN_TEXT)
  })

  it("converts chords-over-words to inline bracket notation", () => {
    const result = convertToChordPro(CHORDS_OVER_WORDS)
    expect(result.format).toBe("chord-above-lyrics")
    expect(result.output).toContain("[Am]")
    expect(result.output).toContain("[C/G]")
    expect(result.output).toContain("Let it")
    expect(result.output).toContain("Whisper words of")
  })

  it("converted output contains no standalone chord lines", () => {
    const result = convertToChordPro(CHORDS_OVER_WORDS)
    const lines = result.output.split("\n")
    // No line should consist exclusively of chord tokens (they've been merged inline)
    const bareChordLine = /^\s*([A-G][b#]?(m|maj|min|aug|dim|sus|add|M)?[0-9]*(\/[A-G][b#]?)?\s+)+$/
    expect(lines.some((l) => bareChordLine.test(l))).toBe(false)
  })

  it("multi-verse song preserves both verse lines", () => {
    const result = convertToChordPro(CHORDS_OVER_WORDS)
    expect(result.output).toContain("Let it")
    expect(result.output).toContain("Whisper words of")
  })
})
