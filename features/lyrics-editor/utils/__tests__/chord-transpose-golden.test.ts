/**
 * Golden fixtures for chordsheetjs chord transposition, used by the native iPad app's Swift port.
 *
 * Writes ios/Fixtures/golden/chords.json under UPDATE_GOLDEN=1 and compares against it otherwise.
 * Regenerate: UPDATE_GOLDEN=1 pnpm test -- chord-transpose-golden
 */
import fs from "fs"
import path from "path"
import { Chord, ChordProParser } from "chordsheetjs"

const GOLDEN_PATH = path.resolve(__dirname, "../../../../ios/Fixtures/golden/chords.json")

const ROOTS = [
  "C",
  "C#",
  "Db",
  "D",
  "D#",
  "Eb",
  "E",
  "E#",
  "Fb",
  "F",
  "F#",
  "Gb",
  "G",
  "G#",
  "Ab",
  "A",
  "A#",
  "Bb",
  "B",
  "B#",
  "Cb"
]
const SUFFIXES = [
  "",
  "m",
  "7",
  "maj7",
  "m7",
  "m7b5",
  "sus2",
  "sus4",
  "add9",
  "dim",
  "aug",
  "6",
  "9",
  "11",
  "13"
]
const SLASH = ["C/E", "D/F#", "G/B", "Am/G", "Bb/D"]
const NON_CHORDS = ["N.C.", "x2", "H"]

// All roots with the plain and minor suffix, every other suffix on a handful of roots.
const SYMBOLS = [
  ...ROOTS.flatMap((r) => ["", "m"].map((s) => r + s)),
  ...["C", "F#", "Bb", "E"].flatMap((r) => SUFFIXES.slice(2).map((s) => r + s)),
  ...SLASH,
  ...NON_CHORDS
]

const DELTAS = Array.from({ length: 25 }, (_, i) => i - 12)
const TRANSPOSES = Array.from({ length: 13 }, (_, i) => i - 6)
const CAPOS = [0, 1, 2, 3, 5, 7]
const KEYS = ["G", "F", "D", "Bb", "Em"]

function transposeChord(symbol: string, delta: number): string {
  try {
    return Chord.parse(symbol)?.transpose(delta).toString() ?? symbol
  } catch {
    return symbol
  }
}

function normalizeChord(symbol: string, key: string, normalizeSuffix?: boolean): string {
  try {
    const chord = Chord.parse(symbol)
    if (!chord) return symbol
    return (
      normalizeSuffix === undefined
        ? chord.normalize(key)
        : chord.normalize(key, { normalizeSuffix })
    ).toString()
  } catch {
    return symbol
  }
}

/** Mirrors song-pipeline.ts: Song.transpose(t) then Song.transpose(-capo), both without suffix normalization. */
function pipeline(symbol: string, transpose: number, capo: number): string {
  try {
    let song = new ChordProParser().parse(`[${symbol}]x`)
    if (transpose !== 0) song = song.transpose(transpose, { normalizeChordSuffix: false })
    if (capo > 0) song = song.transpose(-capo, { normalizeChordSuffix: false })
    const item = song.lines.flatMap((l) => l.items).find((i) => "chords" in i) as
      | { chords?: string }
      | undefined
    return item?.chords ?? symbol
  } catch {
    return symbol
  }
}

function build() {
  const parses: Record<string, boolean> = {}
  const transpose: Record<string, Record<string, string>> = {}
  const normalize: Record<string, Record<string, string>> = {}
  const normalizeNoSuffix: Record<string, Record<string, string>> = {}
  const twoPass: Record<string, Record<string, string>> = {}

  for (const symbol of SYMBOLS) {
    parses[symbol] = (() => {
      try {
        return Chord.parse(symbol) !== null
      } catch {
        return false
      }
    })()
    transpose[symbol] = Object.fromEntries(
      DELTAS.map((d) => [String(d), transposeChord(symbol, d)])
    )
    normalize[symbol] = Object.fromEntries(KEYS.map((k) => [k, normalizeChord(symbol, k)]))
    normalizeNoSuffix[symbol] = Object.fromEntries(
      KEYS.map((k) => [k, normalizeChord(symbol, k, false)])
    )
    twoPass[symbol] = Object.fromEntries(
      TRANSPOSES.flatMap((t) => CAPOS.map((c) => [`${t}@${c}`, pipeline(symbol, t, c)]))
    )
  }

  return {
    symbols: SYMBOLS,
    deltas: DELTAS,
    transposes: TRANSPOSES,
    capos: CAPOS,
    keys: KEYS,
    parses,
    transpose,
    normalize,
    normalizeNoSuffix,
    twoPass
  }
}

describe("chord transposition golden fixtures", () => {
  it("covers about 70 symbols", () => {
    expect(SYMBOLS.length).toBeGreaterThanOrEqual(70)
  })

  it("matches chords.json", () => {
    const golden = build()
    if (process.env.UPDATE_GOLDEN) {
      fs.mkdirSync(path.dirname(GOLDEN_PATH), { recursive: true })
      fs.writeFileSync(GOLDEN_PATH, JSON.stringify(golden, null, 2) + "\n")
      return
    }
    expect(fs.existsSync(GOLDEN_PATH)).toBe(true)
    expect(golden).toEqual(JSON.parse(fs.readFileSync(GOLDEN_PATH, "utf8")))
  })

  it("leaves non-chords unchanged", () => {
    expect(transposeChord("N.C.", 3)).toBe("N.C.")
    expect(transposeChord("x2", -2)).toBe("x2")
  })
})
