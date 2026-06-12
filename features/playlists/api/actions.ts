"use server"

import { revalidatePath } from "next/cache"
import { z } from "zod"
import { createClient } from "@/lib/supabase/server"
import { uuidSchema, uuidArraySchema } from "@/lib/validation"
import type { Playlist } from "../types"
import type { AppContext } from "@/features/app-context"
import {
  getPlaylists as getPlaylistsApi,
  getPlaylistsAllBuckets as getPlaylistsAllBucketsApi,
  getPlaylistWithSongs as getPlaylistWithSongsApi,
  createPlaylist as createPlaylistApi,
  updatePlaylist as updatePlaylistApi,
  deletePlaylist as deletePlaylistApi,
  addSongToPlaylist as addSongToPlaylistApi,
  addSongsToPlaylist as addSongsToPlaylistApi,
  removeSongFromPlaylist as removeSongFromPlaylistApi,
  reorderPlaylistSongs as reorderPlaylistSongsApi,
  archivePlaylist as archivePlaylistApi,
  unarchivePlaylist as unarchivePlaylistApi
} from "./playlistsApi"
export async function getPlaylistsAction(context: AppContext): Promise<Playlist[]> {
  const supabase = await createClient()
  return getPlaylistsApi(supabase, context)
}

export async function getPlaylistsAllBucketsAction(
  userId: string,
  teamIds: string[]
): Promise<Playlist[]> {
  uuidSchema.parse(userId)
  uuidArraySchema.parse(teamIds)
  const supabase = await createClient()
  return getPlaylistsAllBucketsApi(supabase, userId, teamIds)
}

export async function getPlaylistWithSongsAction(playlistId: string) {
  uuidSchema.parse(playlistId)
  const supabase = await createClient()
  // Tags are embedded in the playlist query itself — no second round-trip needed
  return getPlaylistWithSongsApi(supabase, playlistId)
}

const createPlaylistSchema = z.object({
  name: z.string().trim().min(1).max(200),
  description: z.string().max(2000).optional(),
  date: z.string().max(40).optional(),
  songs: uuidArraySchema.optional(),
  visibility: z.enum(["private", "public"]).optional(),
  allowGuestEditing: z.boolean().optional()
})

const updatePlaylistSchema = z.looseObject({
  name: z.string().trim().min(1).max(200).optional(),
  description: z.string().max(2000).optional(),
  date: z.string().max(40).optional(),
  songs: uuidArraySchema.optional(),
  visibility: z.enum(["private", "public"]).optional(),
  allowGuestEditing: z.boolean().optional()
})

const reorderUpdatesSchema = z.array(
  z.object({
    songId: uuidSchema,
    position: z.number().int().min(0)
  })
)

export async function createPlaylistAction(
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
  const validated = createPlaylistSchema.parse(playlistData)
  uuidSchema.parse(userId)
  const supabase = await createClient()
  const result = context
    ? await createPlaylistApi(supabase, validated, userId, context)
    : await createPlaylistApi(supabase, validated, userId)
  return result
}

export async function updatePlaylistAction(
  playlistId: string,
  updates: Partial<Playlist>
): Promise<Playlist> {
  uuidSchema.parse(playlistId)
  const validated = updatePlaylistSchema.parse(updates) as Partial<Playlist>
  const supabase = await createClient()
  const result = await updatePlaylistApi(supabase, playlistId, validated)
  if (result.shareCode) {
    revalidatePath(`/shared/${result.shareCode}`)
  }
  return result
}

export async function deletePlaylistAction(playlistId: string): Promise<void> {
  uuidSchema.parse(playlistId)
  const supabase = await createClient()
  await deletePlaylistApi(supabase, playlistId)
}

export async function addSongToPlaylistAction(
  playlistId: string,
  songId: string
): Promise<void> {
  uuidSchema.parse(playlistId)
  uuidSchema.parse(songId)
  const supabase = await createClient()
  await addSongToPlaylistApi(supabase, playlistId, songId)
}

export async function addSongsToPlaylistAction(
  playlistId: string,
  songIds: string[]
): Promise<void> {
  uuidSchema.parse(playlistId)
  uuidArraySchema.parse(songIds)
  const supabase = await createClient()
  await addSongsToPlaylistApi(supabase, playlistId, songIds)
}

export async function removeSongFromPlaylistAction(
  playlistId: string,
  songId: string
): Promise<void> {
  uuidSchema.parse(playlistId)
  uuidSchema.parse(songId)
  const supabase = await createClient()
  await removeSongFromPlaylistApi(supabase, playlistId, songId)
}

export async function reorderPlaylistSongsAction(
  playlistId: string,
  updates: Array<{ songId: string; position: number }>,
  shareCode?: string
): Promise<void> {
  uuidSchema.parse(playlistId)
  reorderUpdatesSchema.parse(updates)
  const supabase = await createClient()
  await reorderPlaylistSongsApi(supabase, playlistId, updates)
  if (shareCode) {
    revalidatePath(`/shared/${shareCode}`)
  }
}

export async function archivePlaylistAction(playlistId: string): Promise<void> {
  uuidSchema.parse(playlistId)
  const supabase = await createClient()
  await archivePlaylistApi(supabase, playlistId)
}

export async function unarchivePlaylistAction(playlistId: string): Promise<void> {
  uuidSchema.parse(playlistId)
  const supabase = await createClient()
  await unarchivePlaylistApi(supabase, playlistId)
}
