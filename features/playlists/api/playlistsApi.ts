/**
 * Playlists API - Supabase REST API functions
 *
 * Pure functions for data fetching and mutations.
 * No React hooks, no side effects beyond Supabase calls.
 */

import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database, Tables, TablesInsert, TablesUpdate } from "@/lib/supabase/database.types"
import type { AppContext } from "@/features/app-context"
import type { Playlist } from "@/features/playlists/types"
import type { Song } from "@/features/songs"
import { applyContextFilter } from "@/lib/supabase/apply-context-filter"

type PlaylistRow = Tables<"playlists"> & {
  playlist_songs?: Array<{ song_id: string; position: number }>
}

type PlaylistWithSongs = Omit<Playlist, "songs"> & {
  songs: Song[]
  playlist_songs?: Array<{ song_id: string; position: number; song: NestedSongRow }>
}

const SHARE_CODE_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

// Only the columns actually consumed by the Song frontend type
const SONG_FIELDS = "id, title, artist, key, bpm, lyrics, notes, transpose, capo, status"

// Nested select for playlist_songs joined with the minimal song columns
const PLAYLIST_SONGS_WITH_SONG = `
  song_id,
  position,
  song:songs (${SONG_FIELDS})
`

// Subset row type matching SONG_FIELDS — used to type the nested song in query results
type NestedSongRow = Pick<
  Tables<"songs">,
  "id" | "title" | "artist" | "key" | "bpm" | "lyrics" | "notes" | "transpose" | "capo" | "status"
>

function generateShareCode(length = 12): string {
  const bytes = new Uint8Array(length)

  if (typeof globalThis.crypto !== "undefined" && typeof globalThis.crypto.getRandomValues === "function") {
    globalThis.crypto.getRandomValues(bytes)
  } else {
    for (let i = 0; i < length; i++) {
      bytes[i] = Math.floor(Math.random() * 256)
    }
  }

  return Array.from(bytes, (byte) => SHARE_CODE_CHARS[byte % SHARE_CODE_CHARS.length]).join("")
}

function isMissingAllowGuestEditingColumnError(error: { code?: string; message?: string } | null) {
  if (!error) return false
  return error.code === "42703" || error.message?.includes("allow_guest_editing") === true
}

/**
 * Transform database playlist row to app Playlist type
 */
function transformPlaylistRow(row: PlaylistRow): Playlist {
  const songs =
    row.playlist_songs?.sort((a, b) => a.position - b.position).map((ps) => ps.song_id) || []

  return {
    id: row.id,
    userId: row.user_id,
    teamId: row.team_id,
    name: row.name,
    description: row.description || undefined,
    date: row.date || undefined,
    songs,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    visibility: row.is_public ? "public" : "private",
    allowGuestEditing: row.allow_guest_editing ?? false,
    shareCode: row.share_code || undefined,
    archivedAt: row.archived_at || undefined
  }
}

/**
 * Fetch playlists based on context (personal or team)
 *
 * @param supabase - Supabase client instance
 * @param context - App context (personal or team)
 * @returns Promise<Playlist[]> - Array of playlists
 */
export async function getPlaylists(
  supabase: SupabaseClient<Database>,
  context: AppContext
): Promise<Playlist[]> {
  // Build query with playlist_songs joined
  let query = supabase.from("playlists").select(`
      *,
      playlist_songs (
        song_id,
        position
      )
    `)

  query = applyContextFilter(query, context)

  // Order by created_at descending
  const { data, error } = await query.order("created_at", { ascending: false })

  if (error) throw error

  // Transform database rows to app Playlist type
  return (data || []).map(transformPlaylistRow)
}

/**
 * Fetch playlists from all accessible buckets (personal + all teams) in a single query.
 * Falls back to a simple personal query when the user has no teams.
 *
 * @param supabase - Supabase client instance
 * @param userId - Current user ID
 * @param teamIds - Array of team IDs the user belongs to
 * @returns Promise<Playlist[]> - Array of playlists
 */
export async function getPlaylistsAllBuckets(
  supabase: SupabaseClient<Database>,
  userId: string,
  teamIds: string[]
): Promise<Playlist[]> {
  if (teamIds.length === 0) {
    const context: AppContext = { type: "personal", userId }
    return getPlaylists(supabase, context)
  }

  const orFilter = [
    `user_id.eq.${userId}`,
    ...teamIds.map((id) => `team_id.eq.${id}`)
  ].join(",")

  const { data, error } = await supabase
    .from("playlists")
    .select(`*, playlist_songs (song_id, position)`)
    .or(orFilter)
    .order("created_at", { ascending: false })

  if (error) throw error
  return (data || []).map(transformPlaylistRow)
}

/**
 * Fetch playlist with songs (nested query)
 *
 * @param supabase - Supabase client instance
 * @param playlistId - Playlist UUID
 * @returns Promise<PlaylistWithSongs | null> - Playlist with nested songs or null
 */
export async function getPlaylistWithSongs(
  supabase: SupabaseClient<Database>,
  playlistId: string
): Promise<PlaylistWithSongs | null> {
  const { data, error } = await supabase
    .from("playlists")
    .select(`*, playlist_songs (${PLAYLIST_SONGS_WITH_SONG})`)
    .eq("id", playlistId)
    .single()

  if (error) {
    if (error.code === "PGRST116") return null
    throw error
  }

  if (!data) return null

  const sortedPlaylistSongs =
    data.playlist_songs?.sort(
      (a: { position: number }, b: { position: number }) => a.position - b.position
    ) || []

  return {
    id: data.id,
    userId: data.user_id,
    teamId: data.team_id,
    name: data.name,
    description: data.description || undefined,
    date: data.date || undefined,
    songs: sortedPlaylistSongs
      .filter((ps: { song: NestedSongRow | null }) => ps.song !== null)
      .map((ps: { song: NestedSongRow }): Song => {
        const song = ps.song
        return {
          id: song.id,
          title: song.title,
          artist: song.artist || "",
          key: song.key || "",
          bpm: song.bpm || 0,
          lyrics: song.lyrics || undefined,
          notes: song.notes || undefined,
          transpose: song.transpose ?? undefined,
          capo: song.capo ?? undefined,
        }
      }),
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    visibility: data.is_public ? "public" : "private",
    allowGuestEditing: data.allow_guest_editing ?? false,
    shareCode: data.share_code || undefined,
    archivedAt: data.archived_at || undefined,
    playlist_songs: sortedPlaylistSongs
  }
}

/**
 * Fetch public playlist by share code (anonymous access)
 *
 * @param shareCode - Share code string
 * @returns Promise<PlaylistWithSongs | null> - Public playlist or null
 */
export async function getPublicPlaylistByShareCode(
  supabase: SupabaseClient<Database>,
  shareCode: string
): Promise<PlaylistWithSongs | null> {
  const { data, error } = await supabase
    .from("playlists")
    .select(`*, playlist_songs (${PLAYLIST_SONGS_WITH_SONG})`)
    .eq("share_code", shareCode)
    .eq("is_public", true)
    .or("share_expires_at.is.null,share_expires_at.gt.now()")
    .single()

  if (error) {
    if (error.code === "PGRST116") return null
    throw error
  }

  if (!data) return null

  const sortedPlaylistSongs =
    data.playlist_songs?.sort(
      (a: { position: number }, b: { position: number }) => a.position - b.position
    ) || []

  return {
    id: data.id,
    userId: data.user_id,
    teamId: data.team_id,
    name: data.name,
    description: data.description || undefined,
    date: data.date || undefined,
    songs: sortedPlaylistSongs
      .filter((ps: { song: NestedSongRow | null }) => ps.song !== null)
      .map((ps: { song: NestedSongRow }): Song => {
        const song = ps.song
        return {
          id: song.id,
          title: song.title,
          artist: song.artist || "",
          key: song.key || "",
          bpm: song.bpm || 0,
          lyrics: song.lyrics || undefined,
          notes: song.notes || undefined,
          transpose: song.transpose ?? undefined,
          capo: song.capo ?? undefined,
        }
      }),
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    visibility: data.is_public ? "public" : "private",
    allowGuestEditing: data.allow_guest_editing ?? false,
    shareCode: data.share_code || undefined,
    archivedAt: data.archived_at || undefined,
    playlist_songs: sortedPlaylistSongs
  }
}

/**
 * Fetch playlist by share code (authenticated access — RLS handles visibility)
 *
 * @param supabase - Supabase client instance
 * @param shareCode - Share code string
 * @returns Promise<PlaylistWithSongs | null> - Playlist or null if not found/no access
 */
export async function getPlaylistByShareCode(
  supabase: SupabaseClient<Database>,
  shareCode: string
): Promise<PlaylistWithSongs | null> {
  const { data, error } = await supabase
    .from("playlists")
    .select(`*, playlist_songs (${PLAYLIST_SONGS_WITH_SONG})`)
    .eq("share_code", shareCode)
    .single()

  if (error) {
    if (error.code === "PGRST116") return null
    throw error
  }

  if (!data) return null

  const sortedPlaylistSongs =
    data.playlist_songs?.sort(
      (a: { position: number }, b: { position: number }) => a.position - b.position
    ) || []

  return {
    id: data.id,
    userId: data.user_id,
    teamId: data.team_id,
    name: data.name,
    description: data.description || undefined,
    date: data.date || undefined,
    songs: sortedPlaylistSongs
      .filter((ps: { song: NestedSongRow | null }) => ps.song !== null)
      .map((ps: { song: NestedSongRow }): Song => {
        const song = ps.song
        return {
          id: song.id,
          title: song.title,
          artist: song.artist || "",
          key: song.key || "",
          bpm: song.bpm || 0,
          lyrics: song.lyrics || undefined,
          notes: song.notes || undefined,
          transpose: song.transpose ?? undefined,
          capo: song.capo ?? undefined,
        }
      }),
    createdAt: data.created_at,
    updatedAt: data.updated_at,
    visibility: data.is_public ? "public" : "private",
    allowGuestEditing: data.allow_guest_editing ?? false,
    shareCode: data.share_code || undefined,
    archivedAt: data.archived_at || undefined,
    playlist_songs: sortedPlaylistSongs
  }
}

/**
 * Create a new playlist
 *
 * @param supabase - Supabase client instance
 * @param playlistData - Playlist data to insert (from app Playlist type)
 * @param userId - User ID creating the playlist
 * @returns Promise<Playlist> - Created playlist
 */
export async function createPlaylist(
  supabase: SupabaseClient<Database>,
  playlistData: {
    name: string
    description?: string
    date?: string
    songs?: string[]
    visibility?: "private" | "public"
    allowGuestEditing?: boolean
  },
  userId: string,
  context?: AppContext
): Promise<Playlist> {
  // Convert app Playlist to database Insert type
  const isPublic = playlistData.visibility === "public"
  const isTeam = context?.type === "team"
  const playlistInsert: TablesInsert<"playlists"> = {
    name: playlistData.name,
    description: playlistData.description || null,
    date: playlistData.date || null,
    is_public: isPublic,
    allow_guest_editing: playlistData.allowGuestEditing ?? false,
    user_id: isTeam ? null : userId,
    team_id: isTeam ? context.teamId : null,
    created_by: userId,
    // Always pre-assign a share code so playlists can be referenced by code regardless of visibility.
    share_code: generateShareCode()
  }

  // Insert playlist
  let { data: playlistRow, error: playlistError } = await supabase
    .from("playlists")
    .insert(playlistInsert)
    .select()
    .single()

  if (playlistError && isMissingAllowGuestEditingColumnError(playlistError)) {
    const fallbackInsert = { ...playlistInsert }
    delete fallbackInsert.allow_guest_editing

    const retryResult = await supabase.from("playlists").insert(fallbackInsert).select().single()
    playlistRow = retryResult.data
    playlistError = retryResult.error
  }

  if (playlistError) throw playlistError
  if (!playlistRow) throw new Error("Playlist creation failed")

  // Insert playlist_songs if songs are provided
  let insertedSongs: string[] = []
  if (playlistData.songs && playlistData.songs.length > 0 && playlistRow) {
    const playlistSongs = playlistData.songs.map((songId, index) => ({
      playlist_id: playlistRow.id,
      song_id: songId,
      position: index
    }))

    const { error: songsError } = await supabase.from("playlist_songs").insert(playlistSongs)

    if (songsError) {
      // If songs insertion fails, we should probably rollback the playlist
      // For now, log error and continue - playlist is created but without songs
      console.error("Error adding songs to playlist:", songsError)
    } else {
      insertedSongs = playlistData.songs
    }
  }

  // Construct the response from the already-known data — no extra round-trip needed
  return {
    id: playlistRow.id,
    userId: playlistRow.user_id,
    teamId: playlistRow.team_id,
    name: playlistRow.name,
    description: playlistRow.description || undefined,
    date: playlistRow.date || undefined,
    songs: insertedSongs,
    createdAt: playlistRow.created_at,
    updatedAt: playlistRow.updated_at,
    visibility: playlistRow.is_public ? "public" : "private",
    allowGuestEditing: playlistRow.allow_guest_editing ?? false,
    shareCode: playlistRow.share_code || undefined,
    archivedAt: playlistRow.archived_at || undefined
  }
}

/**
 * Update a playlist
 *
 * @param playlistId - Playlist UUID
 * @param updates - Partial playlist data to update
 * @returns Promise<Playlist> - Updated playlist
 */
export async function updatePlaylist(
  supabase: SupabaseClient<Database>,
  playlistId: string,
  updates: Partial<Playlist>
): Promise<Playlist> {
  const dbUpdates: TablesUpdate<"playlists"> = {}

  if (updates.name !== undefined) dbUpdates.name = updates.name
  if (updates.description !== undefined) dbUpdates.description = updates.description || null
  if (updates.date !== undefined) dbUpdates.date = updates.date || null
  if (updates.visibility !== undefined) dbUpdates.is_public = updates.visibility === "public"
  if (updates.allowGuestEditing !== undefined) {
    dbUpdates.allow_guest_editing = updates.allowGuestEditing
  }

  // Avoid broken DB trigger path: on any update, ensure public playlists always have share_code.
  const { data: currentPlaylist, error: currentPlaylistError } = await supabase
    .from("playlists")
    .select("is_public, share_code")
    .eq("id", playlistId)
    .single()

  if (currentPlaylistError) throw currentPlaylistError

  const willBePublic =
    updates.visibility !== undefined ? updates.visibility === "public" : currentPlaylist.is_public
  const nextShareCode = dbUpdates.share_code ?? currentPlaylist.share_code

  if (willBePublic && !nextShareCode) {
    dbUpdates.share_code = generateShareCode()
  }

  const playlistSelect = `
    *,
    playlist_songs (
      song_id,
      position
    )
  `

  if (Object.keys(dbUpdates).length > 0) {
    const updatePayload = { ...dbUpdates }
    let { data, error } = await supabase
      .from("playlists")
      .update(updatePayload)
      .eq("id", playlistId)
      .select(playlistSelect)
      .single()

    if (error && isMissingAllowGuestEditingColumnError(error)) {
      delete updatePayload.allow_guest_editing

      if (Object.keys(updatePayload).length > 0) {
        const retryResult = await supabase
          .from("playlists")
          .update(updatePayload)
          .eq("id", playlistId)
          .select(playlistSelect)
          .single()
        data = retryResult.data
        error = retryResult.error
      } else {
        // Nothing to update — fetch the current state
        const fetchResult = await supabase
          .from("playlists")
          .select(playlistSelect)
          .eq("id", playlistId)
          .single()
        data = fetchResult.data
        error = fetchResult.error
      }
    }

    if (error) throw error
    return transformPlaylistRow(data!)
  }

  // No fields to update — just return the current state
  const { data, error } = await supabase
    .from("playlists")
    .select(playlistSelect)
    .eq("id", playlistId)
    .single()

  if (error) throw error
  return transformPlaylistRow(data)
}

/**
 * Delete a playlist
 *
 * @param playlistId - Playlist UUID
 * @returns Promise<void>
 */
export async function deletePlaylist(
  supabase: SupabaseClient<Database>,
  playlistId: string
): Promise<void> {
  const { error } = await supabase.from("playlists").delete().eq("id", playlistId)

  if (error) throw error
}

/**
 * Archive a playlist (sets archived_at to now)
 */
export async function archivePlaylist(
  supabase: SupabaseClient<Database>,
  playlistId: string
): Promise<void> {
  const { error } = await supabase
    .from("playlists")
    .update({ archived_at: new Date().toISOString() })
    .eq("id", playlistId)

  if (error) throw error
}

/**
 * Unarchive a playlist (clears archived_at)
 */
export async function unarchivePlaylist(
  supabase: SupabaseClient<Database>,
  playlistId: string
): Promise<void> {
  const { error } = await supabase
    .from("playlists")
    .update({ archived_at: null })
    .eq("id", playlistId)

  if (error) throw error
}

/**
 * Add a song to a playlist
 *
 * @param supabase - Supabase client instance
 * @param playlistId - Playlist UUID
 * @param songId - Song UUID
 * @param position - Position in playlist (optional, defaults to end)
 * @returns Promise<void>
 */
export async function addSongToPlaylist(
  supabase: SupabaseClient<Database>,
  playlistId: string,
  songId: string
): Promise<void> {
  const { error } = await supabase.rpc("add_song_to_playlist", {
    p_playlist_id: playlistId,
    p_song_id: songId
  })

  if (error) throw error
}

/**
 * Add multiple songs to a playlist in bulk
 *
 * @param supabase - Supabase client instance
 * @param playlistId - Playlist UUID
 * @param songIds - Array of song UUIDs
 * @returns Promise<void>
 */
export async function addSongsToPlaylist(
  supabase: SupabaseClient<Database>,
  playlistId: string,
  songIds: string[]
): Promise<void> {
  // Get current max position
  const { data: maxPosData } = await supabase
    .from("playlist_songs")
    .select("position")
    .eq("playlist_id", playlistId)
    .order("position", { ascending: false })
    .limit(1)
    .single()

  const startPos = maxPosData ? maxPosData.position + 1 : 0

  const playlistSongs = songIds.map((songId, index) => ({
    playlist_id: playlistId,
    song_id: songId,
    position: startPos + index
  }))

  const { error } = await supabase.from("playlist_songs").insert(playlistSongs)
  if (error) throw error
}

/**
 * Remove a song from a playlist
 *
 * @param supabase - Supabase client instance
 * @param playlistId - Playlist UUID
 * @param songId - Song UUID
 * @returns Promise<void>
 */
export async function removeSongFromPlaylist(
  supabase: SupabaseClient<Database>,
  playlistId: string,
  songId: string
): Promise<void> {
  const { error } = await supabase
    .from("playlist_songs")
    .delete()
    .eq("playlist_id", playlistId)
    .eq("song_id", songId)

  if (error) throw error
}

/**
 * Reorder songs in a playlist
 *
 * @param supabase - Supabase client instance
 * @param playlistId - Playlist UUID
 * @param updates - Array of { songId, position } updates
 * @returns Promise<void>
 */
export async function reorderPlaylistSongs(
  supabase: SupabaseClient<Database>,
  playlistId: string,
  updates: Array<{ songId: string; position: number }>
): Promise<void> {
  // Two-phase update to avoid unique constraint violations on (playlist_id, position).
  // Swapping adjacent positions in parallel (e.g. 0↔1) would temporarily produce two rows
  // with the same position, hitting the playlist_songs_playlist_id_position_key constraint.
  // Phase 1 moves all rows to safe temporary positions (final + large offset), phase 2 sets
  // the final positions — neither phase conflicts with itself or the other.
  const OFFSET = 10000

  const phase1 = updates.map(({ songId, position }) =>
    supabase
      .from("playlist_songs")
      .update({ position: position + OFFSET })
      .eq("playlist_id", playlistId)
      .eq("song_id", songId)
  )

  const phase1Results = await Promise.all(phase1)
  for (const { error } of phase1Results) {
    if (error) throw error
  }

  const phase2 = updates.map(({ songId, position }) =>
    supabase
      .from("playlist_songs")
      .update({ position })
      .eq("playlist_id", playlistId)
      .eq("song_id", songId)
  )

  const phase2Results = await Promise.all(phase2)
  for (const { error } of phase2Results) {
    if (error) throw error
  }
}

/**
 * Ensure playlist has a share code (via RPC)
 * Uses the ensure_share_code RPC function from the database
 * Auto-generates share_code if missing when playlist becomes public
 *
 * @param supabase - Supabase client instance
 * @param playlistId - Playlist UUID
 * @returns Promise<string> - Share code
 */
export async function ensurePlaylistShareCode(
  supabase: SupabaseClient<Database>,
  playlistId: string
): Promise<string> {
  const { data, error } = await supabase.rpc("ensure_share_code", {
    playlist_id: playlistId
  })

  if (error) throw error
  return data as string
}
