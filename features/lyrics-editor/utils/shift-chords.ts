// Rewrites the chords stored in a ChordPro text by a number of semitones.
// Unlike the render-time `transpose`/`capo` settings, this changes the stored lyrics
// (used to fix imports whose chords were written in a different key than the song's).

const SHARP_NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const FLAT_NOTES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
const NOTE_INDEX: Record<string, number> = {
  C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11
}

const CHORD_RE = /^([A-G])([#b]?)([^/]*)(?:\/([A-G])([#b]?))?$/

function shiftNote(letter: string, accidental: string, semitones: number, flats: boolean): string {
  const base = NOTE_INDEX[letter] + (accidental === "#" ? 1 : accidental === "b" ? -1 : 0)
  const idx = (((base + semitones) % 12) + 12) % 12
  return (flats ? FLAT_NOTES : SHARP_NOTES)[idx]
}

/**
 * Shifts a single chord symbol. Returns the input unchanged when it is not a chord
 * (e.g. "N.C.", "x2"). Shifting down spells accidentals as flats, up as sharps.
 */
export function shiftChord(chord: string, semitones: number): string {
  const match = CHORD_RE.exec(chord.trim())
  if (!match) return chord
  const [, letter, accidental, suffix, bassLetter, bassAccidental] = match
  const flats = semitones < 0
  const root = shiftNote(letter, accidental, semitones, flats)
  const bass = bassLetter ? `/${shiftNote(bassLetter, bassAccidental, semitones, flats)}` : ""
  return `${root}${suffix}${bass}`
}

/**
 * Shifts every `[chord]` in the ChordPro text by `semitones`. Directives (`{...}`),
 * lyrics and non-chord brackets are left untouched.
 */
export function shiftLyricsChords(lyrics: string, semitones: number): string {
  if (!semitones) return lyrics
  return lyrics.replace(/\{[^}]*\}|\[([^\]\n]*)\]/g, (whole, chord?: string) =>
    chord === undefined ? whole : `[${shiftChord(chord, semitones)}]`
  )
}
