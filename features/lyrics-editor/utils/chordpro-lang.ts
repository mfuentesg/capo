import { HighlightStyle, StreamLanguage, syntaxHighlighting } from "@codemirror/language"
import { autocompletion, type CompletionContext } from "@codemirror/autocomplete"
import { tags } from "@lezer/highlight"
import type { Extension } from "@codemirror/state"

interface ChordProState {
  inDirective: boolean
  afterColon: boolean
}

// Directives fully supported by chordsheetjs v12.3.1.
// Add entries here as the library gains support for new ChordPro spec directives.
const SUPPORTED_DIRECTIVES = [
  // Meta
  { label: "title", detail: "Song title", apply: "title: " },
  { label: "t", detail: "Song title (short)", apply: "t: " },
  { label: "subtitle", detail: "Subtitle", apply: "subtitle: " },
  { label: "artist", detail: "Artist name", apply: "artist: " },
  { label: "composer", detail: "Composer", apply: "composer: " },
  { label: "lyricist", detail: "Lyricist", apply: "lyricist: " },
  { label: "copyright", detail: "Copyright info", apply: "copyright: " },
  { label: "album", detail: "Album name", apply: "album: " },
  { label: "year", detail: "Release year", apply: "year: " },
  { label: "key", detail: "Song key", apply: "key: " },
  { label: "k", detail: "Song key (short)", apply: "k: " },
  { label: "time", detail: "Time signature", apply: "time: " },
  { label: "tempo", detail: "Tempo in BPM", apply: "tempo: " },
  { label: "duration", detail: "Song duration", apply: "duration: " },
  { label: "capo", detail: "Capo fret position", apply: "capo: " },
  { label: "ca", detail: "Capo (short)", apply: "ca: " },
  { label: "meta", detail: "Custom metadata", apply: "meta: " },
  // Sections — optional name, count, and performance flags (attention, skip, forte, piano, vamp, tag, break, inline)
  { label: "start_of_chorus", detail: "Begin chorus — e.g. {soc: Chorus, 3, forte}", apply: "start_of_chorus: " },
  { label: "soc", detail: "Begin chorus (short) — e.g. {soc: Chorus, 3, forte}", apply: "soc: " },
  { label: "end_of_chorus", detail: "End chorus section", apply: "end_of_chorus}" },
  { label: "eoc", detail: "End chorus (short)", apply: "eoc}" },
  { label: "start_of_verse", detail: "Begin verse — e.g. {sov: Verse 1, 2, attention}", apply: "start_of_verse: " },
  { label: "sov", detail: "Begin verse (short) — e.g. {sov: Verse 1, 2, attention}", apply: "sov: " },
  { label: "end_of_verse", detail: "End verse section", apply: "end_of_verse}" },
  { label: "eov", detail: "End verse (short)", apply: "eov}" },
  { label: "start_of_bridge", detail: "Begin bridge — e.g. {sob: Bridge, vamp}", apply: "start_of_bridge: " },
  { label: "sob", detail: "Begin bridge (short) — e.g. {sob: Bridge, vamp}", apply: "sob: " },
  { label: "end_of_bridge", detail: "End bridge section", apply: "end_of_bridge}" },
  { label: "eob", detail: "End bridge (short)", apply: "eob}" },
  { label: "start_of_tab", detail: "Begin tablature section", apply: "start_of_tab}" },
  { label: "sot", detail: "Begin tab (short)", apply: "sot}" },
  { label: "end_of_tab", detail: "End tablature section", apply: "end_of_tab}" },
  { label: "eot", detail: "End tab (short)", apply: "eot}" },
  { label: "start_of_grid", detail: "Begin chord grid section", apply: "start_of_grid}" },
  { label: "sog", detail: "Begin grid (short)", apply: "sog}" },
  { label: "end_of_grid", detail: "End chord grid section", apply: "end_of_grid}" },
  { label: "eog", detail: "End grid (short)", apply: "eog}" },
  // Custom extensions — not part of the official ChordPro specification
  { label: "start_of_intro", detail: "Begin intro section — e.g. {soi: Intro, inline}", apply: "start_of_intro: " },
  { label: "soi", detail: "Begin intro (short)", apply: "soi: " },
  { label: "end_of_intro", detail: "End intro section", apply: "end_of_intro}" },
  { label: "eoi", detail: "End intro (short)", apply: "eoi}" },
  { label: "start_of_outro", detail: "Begin outro section", apply: "start_of_outro: " },
  { label: "soo", detail: "Begin outro (short)", apply: "soo: " },
  { label: "end_of_outro", detail: "End outro section", apply: "end_of_outro}" },
  { label: "eoo", detail: "End outro (short)", apply: "eoo}" },
  { label: "start_of_pre_chorus", detail: "Begin pre-chorus section", apply: "start_of_pre_chorus: " },
  { label: "sopc", detail: "Begin pre-chorus (short)", apply: "sopc: " },
  { label: "end_of_pre_chorus", detail: "End pre-chorus section", apply: "end_of_pre_chorus}" },
  { label: "eopc", detail: "End pre-chorus (short)", apply: "eopc}" },
  // Box sections — custom extension
  { label: "start_of_box", detail: "Begin labeled box — closing tag optional", apply: "start_of_box: " },
  { label: "sbox", detail: "Begin box (short) — closing tag optional", apply: "sbox: " },
  { label: "end_of_box", detail: "End box section", apply: "end_of_box}" },
  { label: "ebox", detail: "End box (short)", apply: "ebox}" },
  // Volta (iteration) sections — custom extension
  { label: "start_of_volta", detail: "Begin volta/iteration — e.g. {sovt: 1st time}", apply: "start_of_volta: " },
  { label: "sovt", detail: "Begin volta (short) — e.g. {sovt: 1st time}", apply: "sovt: " },
  { label: "end_of_volta", detail: "End volta section", apply: "end_of_volta}" },
  { label: "eovt", detail: "End volta (short)", apply: "eovt}" },
  // Section references and extensions
  { label: "repeat", detail: "Reference a named section with optional count — e.g. {repeat: Chorus, 2}", apply: "repeat: " },
  { label: "start_of_extend", detail: "Prepend a named section then append own content — e.g. {soex: Intro, label: Extended Intro, inline}", apply: "start_of_extend: " },
  { label: "soex", detail: "Begin extend block (short) — e.g. {soex: Intro, inline}", apply: "soex: " },
  { label: "end_of_extend", detail: "End extend block", apply: "end_of_extend}" },
  { label: "eoex", detail: "End extend (short)", apply: "eoex}" },
  // Comments
  { label: "comment", detail: "Inline annotation", apply: "comment: " },
  { label: "c", detail: "Comment (short)", apply: "c: " },
  { label: "comment_italic", detail: "Italic comment", apply: "comment_italic: " },
  { label: "comment_box", detail: "Boxed comment", apply: "comment_box: " },
  // Performance notes — custom extension
  { label: "note", detail: "Performance note — e.g. {note: stronger}", apply: "note: " },
  // Chord definitions
  { label: "define", detail: "Define a chord shape", apply: "define: " },
  { label: "chord", detail: "Chord definition", apply: "chord: " },
  // Formatting
  { label: "textfont", detail: "Lyrics text font", apply: "textfont: " },
  { label: "textsize", detail: "Lyrics text size", apply: "textsize: " },
  { label: "textcolour", detail: "Lyrics text colour", apply: "textcolour: " },
  { label: "textcolor", detail: "Lyrics text color (US)", apply: "textcolor: " },
  { label: "chordfont", detail: "Chord text font", apply: "chordfont: " },
  { label: "chordsize", detail: "Chord text size", apply: "chordsize: " },
  { label: "chordcolour", detail: "Chord text colour", apply: "chordcolour: " },
  { label: "chordcolor", detail: "Chord text color (US)", apply: "chordcolor: " },
] as const

// Directives that accept comma-separated flags and/or a repeat count after the name
const FLAG_DIRECTIVES = new Set([
  "start_of_chorus", "soc",
  "start_of_verse", "sov",
  "start_of_bridge", "sob",
  "start_of_intro", "soi",
  "start_of_outro", "soo",
  "start_of_pre_chorus", "sopc",
  "start_of_box", "sbox",
  "comment", "c", "comment_italic", "comment_box",
  "repeat",
  "start_of_extend", "soex",
])

const FLAG_COMPLETIONS = [
  { label: "label", detail: "compact title chip — no body content" },
  { label: "inline", detail: "render chords inline with text" },
  { label: "attention", detail: "! — mark for special attention" },
  { label: "forte", detail: "f — forte (loud)" },
  { label: "piano", detail: "p — piano (soft)" },
  { label: "vamp", detail: "vamp — repeat until cue" },
  { label: "tag", detail: "tag — ending tag" },
  { label: "skip", detail: "skip — mark to skip" },
  { label: "break", detail: "break — rest/break" },
]

const COUNT_COMPLETIONS = ["2", "3", "4", "5", "6", "7", "8"].map((n) => ({
  label: n,
  detail: `repeat ${n} times`,
}))

const chordProLang = StreamLanguage.define<ChordProState>({
  name: "chordpro",

  startState: () => ({ inDirective: false, afterColon: false }),

  token(stream, state) {
    // Line comment: # at start of line
    if (stream.sol() && stream.peek() === "#") {
      stream.skipToEnd()
      return "comment"
    }

    // Inline chord: [ChordName] — match whole bracket or just [ on malformed input
    if (stream.peek() === "[") {
      if (!stream.match(/^\[[^\]\n]*\]/)) stream.next()
      return "atom"
    }

    // Directive open: {
    if (!state.inDirective && stream.peek() === "{") {
      stream.next()
      state.inDirective = true
      state.afterColon = false
      return "punctuation"
    }

    if (state.inDirective) {
      // Directive close: }
      if (stream.peek() === "}") {
        stream.next()
        state.inDirective = false
        state.afterColon = false
        return "punctuation"
      }

      // Colon separator
      if (!state.afterColon && stream.peek() === ":") {
        stream.next()
        stream.eatSpace()
        state.afterColon = true
        return "punctuation"
      }

      // Directive value (after colon)
      if (state.afterColon) {
        stream.eatWhile((ch: string) => ch !== "}" && ch !== "\n")
        return "string"
      }

      // Directive keyword (before colon or })
      stream.eatWhile((ch: string) => ch !== ":" && ch !== "}" && ch !== "\n")
      return "keyword"
    }

    stream.next()
    return null
  },

  // Reset directive state on blank lines — directives are always single-line
  blankLine(state) {
    state.inDirective = false
    state.afterColon = false
  },
})

// Match the rendered view's chord colour so editor and preview stay in sync.
// Other token colors (keyword, string, comment) come from the base editor theme.
const chordHighlight = HighlightStyle.define([
  { tag: tags.atom, color: "var(--chord)" },
])

function chordProCompletions(context: CompletionContext) {
  // Flag/count completion: inside a section directive value, after a comma.
  // Matches e.g. "{soc: Chorus, " or "{soi: Intro, 2, fo" up to the cursor.
  const flagMatch = context.matchBefore(/\{([\w_]+):[^,}]+(?:,[^,}]*)*,\s*\w*/)
  if (flagMatch) {
    const directiveMatch = flagMatch.text.match(/^\{([\w_]+):/)
    if (directiveMatch && FLAG_DIRECTIVES.has(directiveMatch[1].toLowerCase())) {
      // Extract the partial token being typed after the last comma
      const afterLastComma = flagMatch.text.match(/,\s*(\w*)$/)
      const typed = afterLastComma?.[1] ?? ""
      const from = flagMatch.to - typed.length

      // Collect tokens already present so we don't re-suggest them
      const alreadyUsed = new Set(
        Array.from(flagMatch.text.matchAll(/,\s*(\w+)/g))
          .map((m) => m[1])
          .filter((t) => t !== typed)
      )

      const hasCount = Array.from(alreadyUsed).some((t) => /^\d+$/.test(t))

      const options = [
        ...(!hasCount ? COUNT_COMPLETIONS : []),
        ...FLAG_COMPLETIONS.filter((f) => !alreadyUsed.has(f.label)),
      ].map((o) => ({ ...o, type: "keyword" as const }))

      return { from, options, filter: true }
    }
  }

  // Directive name completion: after opening {
  const before = context.matchBefore(/\{\w*/)
  if (!before) return null
  return {
    from: before.from + 1, // position right after {
    options: SUPPORTED_DIRECTIVES.map((d) => ({
      label: d.label,
      detail: d.detail,
      apply: d.apply,
      type: "keyword" as const,
    })),
    filter: true,
  }
}

export function chordProExtensions(): Extension[] {
  return [
    chordProLang.extension,
    syntaxHighlighting(chordHighlight),
    autocompletion({ override: [chordProCompletions] }),
  ]
}

/** Syntax highlighting only — no autocomplete. Used by the reference panel code blocks. */
export function chordProDisplayExtensions(): Extension[] {
  return [chordProLang.extension, syntaxHighlighting(chordHighlight)]
}
