import { ChordProFormatter, ChordsOverWordsParser } from "chordsheetjs"

export type DetectedFormat = "chord-above-lyrics" | "plain-text" | "chordpro"

export interface ConversionResult {
  format: DetectedFormat
  output: string
}

const CHORD_PATTERN = /^[A-G][b#]?(m|maj|min|aug|dim|sus|add|M)?[0-9]*(\/[A-G][b#]?)?$/

function isChordLine(line: string): boolean {
  const tokens = line.trim().split(/\s+/).filter(Boolean)
  if (tokens.length === 0) return false
  const chordCount = tokens.filter((t) => CHORD_PATTERN.test(t)).length
  return chordCount / tokens.length >= 0.7
}

// A line that has no ChordPro brackets or directives — could be part of chord-above-lyrics
function isPlainLine(line: string): boolean {
  const trimmed = line.trim()
  return !trimmed.includes("[") && !trimmed.startsWith("{") && !trimmed.startsWith("#")
}

export function detectFormat(text: string): DetectedFormat {
  if (/\[[A-G][^\]]*\]/.test(text)) return "chordpro"
  const lines = text.split("\n")
  const chordLineCount = lines.filter(isChordLine).length
  if (chordLineCount > 0 && chordLineCount >= lines.length * 0.3) return "chord-above-lyrics"
  return "plain-text"
}

function convertChordAboveLyrics(text: string): string {
  const parser = new ChordsOverWordsParser()
  const song = parser.parse(text)
  return new ChordProFormatter().format(song)
}

export function convertToChordPro(text: string): ConversionResult {
  const format = detectFormat(text)
  if (format === "chordpro") return { format, output: text }
  if (format === "chord-above-lyrics") return { format, output: convertChordAboveLyrics(text) }
  return { format: "plain-text", output: text }
}

// Converts chord-above-lyrics blocks within a document that may already contain
// ChordPro-formatted sections. Only unbracketed blocks with chord+lyric pairs are
// touched; everything else is left unchanged.
export function convertChordAboveLyricsBlocks(text: string): {
  converted: boolean
  output: string
} {
  const lines = text.split("\n")

  type Segment = { lines: string[]; isPlain: boolean }
  const segments: Segment[] = []

  for (const line of lines) {
    const plain = isPlainLine(line)
    const last = segments[segments.length - 1]
    if (last && last.isPlain === plain) {
      last.lines.push(line)
    } else {
      segments.push({ lines: [line], isPlain: plain })
    }
  }

  let anyConverted = false
  const resultParts: string[] = []

  for (const seg of segments) {
    if (!seg.isPlain) {
      resultParts.push(seg.lines.join("\n"))
      continue
    }

    const hasChordLine = seg.lines.some(isChordLine)
    const hasLyricLine = seg.lines.some((l) => !isChordLine(l) && l.trim().length > 0)

    if (hasChordLine && hasLyricLine) {
      try {
        const converted = convertChordAboveLyrics(seg.lines.join("\n"))
        resultParts.push(converted.trim())
        anyConverted = true
      } catch {
        resultParts.push(seg.lines.join("\n"))
      }
    } else {
      resultParts.push(seg.lines.join("\n"))
    }
  }

  return { converted: anyConverted, output: resultParts.join("\n") }
}
