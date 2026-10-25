/**
 * Golden fixtures for lib/music-theory.ts, used by the native iPad app's Swift port.
 *
 * Writes ios/Fixtures/golden/music-theory.json under UPDATE_GOLDEN=1 and compares otherwise.
 * Regenerate: UPDATE_GOLDEN=1 pnpm test -- music-theory-golden
 */
import fs from "fs"
import path from "path"
import { calculateCapoKey, calculateEffectiveKey, transposeKey } from "../music-theory"

const GOLDEN_PATH = path.resolve(__dirname, "../../ios/Fixtures/golden/music-theory.json")

const ROOTS = [
  "C",
  "C#",
  "Db",
  "D",
  "D#",
  "Eb",
  "E",
  "F",
  "F#",
  "Gb",
  "G",
  "G#",
  "Ab",
  "A",
  "A#",
  "Bb",
  "B"
]
const MODIFIERS = ["", "m", "7"]
const RANGE_11 = Array.from({ length: 23 }, (_, i) => i - 11)
const CAPO_RANGE = Array.from({ length: 13 }, (_, i) => i)
const CAPO_KEYS = ["G", "Em", "C#", "Bb", "F#m", "A7", "", "H", "Cb"]
const EFFECTIVE_KEYS = ["C", "G", "Em", "Bb", "F#", "Dm", "Ab7"]
const EFFECTIVE_TRANSPOSES = [-6, -3, -1, 0, 1, 2, 5, 6]
const EFFECTIVE_CAPOS = [0, 1, 2, 3, 5, 7, 12]

function build() {
  const transposeKeyTable: Record<string, Record<string, string>> = {}
  for (const root of ROOTS) {
    for (const mod of MODIFIERS) {
      const key = root + mod
      transposeKeyTable[key] = Object.fromEntries(
        RANGE_11.map((n) => [String(n), transposeKey(key, n)])
      )
    }
  }
  // Edge inputs: empty, unparseable, unknown modifiers
  for (const key of ["", "H", "Cb", "Fb", "E#", "Cmaj7", "Bbm7", "X"]) {
    transposeKeyTable[key] = Object.fromEntries(
      [-7, -1, 0, 1, 7].map((n) => [String(n), transposeKey(key, n)])
    )
  }

  const capoKey: Record<string, Record<string, string>> = {}
  for (const key of CAPO_KEYS) {
    capoKey[key] = Object.fromEntries(CAPO_RANGE.map((c) => [String(c), calculateCapoKey(key, c)]))
  }

  const effectiveKey: Record<string, Record<string, string>> = {}
  for (const key of EFFECTIVE_KEYS) {
    effectiveKey[key] = Object.fromEntries(
      EFFECTIVE_TRANSPOSES.flatMap((t) =>
        EFFECTIVE_CAPOS.map((c) => [`${t}@${c}`, calculateEffectiveKey(key, t, c)])
      )
    )
  }

  return {
    transposeKey: transposeKeyTable,
    calculateCapoKey: capoKey,
    calculateEffectiveKey: effectiveKey
  }
}

describe("music-theory golden fixtures", () => {
  it("matches music-theory.json", () => {
    const golden = build()
    if (process.env.UPDATE_GOLDEN) {
      fs.mkdirSync(path.dirname(GOLDEN_PATH), { recursive: true })
      fs.writeFileSync(GOLDEN_PATH, JSON.stringify(golden, null, 2) + "\n")
      return
    }
    expect(fs.existsSync(GOLDEN_PATH)).toBe(true)
    expect(golden).toEqual(JSON.parse(fs.readFileSync(GOLDEN_PATH, "utf8")))
  })
})
