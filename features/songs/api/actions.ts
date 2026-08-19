"use server"

import { z } from "zod"
import { createClient } from "@/lib/supabase/server"
import { uuidSchema, uuidArraySchema } from "@/lib/validation"
import type { Song, UserSongSettings, UserPreferences, SongTag } from "../types"
import type { UserProfileData } from "./user-preferences-api"
import type { AppContext } from "@/features/app-context"
import {
  getSongs as getSongsApi,
  getSongsAllBuckets as getSongsAllBucketsApi,
  createSong as createSongApi,
  updateSong as updateSongApi,
  deleteSong as deleteSongApi,
  transferSongToTeam as transferSongToTeamApi
} from "./songsApi"
import {
  getUserSongSettings as getUserSongSettingsApi,
  upsertUserSongSettings as upsertUserSongSettingsApi,
  getAllUserSongSettings as getAllUserSongSettingsApi
} from "./user-song-settings-api"
import {
  getUserProfileData as getUserProfileDataApi,
  upsertUserPreferences as upsertUserPreferencesApi
} from "./user-preferences-api"
import {
  getTagAssignmentsForSongs as getTagAssignmentsForSongsApi,
  getTagsForContext as getTagsForContextApi,
  getTagsForUser as getTagsForUserApi,
  createTag as createTagApi,
  deleteTag as deleteTagApi,
  setSongTags as setSongTagsApi
} from "./tags-api"
import { validateCifraClubUrl } from "../utils/cifraclub/validate-url"
import { fetchCifraClubPage } from "../utils/cifraclub/fetch-cifraclub-page"
import { parseCifraClubHtml } from "../utils/cifraclub/parse-html"
import type { CifraClubImportResult } from "../types/cifraclub-import.types"

// Validates user-editable song fields on create/update; unknown keys (e.g.
// ownership, userSettings) pass through untouched and are handled by the API layer.
const songFieldsSchema = z.looseObject({
  title: z.string().trim().min(1).max(200).optional(),
  artist: z.string().trim().max(200).optional(),
  key: z.string().max(12).optional(),
  bpm: z.number().int().min(0).max(400).optional(),
  lyrics: z.string().max(100_000).optional(),
  notes: z.string().max(10_000).optional(),
  // fontSize is a scale factor (UI range 0.5–3), not pixels
  fontSize: z.number().min(0.25).max(10).optional(),
  transpose: z.number().int().min(-11).max(11).optional(),
  capo: z.number().int().min(0).max(24).optional()
})

const tagNameSchema = z.string().trim().min(1).max(50)
const tagColorSchema = z.string().max(32).nullable()

export async function getSongsAction(context: AppContext, searchQuery?: string): Promise<Song[]> {
  const supabase = await createClient()
  // Tags are embedded in the songs query itself, so both fetches run in parallel
  const [songs, settings] = await Promise.all([
    getSongsApi(supabase, context, searchQuery),
    getAllUserSongSettingsApi(supabase, context.userId)
  ])
  const settingsBySongId = new Map(settings.map((s) => [s.songId, s]))
  return songs.map((song) => ({
    ...song,
    userSettings: settingsBySongId.get(song.id) ?? null
  }))
}

export async function getSongsAllBucketsAction(
  userId: string,
  teamIds: string[],
  teams: { id: string; name: string; icon: string | null }[],
  searchQuery?: string
): Promise<Song[]> {
  uuidSchema.parse(userId)
  uuidArraySchema.parse(teamIds)
  const supabase = await createClient()
  // Tags are embedded in the songs query itself, so both fetches run in parallel
  const [songs, settings] = await Promise.all([
    getSongsAllBucketsApi(supabase, userId, teamIds, teams, searchQuery),
    getAllUserSongSettingsApi(supabase, userId)
  ])
  const settingsBySongId = new Map(settings.map((s) => [s.songId, s]))
  return songs.map((song) => ({
    ...song,
    userSettings: settingsBySongId.get(song.id) ?? null
  }))
}

export async function getTagsForContextAction(context: AppContext): Promise<SongTag[]> {
  const supabase = await createClient()
  return getTagsForContextApi(supabase, context)
}

export async function getTagsForUserAction(
  userId: string,
  teamIds: string[]
): Promise<SongTag[]> {
  uuidSchema.parse(userId)
  uuidArraySchema.parse(teamIds)
  const supabase = await createClient()
  return getTagsForUserApi(supabase, userId, teamIds)
}

export async function createTagAction(
  name: string,
  color: string | null,
  context: AppContext
): Promise<SongTag> {
  const validatedName = tagNameSchema.parse(name)
  tagColorSchema.parse(color)
  const supabase = await createClient()
  return createTagApi(supabase, validatedName, color, context)
}

export async function deleteTagAction(tagId: string): Promise<void> {
  uuidSchema.parse(tagId)
  const supabase = await createClient()
  await deleteTagApi(supabase, tagId)
}

export async function setSongTagsAction(songId: string, tagIds: string[]): Promise<void> {
  uuidSchema.parse(songId)
  uuidArraySchema.parse(tagIds)
  const supabase = await createClient()
  await setSongTagsApi(supabase, songId, tagIds)
}

export async function getSongTagsAction(songId: string): Promise<SongTag[]> {
  uuidSchema.parse(songId)
  const supabase = await createClient()
  const tagMap = await getTagAssignmentsForSongsApi(supabase, [songId])
  return tagMap.get(songId) ?? []
}

export async function getTagAssignmentsForSongsAction(
  songIds: string[]
): Promise<Map<string, SongTag[]>> {
  const supabase = await createClient()
  return getTagAssignmentsForSongsApi(supabase, songIds)
}

export async function createSongAction(
  song: Partial<Song>,
  userId: string,
  context?: AppContext
): Promise<Song> {
  const validated = songFieldsSchema.parse(song) as Partial<Song>
  uuidSchema.parse(userId)
  const supabase = await createClient()
  const result = context
    ? await createSongApi(supabase, validated, userId, context)
    : await createSongApi(supabase, validated, userId)
  return result
}

export async function updateSongAction(songId: string, updates: Partial<Song>): Promise<Song> {
  uuidSchema.parse(songId)
  const validated = songFieldsSchema.parse(updates) as Partial<Song>
  const supabase = await createClient()
  return updateSongApi(supabase, songId, validated)
}

export async function deleteSongAction(songId: string): Promise<void> {
  uuidSchema.parse(songId)
  const supabase = await createClient()
  await deleteSongApi(supabase, songId)
}

export async function transferSongToTeamAction(songId: string, teamId: string): Promise<void> {
  uuidSchema.parse(songId)
  uuidSchema.parse(teamId)
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) throw new Error("Unauthorized")
  await transferSongToTeamApi(supabase, songId, teamId)
}

export async function getUserSongSettingsAction(
  songId: string
): Promise<UserSongSettings | null> {
  uuidSchema.parse(songId)
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) return null
  return getUserSongSettingsApi(supabase, user.id, songId)
}

const userSongSettingsSchema = z.object({
  capo: z.number().int().min(0).max(24),
  transpose: z.number().int().min(-11).max(11),
  // fontSize is a scale factor (UI range 0.5–3), not pixels
  fontSize: z.number().min(0.25).max(10).optional()
})

export async function upsertUserSongSettingsAction(
  songId: string,
  settings: Omit<UserSongSettings, "songId">
): Promise<UserSongSettings> {
  uuidSchema.parse(songId)
  userSongSettingsSchema.parse(settings)
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) throw new Error("Unauthorized")
  return upsertUserSongSettingsApi(supabase, user.id, songId, settings)
}

export async function getAllUserSongSettingsAction(): Promise<UserSongSettings[]> {
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) return []
  return getAllUserSongSettingsApi(supabase, user.id)
}

/**
 * Fetches user preferences and all song settings in a single DB query
 * using PostgREST nested selects (profiles → user_song_settings).
 */
export async function getUserProfileDataAction(): Promise<UserProfileData | null> {
  const supabase = await createClient()
  const {
    data: { session }
  } = await supabase.auth.getSession()
  if (!session?.user) return null
  return getUserProfileDataApi(supabase, session.user.id)
}

const userPreferencesSchema = z.object({
  lyricsColumns: z.union([z.literal(1), z.literal(2)]),
  locale: z.string().max(10).optional(),
  theme: z.enum(["light", "dark", "system"]).optional(),
  chordHand: z.enum(["right", "left"]).optional(),
  palette: z.string().max(50).optional(),
  uiFont: z.string().max(50).optional()
})

export async function upsertUserPreferencesAction(
  preferences: UserPreferences
): Promise<UserPreferences | null> {
  userPreferencesSchema.parse(preferences)
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) return null
  return upsertUserPreferencesApi(supabase, user.id, preferences)
}

const cifraClubUrlSchema = z.string().trim().min(1).max(2000)

const CIFRA_IMPORT_RATE_LIMIT = 10
const CIFRA_IMPORT_RATE_WINDOW_MS = 60_000
// Process-local throttle: resets on redeploy and does not coordinate across
// serverless instances, so it's a v1 abuse deterrent rather than a hard
// guarantee. Good enough given imports don't write to Supabase themselves.
const cifraImportAttempts = new Map<string, number[]>()

function isCifraImportRateLimited(key: string): boolean {
  const now = Date.now()
  const recent = (cifraImportAttempts.get(key) ?? []).filter(
    (timestamp) => now - timestamp < CIFRA_IMPORT_RATE_WINDOW_MS
  )
  recent.push(now)
  cifraImportAttempts.set(key, recent)
  return recent.length > CIFRA_IMPORT_RATE_LIMIT
}

// Fetches and parses a CifraClub song page server-side. Unlike the actions
// above, this reaches out to a third-party site, which can fail in many more
// ways than a Supabase call — so it never throws, it always returns a typed
// result the caller can render a message from.
export async function importSongFromCifraClubAction(url: string): Promise<CifraClubImportResult> {
  const parsedInput = cifraClubUrlSchema.safeParse(url)
  if (!parsedInput.success) {
    return { success: false, error: "invalid_url" }
  }

  try {
    const supabase = await createClient()
    const {
      data: { user }
    } = await supabase.auth.getUser()
    if (isCifraImportRateLimited(user?.id ?? "anonymous")) {
      return { success: false, error: "rate_limited" }
    }

    const validated = validateCifraClubUrl(parsedInput.data)
    if (!validated.ok) {
      return { success: false, error: validated.error }
    }

    const fetched = await fetchCifraClubPage(validated.url.href)
    if (!fetched.ok) {
      return { success: false, error: fetched.reason }
    }

    const parsed = parseCifraClubHtml(fetched.html, validated.url)
    if (!parsed.success) {
      return { success: false, error: parsed.error }
    }

    return { success: true, data: parsed.data }
  } catch (err) {
    console.error("[cifraclub-import] Unexpected error:", err)
    return { success: false, error: "unexpected" }
  }
}
