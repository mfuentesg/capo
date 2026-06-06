"use client"

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  getPlaylistsAction,
  getPlaylistsAllBucketsAction,
  getPlaylistWithSongsAction,
  createPlaylistAction,
  updatePlaylistAction,
  deletePlaylistAction,
  archivePlaylistAction,
  unarchivePlaylistAction,
  addSongsToPlaylistAction,
  reorderPlaylistSongsAction
} from "../api/actions"
import { playlistsKeys } from "./query-keys"
import type { Playlist } from "../types"
import { toast } from "sonner"
import { useLocale } from "@/features/settings"
import { useAppContext, useViewFilter, type AppContext } from "@/features/app-context"
import { useUser } from "@/features/auth"
import { useRouter } from "next/navigation"

type PlaylistQuerySnapshot = Array<[readonly unknown[], Playlist[] | undefined]>

function snapshotPlaylistQueries(queryClient: ReturnType<typeof useQueryClient>): PlaylistQuerySnapshot {
  return queryClient.getQueriesData<Playlist[]>({ queryKey: playlistsKeys.lists() })
}

function restorePlaylistQueries(
  queryClient: ReturnType<typeof useQueryClient>,
  snapshots?: PlaylistQuerySnapshot
) {
  if (!snapshots) return

  for (const [queryKey, data] of snapshots) {
    queryClient.setQueryData(queryKey, data)
  }
}

/**
 * Internal hook for fetching playlists from all accessible buckets
 */
function useAllPlaylists(initialData?: Playlist[]) {
  const { context, teams } = useAppContext()
  const { data: user } = useUser()

  return useQuery({
    queryKey: user?.id ? playlistsKeys.listAll(user.id) : playlistsKeys.lists(),
    queryFn: async () => {
      if (!user?.id) return []
      const teamIds = teams.map((t) => t.id)
      return getPlaylistsAllBucketsAction(user.id, teamIds)
    },
    enabled: !!context && !!user?.id,
    staleTime: 30 * 1000,
    placeholderData: (previousData) => previousData,
    initialData,
    // Treat the SSR snapshot as freshly fetched so React Query does not
    // fire a redundant background request immediately on mount.
    // Passed as a function reference so it is not called during render.
    initialDataUpdatedAt: initialData ? Date.now : undefined
  })
}

/**
 * Hook to fetch playlists, routing between all-buckets and per-context queries
 * based on the current viewFilter.
 */
export function usePlaylists(initialData?: Playlist[]) {
  const { viewFilter } = useViewFilter()
  const { data: user } = useUser()

  const allPlaylists = useAllPlaylists(initialData)

  const filteredContext: AppContext | null =
    viewFilter.type === "personal" && user?.id
      ? { type: "personal", userId: user.id }
      : viewFilter.type === "team" && user?.id
        ? { type: "team", teamId: viewFilter.teamId, userId: user.id }
        : null

  const perContextPlaylists = useQuery({
    queryKey: filteredContext ? playlistsKeys.list(filteredContext) : playlistsKeys.lists(),
    queryFn: async () => {
      if (!filteredContext) return []
      return getPlaylistsAction(filteredContext)
    },
    enabled: viewFilter.type !== "all" && !!filteredContext,
    staleTime: 30 * 1000,
    placeholderData: (previousData) => previousData,
    initialData: viewFilter.type !== "all" ? initialData : undefined
  })

  if (viewFilter.type === "all") {
    return allPlaylists
  }
  return perContextPlaylists
}

/**
 * Hook to create a new playlist
 */
export function useCreatePlaylist() {
  const queryClient = useQueryClient()
  const { t } = useLocale()
  const { context } = useAppContext()
  const router = useRouter()

  return useMutation({
    mutationFn: async ({
      playlist,
      userId,
      context: contextOverride
    }: {
      playlist: Playlist
      userId: string
      context?: AppContext
    }) => {
      return createPlaylistAction(playlist, userId, contextOverride ?? context ?? undefined)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: playlistsKeys.lists() })
      toast.success(t.toasts?.playlistCreated || "Playlist created", {
        action: {
          label: t.toasts?.viewPlaylists || "View playlists",
          onClick: () => router.push("/dashboard/playlists")
        }
      })
    },
    onError: (error) => {
      console.error("Error creating playlist:", error)
      toast.error(t.toasts?.error || "Something went wrong")
    }
  })
}

/**
 * Hook to update a playlist with optimistic updates
 */
export function useUpdatePlaylist() {
  const queryClient = useQueryClient()
  const { t } = useLocale()

  return useMutation({
    mutationFn: async ({
      playlistId,
      updates
    }: {
      playlistId: string
      updates: Partial<Playlist>
    }) => {
      return updatePlaylistAction(playlistId, updates)
    },
    onMutate: async ({ playlistId, updates }) => {
      await queryClient.cancelQueries({ queryKey: playlistsKeys.lists() })
      const snapshots = snapshotPlaylistQueries(queryClient)
      queryClient.setQueriesData<Playlist[]>({ queryKey: playlistsKeys.lists() }, (old) =>
        old?.map((p) => (p.id === playlistId ? { ...p, ...updates } : p))
      )
      return { snapshots }
    },
    onError: (_err, _vars, rollbackContext) => {
      restorePlaylistQueries(queryClient, rollbackContext?.snapshots)
      toast.error(t.toasts?.error || "Something went wrong")
    },
    onSuccess: (updatedPlaylist) => {
      queryClient.setQueriesData<Playlist[]>({ queryKey: playlistsKeys.lists() }, (old) =>
        old?.map((p) => (p.id === updatedPlaylist.id ? updatedPlaylist : p))
      )
      toast.success(t.toasts?.playlistUpdated || "Playlist updated")
    }
  })
}

/**
 * Hook to delete a playlist with optimistic updates
 */
export function useDeletePlaylist() {
  const queryClient = useQueryClient()
  const { t } = useLocale()

  return useMutation({
    mutationFn: async (playlistId: string) => {
      return deletePlaylistAction(playlistId)
    },
    onMutate: async (playlistId) => {
      await queryClient.cancelQueries({ queryKey: playlistsKeys.lists() })
      const snapshots = snapshotPlaylistQueries(queryClient)
      queryClient.setQueriesData<Playlist[]>({ queryKey: playlistsKeys.lists() }, (old) =>
        old?.filter((p) => p.id !== playlistId)
      )
      return { snapshots }
    },
    onError: (_err, _vars, rollbackContext) => {
      restorePlaylistQueries(queryClient, rollbackContext?.snapshots)
      toast.error(t.toasts?.error || "Something went wrong")
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: playlistsKeys.lists() })
      toast.success(t.toasts?.playlistDeleted || "Playlist deleted")
    }
  })
}

/**
 * Hook to archive a playlist with optimistic updates
 */
export function useArchivePlaylist() {
  const queryClient = useQueryClient()
  const { t } = useLocale()

  return useMutation({
    mutationFn: async (playlistId: string) => {
      return archivePlaylistAction(playlistId)
    },
    onMutate: async (playlistId) => {
      await queryClient.cancelQueries({ queryKey: playlistsKeys.lists() })
      const snapshots = snapshotPlaylistQueries(queryClient)
      queryClient.setQueriesData<Playlist[]>({ queryKey: playlistsKeys.lists() }, (old) =>
        old?.map((p) =>
          p.id === playlistId ? { ...p, archivedAt: new Date().toISOString() } : p
        )
      )
      return { snapshots }
    },
    onError: (_err, _vars, rollbackContext) => {
      restorePlaylistQueries(queryClient, rollbackContext?.snapshots)
      toast.error(t.toasts?.error || "Something went wrong")
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: playlistsKeys.lists() })
      toast.success(t.toasts?.playlistArchived || "Playlist archived")
    }
  })
}

/**
 * Hook to unarchive a playlist with optimistic updates
 */
export function useUnarchivePlaylist() {
  const queryClient = useQueryClient()
  const { t } = useLocale()

  return useMutation({
    mutationFn: async (playlistId: string) => {
      return unarchivePlaylistAction(playlistId)
    },
    onMutate: async (playlistId) => {
      await queryClient.cancelQueries({ queryKey: playlistsKeys.lists() })
      const snapshots = snapshotPlaylistQueries(queryClient)
      queryClient.setQueriesData<Playlist[]>({ queryKey: playlistsKeys.lists() }, (old) =>
        old?.map((p) => (p.id === playlistId ? { ...p, archivedAt: undefined } : p))
      )
      return { snapshots }
    },
    onError: (_err, _vars, rollbackContext) => {
      restorePlaylistQueries(queryClient, rollbackContext?.snapshots)
      toast.error(t.toasts?.error || "Something went wrong")
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: playlistsKeys.lists() })
      toast.success(t.toasts?.playlistUnarchived || "Playlist unarchived")
    }
  })
}

/**
 * Hook to add multiple songs to an existing playlist
 */
export function useAddSongsToPlaylist() {
  const queryClient = useQueryClient()
  const { t } = useLocale()
  const router = useRouter()

  return useMutation({
    mutationFn: async ({ playlistId, songIds }: { playlistId: string; songIds: string[] }) => {
      return addSongsToPlaylistAction(playlistId, songIds)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: playlistsKeys.lists() })
      toast.success(t.toasts?.songsAdded || "Songs added to playlist", {
        action: {
          label: t.toasts?.viewPlaylists || "View playlists",
          onClick: () => router.push("/dashboard/playlists")
        }
      })
    },
    onError: (error) => {
      console.error("Error adding songs to playlist:", error)
      toast.error(t.toasts?.error || "Something went wrong")
    }
  })
}

/**
 * Hook to fetch a single playlist with full song data (joined query via server action)
 */
export function usePlaylistSongs(playlistId: string | null) {
  return useQuery({
    queryKey: playlistId ? playlistsKeys.detail(playlistId) : ["playlists", "detail", null],
    queryFn: () => getPlaylistWithSongsAction(playlistId!),
    enabled: !!playlistId,
    staleTime: 30 * 1000
  })
}

/**
 * Hook to reorder songs within a playlist
 */
export function useReorderPlaylistSongs() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({
      playlistId,
      sourceIndex,
      destinationIndex,
      currentSongs
    }: {
      playlistId: string
      sourceIndex: number
      destinationIndex: number
      currentSongs: string[]
    }) => {
      const newSongs = Array.from(currentSongs)
      const [removed] = newSongs.splice(sourceIndex, 1)
      newSongs.splice(destinationIndex, 0, removed)

      const updates = newSongs.map((songId, position) => ({ songId, position }))
      return reorderPlaylistSongsAction(playlistId, updates)
    },
    onMutate: async ({ playlistId, sourceIndex, destinationIndex, currentSongs }) => {
      const detailKey = playlistsKeys.detail(playlistId)

      await queryClient.cancelQueries({ queryKey: playlistsKeys.lists() })
      await queryClient.cancelQueries({ queryKey: detailKey })

      const snapshots = snapshotPlaylistQueries(queryClient)
      const detailSnapshot = queryClient.getQueryData(detailKey)

      const newSongs = Array.from(currentSongs)
      const [removed] = newSongs.splice(sourceIndex, 1)
      newSongs.splice(destinationIndex, 0, removed)

      // Optimistic update: playlist list (songs as string IDs)
      queryClient.setQueriesData<Playlist[]>({ queryKey: playlistsKeys.lists() }, (old) =>
        old?.map((p) => (p.id !== playlistId ? p : { ...p, songs: newSongs }))
      )

      // Optimistic update: playlist detail (songs as full Song objects)
      const detailData = queryClient.getQueryData<{ songs: Array<{ id: string }> }>(detailKey)
      if (detailData?.songs) {
        const newDetailSongs = Array.from(detailData.songs)
        const [removedSong] = newDetailSongs.splice(sourceIndex, 1)
        newDetailSongs.splice(destinationIndex, 0, removedSong)
        queryClient.setQueryData(detailKey, { ...detailData, songs: newDetailSongs })
      }

      return { snapshots, detailSnapshot, detailKey }
    },
    onError: (_err, _vars, rollbackContext) => {
      restorePlaylistQueries(queryClient, rollbackContext?.snapshots)
      if (rollbackContext?.detailSnapshot !== undefined) {
        queryClient.setQueryData(rollbackContext.detailKey, rollbackContext.detailSnapshot)
      }
    }
  })
}
