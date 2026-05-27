export type SongOwnership =
  | { type: "personal" }
  | { type: "team"; teamId: string; teamName: string; teamIcon?: string | null }

export interface Song {
  id: string
  title: string
  artist: string
  key: string
  bpm: number
  lyrics?: string
  notes?: string
  tags?: string[]
  fontSize?: number
  transpose?: number
  capo?: number
  ownership?: SongOwnership
  userSettings?: UserSongSettings | null
}

export interface UserSongSettings {
  songId: string
  capo: number
  transpose: number
  fontSize?: number
}

export interface UserPreferences {
  lyricsColumns: 1 | 2
  locale?: string
  theme?: "light" | "dark" | "system"
  chordHand?: "right" | "left"
  palette?: string
  uiFont?: string
}

export type GroupBy = "none" | "key" | "artist" | "bucket"

export interface SongDetailProps {
  song: Song
  onClose: () => void
  onUpdate: (songId: string, updates: Partial<Song>) => void
  onDelete: (songId: string) => void
}

export type BPMRange = "all" | "slow" | "medium" | "fast"

export interface SongListProps {
  songs: Song[]
  previewSong?: Song | null
  selectedSong?: Song | null
  groupBy: GroupBy
  bpmRange: BPMRange
  isCreatingNewSong?: boolean
  onSelectSong: (song: Song) => void
}

export type MusicalKey =
  | "A"
  | "Am"
  | "A#"
  | "A#m"
  | "Bb"
  | "Bbm"
  | "B"
  | "Bm"
  | "C"
  | "Cbm"
  | "Cb"
  | "Cm"
  | "C#"
  | "C#m"
  | "Db"
  | "Dbm"
  | "D"
  | "Dm"
  | "D#"
  | "D#m"
  | "E"
  | "Em"
  | "Eb"
  | "Ebm"
  | "F"
  | "Fb"
  | "Fbm"
  | "Fm"
  | "F#"
  | "F#m"
  | "G"
  | "Gm"
  | "G#"
  | "G#m"
  | "Gb"
  | "Gbm"
  | "Ab"
  | "Abm"
