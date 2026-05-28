"use server"

import { createClient } from "@/lib/supabase/server"
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

function mergeTags(songs: Song[], tagMap: Map<string, SongTag[]>): Song[] {
  return songs.map((song) => ({ ...song, tags: tagMap.get(song.id) ?? [] }))
}

export async function getSongsAction(context: AppContext, searchQuery?: string): Promise<Song[]> {
  const supabase = await createClient()
  const [songs, settings] = await Promise.all([
    getSongsApi(supabase, context, searchQuery),
    getAllUserSongSettingsApi(supabase, context.userId)
  ])
  const settingsBySongId = new Map(settings.map((s) => [s.songId, s]))
  const withSettings = songs.map((song) => ({
    ...song,
    userSettings: settingsBySongId.get(song.id) ?? null
  }))
  const tagMap = await getTagAssignmentsForSongsApi(
    supabase,
    withSettings.map((s) => s.id)
  )
  return mergeTags(withSettings, tagMap)
}

export async function getSongsAllBucketsAction(
  userId: string,
  teamIds: string[],
  teams: { id: string; name: string; icon: string | null }[],
  searchQuery?: string
): Promise<Song[]> {
  const supabase = await createClient()
  const [songs, settings] = await Promise.all([
    getSongsAllBucketsApi(supabase, userId, teamIds, teams, searchQuery),
    getAllUserSongSettingsApi(supabase, userId)
  ])
  const settingsBySongId = new Map(settings.map((s) => [s.songId, s]))
  const withSettings = songs.map((song) => ({
    ...song,
    userSettings: settingsBySongId.get(song.id) ?? null
  }))
  const tagMap = await getTagAssignmentsForSongsApi(
    supabase,
    withSettings.map((s) => s.id)
  )
  return mergeTags(withSettings, tagMap)
}

export async function getTagsForContextAction(context: AppContext): Promise<SongTag[]> {
  const supabase = await createClient()
  return getTagsForContextApi(supabase, context)
}

export async function getTagsForUserAction(
  userId: string,
  teamIds: string[]
): Promise<SongTag[]> {
  const supabase = await createClient()
  return getTagsForUserApi(supabase, userId, teamIds)
}

export async function createTagAction(
  name: string,
  color: string | null,
  context: AppContext
): Promise<SongTag> {
  const supabase = await createClient()
  return createTagApi(supabase, name, color, context)
}

export async function deleteTagAction(tagId: string): Promise<void> {
  const supabase = await createClient()
  await deleteTagApi(supabase, tagId)
}

export async function setSongTagsAction(songId: string, tagIds: string[]): Promise<void> {
  const supabase = await createClient()
  await setSongTagsApi(supabase, songId, tagIds)
}

export async function getSongTagsAction(songId: string): Promise<SongTag[]> {
  const supabase = await createClient()
  const tagMap = await getTagAssignmentsForSongsApi(supabase, [songId])
  return tagMap.get(songId) ?? []
}

export async function createSongAction(
  song: Partial<Song>,
  userId: string,
  context?: AppContext
): Promise<Song> {
  const supabase = await createClient()
  const result = context
    ? await createSongApi(supabase, song, userId, context)
    : await createSongApi(supabase, song, userId)
  return result
}

export async function updateSongAction(songId: string, updates: Partial<Song>): Promise<Song> {
  const supabase = await createClient()
  return updateSongApi(supabase, songId, updates)
}

export async function deleteSongAction(songId: string): Promise<void> {
  const supabase = await createClient()
  await deleteSongApi(supabase, songId)
}

export async function transferSongToTeamAction(songId: string, teamId: string): Promise<void> {
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
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) return null
  return getUserSongSettingsApi(supabase, user.id, songId)
}

export async function upsertUserSongSettingsAction(
  songId: string,
  settings: Omit<UserSongSettings, "songId">
): Promise<UserSongSettings> {
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

export async function upsertUserPreferencesAction(
  preferences: UserPreferences
): Promise<UserPreferences | null> {
  const supabase = await createClient()
  const {
    data: { user }
  } = await supabase.auth.getUser()
  if (!user) return null
  return upsertUserPreferencesApi(supabase, user.id, preferences)
}
