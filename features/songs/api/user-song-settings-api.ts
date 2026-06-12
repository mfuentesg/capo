import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database, Tables, TablesInsert } from "@/lib/supabase/database.types"
import type { UserSongSettings } from "@/features/songs/types"

// Only the columns the frontend type consumes
const SETTINGS_COLUMNS = "song_id, capo, transpose, font_size"

type UserSongSettingsRow = Pick<
  Tables<"user_song_settings">,
  "song_id" | "capo" | "transpose" | "font_size"
>

function mapRowToSettings(row: UserSongSettingsRow): UserSongSettings {
  return {
    songId: row.song_id,
    capo: row.capo,
    transpose: row.transpose,
    fontSize: row.font_size ?? undefined
  }
}

export async function getUserSongSettings(
  supabase: SupabaseClient<Database>,
  userId: string,
  songId: string
): Promise<UserSongSettings | null> {
  const { data, error } = await supabase
    .from("user_song_settings")
    .select(SETTINGS_COLUMNS)
    .eq("user_id", userId)
    .eq("song_id", songId)
    .maybeSingle()

  if (error) throw error
  return data ? mapRowToSettings(data) : null
}

export async function getAllUserSongSettings(
  supabase: SupabaseClient<Database>,
  userId: string
): Promise<UserSongSettings[]> {
  const { data, error } = await supabase
    .from("user_song_settings")
    .select(SETTINGS_COLUMNS)
    .eq("user_id", userId)

  if (error) throw error
  return (data ?? []).map(mapRowToSettings)
}

export async function upsertUserSongSettings(
  supabase: SupabaseClient<Database>,
  userId: string,
  songId: string,
  settings: Omit<UserSongSettings, "songId">
): Promise<UserSongSettings> {
  const row: TablesInsert<"user_song_settings"> = {
    user_id: userId,
    song_id: songId,
    capo: settings.capo,
    transpose: settings.transpose,
    font_size: settings.fontSize ?? null,
    updated_at: new Date().toISOString()
  }

  const { data, error } = await supabase
    .from("user_song_settings")
    .upsert(row, { onConflict: "user_id,song_id" })
    .select(SETTINGS_COLUMNS)
    .single()

  if (error) throw error
  return mapRowToSettings(data)
}
