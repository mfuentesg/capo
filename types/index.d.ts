export interface SongTag {
  id: string
  name: string
  color?: string | null
}

export interface Song {
  id: string
  title: string
  artist: string
  key: string
  bpm: number
  lyrics?: string
  notes?: string
  tags?: SongTag[]
  fontSize?: number
  transpose?: number
  capo?: number
  isDraft?: boolean
}

export interface Playlist {
  id: string
  name: string
  description?: string
  date?: string
  songs: string[] // Array of song IDs
  createdAt: string
  updatedAt: string
  isDraft?: boolean
  visibility?: "private" | "public"
  allowGuestEditing?: boolean
  shareCode?: string
}

export type GroupBy = "none" | "key" | "artist"

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
