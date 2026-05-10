export interface ChordToken {
  id: string
  chord: string
  /** Character offset within the lyric text where this chord appears */
  offset: number
}

export interface LyricLine {
  id: string
  text: string
  chords: ChordToken[]
}

export interface VoltaGroup {
  id: string
  /** Free text label, e.g. "1st time", "2nd time", "D.C." */
  label?: string
  lines: LyricLine[]
}

/** A line item inside a section block — either a lyric line or a volta group. */
export type SongLine = LyricLine | VoltaGroup

export function isVoltaGroup(line: SongLine): line is VoltaGroup {
  return Array.isArray((line as VoltaGroup).lines)
}

export type SongBlockType =
  | "verse"
  | "chorus"
  | "bridge"
  | "intro"
  | "outro"
  | "pre-chorus"
  | "tab"
  | "custom"

export interface SongBlock {
  id: string
  type: SongBlockType
  /** Optional display label, e.g. "Verse 1". Falls back to derived label if absent. */
  label?: string
  lines: SongLine[]
}

export interface VisualSongAST {
  blocks: SongBlock[]
}
