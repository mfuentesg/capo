const VOWEL = /[aeiouAEIOU]/

/**
 * Unicode clean-up for lyrics, mirroring ios CapoChordPro `LyricsText.normalized`.
 *
 * The pipeline counts UTF-16 units, so a decomposed accent ("a" + U+0301) can be split from its
 * letter by a chord, and a stray spacing acute ("a´", U+00B4) takes a whole monospace cell of its
 * own. Both render as a misplaced accent. Fold "<vowel>´" into a combining acute, then compose (NFC).
 */
export function normalizeLyricsText(text: string): string {
  if (/^[\x00-\x7F]*$/.test(text)) return text

  let folded = ""
  for (const ch of text) {
    const last = folded.slice(-1)
    folded += ch === "´" && VOWEL.test(last) ? "́" : ch
  }
  return folded.normalize("NFC")
}
