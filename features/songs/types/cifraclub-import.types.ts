export type CifraClubParseError =
  | "invalid_url"
  | "wrong_host"
  | "network"
  | "http_status"
  | "no_chord_block"
  | "rate_limited"
  | "unexpected"

export interface CifraClubParsedSong {
  title: string
  artist: string
  key: string
  lyrics: string
  keyFound: boolean
}

export type CifraClubImportResult =
  | { success: true; data: CifraClubParsedSong }
  | { success: false; error: CifraClubParseError }
