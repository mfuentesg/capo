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
