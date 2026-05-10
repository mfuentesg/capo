import type {
  LyricLine,
  SongBlock,
  SongBlockType,
  SongLine,
  VoltaGroup,
  VisualSongAST
} from "../types/visual-song-ast"
import { isVoltaGroup } from "../types/visual-song-ast"

const TYPE_TO_DIRECTIVES: Record<SongBlockType, { start: string; end: string }> = {
  verse: { start: "sov", end: "eov" },
  chorus: { start: "soc", end: "eoc" },
  bridge: { start: "sob", end: "eob" },
  intro: { start: "soi", end: "eoi" },
  outro: { start: "soo", end: "eoo" },
  "pre-chorus": { start: "sopc", end: "eopc" },
  tab: { start: "sot", end: "eot" },
  custom: { start: "sov", end: "eov" }
}

/** Insert [Chord] tokens into a lyric text string at their character offsets. */
function buildChordProLine(line: LyricLine): string {
  if (line.chords.length === 0) return line.text

  const sorted = [...line.chords].sort((a, b) => a.offset - b.offset)
  let result = ""
  let textPos = 0

  for (const token of sorted) {
    const clampedOffset = Math.max(textPos, Math.min(token.offset, line.text.length))
    result += line.text.slice(textPos, clampedOffset)
    result += `[${token.chord}]`
    textPos = clampedOffset
  }
  result += line.text.slice(textPos)
  return result
}

function voltaGroupToChordPro(group: VoltaGroup): string {
  const labelParam = group.label ? `: ${group.label}` : ""
  const start = `{sovt${labelParam}}`
  const end = `{eovt}`
  const linesText = group.lines.map(buildChordProLine).join("\n")
  return [start, linesText, end].join("\n")
}

function songLineToChordPro(line: SongLine): string {
  if (isVoltaGroup(line)) return voltaGroupToChordPro(line)
  return buildChordProLine(line)
}

function blockToChordPro(block: SongBlock): string {
  const directives = TYPE_TO_DIRECTIVES[block.type]
  const nameParam = block.label ? `: ${block.label}` : ""
  const startDirective = `{${directives.start}${nameParam}}`
  const endDirective = `{${directives.end}}`

  const linesText = block.lines.map(songLineToChordPro).join("\n")

  return [startDirective, linesText, endDirective].join("\n")
}

/**
 * Compile a VisualSongAST back to ChordPro text.
 * Each block is wrapped in its section directives.
 * Volta groups within blocks are wrapped in {sovt}…{eovt}.
 * Blocks are separated by a blank line.
 */
export function visualASTToChordPro(ast: VisualSongAST): string {
  return ast.blocks.map(blockToChordPro).join("\n\n")
}
