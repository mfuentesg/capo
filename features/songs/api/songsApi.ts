/**
 * Songs API - Supabase REST API functions
 *
 * Pure functions for data fetching and mutations.
 * No React hooks, no side effects beyond Supabase calls.
 */

import type { SupabaseClient } from "@supabase/supabase-js"
import type { Tables, TablesInsert, TablesUpdate } from "@/lib/supabase/database.types"
import type { AppContext } from "@/features/app-context"
import type { Song as FrontendSong, SongOwnership } from "@/features/songs/types"
import { applyContextFilter } from "@/lib/supabase/apply-context-filter"

// Only the columns fetched by SONG_COLUMNS — a subset of the full row type
type SongRow = Pick<
  Tables<"songs">,
  "id" | "title" | "artist" | "key" | "bpm" | "lyrics" | "notes" | "transpose" | "capo" | "status"
>

// Extended row type including ownership columns
type SongRowWithOwnership = SongRow &
  Pick<Tables<"songs">, "user_id" | "team_id">

function mapDBSongToFrontend(dbSong: SongRow): FrontendSong {
  return {
    id: dbSong.id,
    title: dbSong.title,
    artist: dbSong.artist || "",
    key: dbSong.key || "",
    bpm: dbSong.bpm || 0,
    lyrics: dbSong.lyrics || undefined,
    notes: dbSong.notes || undefined,
    transpose: dbSong.transpose ?? 0,
    capo: dbSong.capo ?? 0
  }
}

function mapFrontendSongToDB(
  song: Partial<FrontendSong>,
  userId: string,
  context?: AppContext
): TablesInsert<"songs"> {
  const isTeam = context?.type === "team"
  return {
    title: song.title || "",
    artist: song.artist || null,
    key: song.key || null,
    bpm: song.bpm || null,
    lyrics: song.lyrics || null,
    notes: song.notes || null,
    transpose: song.transpose ?? 0,
    capo: song.capo ?? 0,
    status: "published",
    user_id: isTeam ? null : userId,
    team_id: isTeam ? context.teamId : null,
    created_by: userId
  }
}

function mapFrontendUpdatesToDB(updates: Partial<FrontendSong>): TablesUpdate<"songs"> {
  const dbUpdate: TablesUpdate<"songs"> = {}

  if (updates.title !== undefined) dbUpdate.title = updates.title
  if (updates.artist !== undefined) dbUpdate.artist = updates.artist || null
  if (updates.key !== undefined) dbUpdate.key = updates.key || null
  if (updates.bpm !== undefined) dbUpdate.bpm = updates.bpm || null
  if (updates.lyrics !== undefined) dbUpdate.lyrics = updates.lyrics || null
  if (updates.notes !== undefined) dbUpdate.notes = updates.notes || null

  return dbUpdate
}

/**
 * Maps a song row with ownership columns to a frontend song with ownership info resolved
 */
function mapDBSongWithOwnershipToFrontend(
  dbSong: SongRowWithOwnership,
  teams: Pick<Tables<"teams">, "id" | "name" | "icon">[]
): FrontendSong {
  let ownership: SongOwnership
  if (dbSong.team_id) {
    const team = teams.find((t) => t.id === dbSong.team_id)
    ownership = {
      type: "team",
      teamId: dbSong.team_id,
      teamName: team?.name ?? dbSong.team_id,
      teamIcon: team?.icon ?? null
    }
  } else {
    ownership = { type: "personal" }
  }
  return {
    ...mapDBSongToFrontend(dbSong),
    ownership
  }
}

/**
 * Fetch songs based on context (personal or team)
 *
 * @param context - App context (personal or team)
 * @returns Promise<FrontendSong[]> - Array of songs
 */
const SONG_COLUMNS = "id, title, artist, key, bpm, lyrics, notes, transpose, capo, status"
const SONG_COLUMNS_WITH_OWNERSHIP =
  "id, title, artist, key, bpm, lyrics, notes, transpose, capo, status, user_id, team_id"

/**
 * Builds a prefix-matching tsquery string for use with to_tsquery().
 * Each word gets a :* suffix so partial inputs match (e.g. "lib" matches "Libertad").
 * Special tsquery characters are stripped to prevent syntax errors.
 */
function buildPrefixTsQuery(searchQuery: string): string {
  return searchQuery
    .trim()
    .split(/\s+/)
    .map((w) => w.replace(/[&|!():*\\]/g, ""))
    .filter((w) => w.length > 0)
    .map((w) => `${w}:*`)
    .join(" & ")
}

export async function getSongs(
  supabase: SupabaseClient,
  context: AppContext,
  searchQuery?: string
): Promise<FrontendSong[]> {
  let query = supabase.from("songs").select(SONG_COLUMNS)
  query = applyContextFilter(query, context)

  if (searchQuery && searchQuery.trim().length > 0) {
    query = query.textSearch("search_vector", buildPrefixTsQuery(searchQuery))
  }

  const { data, error } = await query.order("created_at", { ascending: false })

  if (error) throw error
  return (data || []).map(mapDBSongToFrontend)
}

/**
 * Fetch songs from all accessible buckets (personal + all teams) in a single query.
 * Falls back to a simple personal query when the user has no teams.
 *
 * @param userId - Current user ID
 * @param teamIds - Array of team IDs the user belongs to
 * @param teams - Team metadata used to resolve ownership display info
 * @returns Promise<FrontendSong[]> - Array of songs with ownership info
 */
export async function getSongsAllBuckets(
  supabase: SupabaseClient,
  userId: string,
  teamIds: string[],
  teams: Pick<Tables<"teams">, "id" | "name" | "icon">[],
  searchQuery?: string
): Promise<FrontendSong[]> {
  if (teamIds.length === 0) {
    // No teams — fall back to personal-only query
    const context: AppContext = { type: "personal", userId }
    return getSongs(supabase, context, searchQuery)
  }

  const orFilter = [
    `user_id.eq.${userId}`,
    ...teamIds.map((id) => `team_id.eq.${id}`)
  ].join(",")

  let query = supabase
    .from("songs")
    .select(SONG_COLUMNS_WITH_OWNERSHIP)
    .or(orFilter)

  if (searchQuery && searchQuery.trim().length > 0) {
    query = query.textSearch("search_vector", buildPrefixTsQuery(searchQuery))
  }

  const { data, error } = await query.order("created_at", { ascending: false })

  if (error) throw error
  return (data || []).map((row) =>
    mapDBSongWithOwnershipToFrontend(row as SongRowWithOwnership, teams)
  )
}

/**
 * Get a single song by ID
 *
 * @param songId - Song UUID
 * @returns Promise<FrontendSong | null> - Song or null if not found
 */
export async function getSong(
  supabase: SupabaseClient,
  songId: string
): Promise<FrontendSong | null> {
  const response = await supabase.from("songs").select("*").eq("id", songId).single()

  if (response.error) {
    if (response.error.code === "PGRST116") return null
    throw response.error
  }

  return response.data ? mapDBSongToFrontend(response.data) : null
}

/**
 * Get multiple songs by their IDs
 *
 * @param songIds - Array of song UUIDs
 * @returns Promise<FrontendSong[]> - Array of songs
 */
export async function getSongsByIds(
  supabase: SupabaseClient,
  songIds: string[]
): Promise<FrontendSong[]> {
  if (songIds.length === 0) return []

  const { data, error } = await supabase.from("songs").select(SONG_COLUMNS).in("id", songIds)

  if (error) throw error
  return (data || []).map(mapDBSongToFrontend)
}

/**
 * Create a new song
 *
 * @param song - Song data to insert (frontend type)
 * @param userId - User ID creating the song
 * @returns Promise<FrontendSong> - Created song
 */
export async function createSong(
  supabase: SupabaseClient,
  song: Partial<FrontendSong>,
  userId: string,
  context?: AppContext
): Promise<FrontendSong> {
  const dbSong = mapFrontendSongToDB(song, userId, context)

  const response = await supabase.from("songs").insert(dbSong).select().single()

  if (response.error) throw response.error
  return mapDBSongToFrontend(response.data)
}

/**
 * Update a song
 *
 * @param songId - Song UUID
 * @param updates - Partial song data to update (frontend type)
 * @returns Promise<FrontendSong> - Updated song
 */
export async function updateSong(
  supabase: SupabaseClient,
  songId: string,
  updates: Partial<FrontendSong>
): Promise<FrontendSong> {
  const dbUpdates = mapFrontendUpdatesToDB(updates)

  const response = await supabase.from("songs").update(dbUpdates).eq("id", songId).select().single()

  if (response.error) throw response.error
  return mapDBSongToFrontend(response.data)
}

/**
 * Delete a song
 *
 * @param songId - Song UUID
 * @returns Promise<void>
 */
export async function deleteSong(supabase: SupabaseClient, songId: string): Promise<void> {
  const { error } = await supabase.from("songs").delete().eq("id", songId)

  if (error) throw error
}

/**
 * Transfer a personal song to a team
 *
 * Clears user_id and sets team_id. The .is("team_id", null) guard ensures
 * only personal songs (not already-transferred ones) are affected.
 *
 * @param songId - Song UUID
 * @param teamId - Target team UUID
 * @returns Promise<void>
 */
export async function transferSongToTeam(
  supabase: SupabaseClient,
  songId: string,
  teamId: string
): Promise<void> {
  const { error } = await supabase
    .from("songs")
    .update({ team_id: teamId, user_id: null })
    .eq("id", songId)
    .is("team_id", null)

  if (error) throw error
}
