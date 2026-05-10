import type {
  ChordToken,
  LyricLine,
  SongBlock,
  SongBlockType,
  SongLine,
  VoltaGroup,
  VisualSongAST
} from "../types/visual-song-ast"

const SECTION_START_RE =
  /^\{(start_of_chorus|soc|start_of_verse|sov|start_of_bridge|sob|start_of_tab|sot|start_of_intro|soi|start_of_outro|soo|start_of_pre_chorus|sopc|start_of_grid|sog)(?::\s*([^}]*))?\}/i

const SECTION_END_RE =
  /^\{(?:end_of_chorus|eoc|end_of_verse|eov|end_of_bridge|eob|end_of_tab|eot|end_of_intro|eoi|end_of_outro|eoo|end_of_pre_chorus|eopc|end_of_grid|eog)\}/i

const VOLTA_START_RE = /^\{(?:start_of_volta|sovt)(?::\s*([^}]*))?\}/i
const VOLTA_END_RE = /^\{(?:end_of_volta|eovt)\}/i

const DIRECTIVE_RE = /^\{[^}]*\}/

const DIRECTIVE_TO_TYPE: Record<string, SongBlockType> = {
  start_of_chorus: "chorus",
  soc: "chorus",
  start_of_verse: "verse",
  sov: "verse",
  start_of_bridge: "bridge",
  sob: "bridge",
  start_of_tab: "tab",
  sot: "tab",
  start_of_intro: "intro",
  soi: "intro",
  start_of_outro: "outro",
  soo: "outro",
  start_of_pre_chorus: "pre-chorus",
  sopc: "pre-chorus",
  start_of_grid: "custom",
  sog: "custom"
}

/** Extract [Chord] tokens from a lyric line, returning the clean text and chord list. */
function parseLyricLine(raw: string): { text: string; chords: ChordToken[] } {
  const chords: ChordToken[] = []
  let text = ""
  let i = 0
  let charOffset = 0

  while (i < raw.length) {
    if (raw[i] === "[") {
      const close = raw.indexOf("]", i + 1)
      if (close !== -1) {
        const chord = raw.slice(i + 1, close)
        if (chord.length > 0) {
          chords.push({ id: crypto.randomUUID(), chord, offset: charOffset })
        }
        i = close + 1
        continue
      }
    }
    text += raw[i]
    charOffset++
    i++
  }

  return { text, chords }
}

function makeLine(raw: string): LyricLine {
  const { text, chords } = parseLyricLine(raw)
  return { id: crypto.randomUUID(), text, chords }
}

function isNonEmpty(line: LyricLine): boolean {
  return line.text.trim().length > 0 || line.chords.length > 0
}

/**
 * Parse ChordPro text into a VisualSongAST.
 *
 * Section blocks can contain lyric lines and/or volta groups.
 * Lines outside named sections are grouped into an implicit verse block.
 * Directives other than section/volta markers are silently dropped.
 */
export function chordProToVisualAST(chordpro: string): VisualSongAST {
  const rawLines = chordpro.split("\n")
  const blocks: SongBlock[] = []

  let currentBlock: SongBlock | null = null
  let currentVolta: VoltaGroup | null = null
  let pendingLines: string[] = []

  function flushCurrentVolta() {
    if (!currentVolta || !currentBlock) return
    const nonEmpty = currentVolta.lines.filter(isNonEmpty)
    if (nonEmpty.length > 0 || currentVolta.label) {
      currentBlock.lines.push({ ...currentVolta, lines: nonEmpty })
    }
    currentVolta = null
  }

  function flushPending() {
    if (pendingLines.length === 0) return
    const nonEmpty = pendingLines.filter((l) => l.trim().length > 0)
    if (nonEmpty.length === 0) {
      pendingLines = []
      return
    }
    blocks.push({
      id: crypto.randomUUID(),
      type: "verse",
      lines: nonEmpty.map(makeLine) as SongLine[]
    })
    pendingLines = []
  }

  for (const rawLine of rawLines) {
    const line = rawLine.trimEnd()

    // Section end
    if (SECTION_END_RE.test(line)) {
      flushCurrentVolta()
      if (currentBlock) {
        const nonEmpty = currentBlock.lines.filter((sl) => {
          if (Array.isArray((sl as VoltaGroup).lines)) return true
          return isNonEmpty(sl as LyricLine)
        })
        if (nonEmpty.length > 0) {
          blocks.push({ ...currentBlock, lines: nonEmpty })
        }
        currentBlock = null
      }
      continue
    }

    // Volta end
    if (VOLTA_END_RE.test(line)) {
      flushCurrentVolta()
      continue
    }

    // Volta start (must be inside a section)
    const voltaMatch = line.match(VOLTA_START_RE)
    if (voltaMatch) {
      flushCurrentVolta()
      currentVolta = {
        id: crypto.randomUUID(),
        label: voltaMatch[1]?.trim() || undefined,
        lines: []
      }
      continue
    }

    // Section start
    const startMatch = line.match(SECTION_START_RE)
    if (startMatch) {
      flushCurrentVolta()
      flushPending()
      const directive = startMatch[1].toLowerCase()
      const label = startMatch[2]?.trim()
      const type = DIRECTIVE_TO_TYPE[directive] ?? "custom"
      currentBlock = {
        id: crypto.randomUUID(),
        type,
        label: label || undefined,
        lines: []
      }
      continue
    }

    // Skip other directives
    if (DIRECTIVE_RE.test(line)) continue

    // Append lyric line
    const lyricLine = makeLine(line)
    if (currentVolta) {
      currentVolta.lines.push(lyricLine)
    } else if (currentBlock) {
      currentBlock.lines.push(lyricLine)
    } else {
      pendingLines.push(line)
    }
  }

  flushCurrentVolta()
  flushPending()

  return { blocks }
}
