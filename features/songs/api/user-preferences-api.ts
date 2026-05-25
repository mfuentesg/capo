import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database } from "@/lib/supabase/database.types"
import type { UserPreferences, UserSongSettings } from "../types"
import { isValidPalette } from "@/lib/palette"
import { isValidUIFont } from "@/lib/font"

type PreferencesJson = Database["public"]["Tables"]["profiles"]["Row"]["preferences"]

const VALID_THEMES = ["light", "dark", "system"] as const
type Theme = (typeof VALID_THEMES)[number]

function isValidTheme(v: unknown): v is Theme {
  return VALID_THEMES.includes(v as Theme)
}

function mapJsonToPreferences(json: PreferencesJson): UserPreferences {
  if (typeof json !== "object" || json === null || Array.isArray(json)) {
    return { lyricsColumns: 2 }
  }
  return {
    lyricsColumns: json["lyricsColumns"] === 1 ? 1 : 2,
    locale: typeof json["locale"] === "string" ? json["locale"] : undefined,
    theme: isValidTheme(json["theme"]) ? json["theme"] : undefined,
    chordHand: json["chordHand"] === "right" ? "right" : json["chordHand"] === "left" ? "left" : undefined,
    palette: isValidPalette(json["palette"]) ? json["palette"] : undefined,
    uiFont: isValidUIFont(json["uiFont"]) ? json["uiFont"] : undefined
  }
}

function mapRowToSongSettings(row: {
  song_id: string
  capo: number
  transpose: number
  font_size: number | null
}): UserSongSettings {
  return {
    songId: row.song_id,
    capo: row.capo,
    transpose: row.transpose,
    fontSize: row.font_size ?? undefined
  }
}

export interface UserProfileData {
  preferences: UserPreferences
  songSettings: UserSongSettings[]
}

/**
 * Fetches only the user preferences column from profiles.
 * Use this when song settings are not needed (e.g. AppContext init).
 */
export async function getUserPreferences(
  supabase: SupabaseClient<Database>,
  userId: string
): Promise<UserPreferences> {
  const { data, error } = await supabase
    .from("profiles")
    .select("preferences")
    .eq("id", userId)
    .single()

  if (error) throw error
  return mapJsonToPreferences(data.preferences)
}

/**
 * Fetches user preferences and all song settings in a single query
 * using PostgREST nested selects (profiles → user_song_settings via FK).
 */
export async function getUserProfileData(
  supabase: SupabaseClient<Database>,
  userId: string
): Promise<UserProfileData> {
  const { data, error } = await supabase
    .from("profiles")
    .select("preferences, user_song_settings(song_id, capo, transpose, font_size)")
    .eq("id", userId)
    .single()

  if (error) throw error

  const songSettings = Array.isArray(data.user_song_settings)
    ? data.user_song_settings.map(mapRowToSongSettings)
    : []

  return {
    preferences: mapJsonToPreferences(data.preferences),
    songSettings
  }
}

export async function upsertUserPreferences(
  supabase: SupabaseClient<Database>,
  userId: string,
  preferences: UserPreferences
): Promise<UserPreferences> {
  const { data, error } = await supabase
    .from("profiles")
    .update({
      preferences: {
        lyricsColumns: preferences.lyricsColumns,
        ...(preferences.locale !== undefined && { locale: preferences.locale }),
        ...(preferences.theme !== undefined && { theme: preferences.theme })
      },
      updated_at: new Date().toISOString()
    })
    .eq("id", userId)
    .select("preferences")
    .single()

  if (error) throw error
  return mapJsonToPreferences(data.preferences)
}
