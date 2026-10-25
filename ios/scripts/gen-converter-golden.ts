// Generates ios/Fixtures/converter/converter.json from the web implementation:
//   npx tsx ios/scripts/gen-converter-golden.ts
import { writeFileSync } from "node:fs"
import path from "node:path"
import {
  convertToChordPro,
  convertChordAboveLyricsBlocks,
  detectFormat
} from "../../features/lyrics-editor/utils/chordpro-converter"

let seed = 20240521
const rnd = () => ((seed = (seed * 1664525 + 1013904223) % 4294967296) / 4294967296)
const pick = <T,>(a: T[]): T => a[Math.floor(rnd() * a.length)]

const chords = ["C", "Am", "F", "G7", "Em", "D/F#", "Bb", "F#m7", "Cmaj7", "Gadd9", "Dsus4", "A2", "Bm7b5", "E", "Ab", "C#dim", "Gm", "Dm7", "Fmaj9", "B7", "Asus2", "G/B", "Cm", "D"]
const symbols = ["|", "/", "x", "-", "x2", "N.C.", "(C)", "Em."]
const words = ["hello", "world", "amazing", "grace", "how", "sweet", "the", "sound", "that", "saved", "a", "wretch", "like", "me", "ñandú", "señor", "I", "Do", "love", "you", "yeah", "A", "Eres", "fiel", "Dios"]
const labels = ["Intro", "Verse 1", "Chorus:", "Bridge", "Capo: 2", "Tom: Em", "Refrão", "Parte 1", "Intro: Em C", "Note: a } b", "Pre-Chorus:", "Instrumental", "Tag along"]

function chordLine(): string {
  let line = ""
  const n = 1 + Math.floor(rnd() * 4)
  for (let i = 0; i < n; i++) {
    const pad = " ".repeat(i === 0 ? Math.floor(rnd() * 5) : 1 + Math.floor(rnd() * 9))
    line += pad + (rnd() < 0.06 ? pick(symbols) : pick(chords))
  }
  return rnd() < 0.1 ? line + "  " : line
}
function lyricLine(): string {
  const n = 1 + Math.floor(rnd() * 6)
  let s = Array.from({ length: n }, () => pick(words)).join(rnd() < 0.1 ? "  " : " ")
  if (rnd() < 0.05) s += " \\ " + pick(words)
  if (rnd() < 0.05) s = "  " + s
  if (rnd() < 0.05) s += "   "
  return s
}
function doc(): string {
  const out: string[] = []
  const n = 2 + Math.floor(rnd() * 10)
  for (let i = 0; i < n; i++) {
    const r = rnd()
    if (r < 0.12) out.push(pick(labels))
    else if (r < 0.17) out.push("")
    else if (r < 0.2) out.push("[Em]already chordpro")
    else if (r < 0.25) out.push("{c: note}")
    else {
      out.push(chordLine())
      if (rnd() < 0.85) out.push(lyricLine())
    }
  }
  let t = out.join(rnd() < 0.1 ? "\r\n" : "\n")
  if (rnd() < 0.2) t += "\n"
  if (rnd() < 0.1) t = "\n" + t
  return t
}

const handwritten = [
  "Em            C\nTest lyric line one\nG             D\nTest lyric line two",
  "Intro: Em C\nEm  C\nhello there",
  "title: Foo\nkey: C\n---\nEm\nhello",
  "{title: Foo}\nEm\nhello",
  "Em\n   \nhello",
  "Em C.\nhello",
  "Note: with } brace",
  "Em C\nNote: with } brace\nAm\nfoo",
  "Em x2\nhello",
  "         Em\nhi",
  "Am  F\n\nOnly chords here",
  "[Em]already [C]chordpro"
]

const cases: { input: string; format: string; convert: string | null; blocks: { converted: boolean; output: string } }[] = []
for (const input of [...handwritten, ...Array.from({ length: 700 }, doc)]) {
  let convert: string | null = null
  try {
    convert = convertToChordPro(input).output
  } catch {
    convert = null
  }
  cases.push({ input, format: detectFormat(input), convert, blocks: convertChordAboveLyricsBlocks(input) })
}
const out = path.resolve(__dirname, "../Fixtures/converter/converter.json")
writeFileSync(out, JSON.stringify(cases))
console.log(`wrote ${cases.length} cases, ${cases.filter((c) => c.convert === null).length} throw`)
