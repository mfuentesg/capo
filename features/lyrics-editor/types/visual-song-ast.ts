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
  lines: LyricLine[]
}

export interface VisualSongAST {
  blocks: SongBlock[]
}
