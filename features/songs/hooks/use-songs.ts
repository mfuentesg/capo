"use client"

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useUser } from "@/features/auth"
import { api } from "../api"
import {
  getSongsAction,
  getSongsAllBucketsAction,
  createSongAction,
  updateSongAction,
  deleteSongAction,
  transferSongToTeamAction
} from "../api/actions"
import { songsKeys } from "./query-keys"
import type { Song } from "../types"
import { toast } from "sonner"
import { useLocale } from "@/features/settings"
import { useAppContext, useViewFilter, type AppContext } from "@/features/app-context"

type SongQuerySnapshot = Array<[readonly unknown[], Song[] | undefined]>

function snapshotSongQueries(queryClient: ReturnType<typeof useQueryClient>): SongQuerySnapshot {
  return queryClient.getQueriesData<Song[]>({ queryKey: songsKeys.lists() })
}

function restoreSongQueries(
  queryClient: ReturnType<typeof useQueryClient>,
  snapshots?: SongQuerySnapshot
) {
  if (!snapshots) return

  for (const [queryKey, data] of snapshots) {
    queryClient.setQueryData(queryKey, data)
  }
}

/**
 * Hook for fetching songs from all accessible buckets (personal + all teams).
 * Always fetches the full set with ownership info, regardless of the current view filter.
 * Use this when you need to see songs across all contexts (e.g. the add-to-playlist sheet).
 */
export function useAllSongs(searchQuery?: string, initialData?: Song[]) {
  const { context, teams } = useAppContext()
  const { data: user } = useUser()
  // Sort for a stable cache key — team order in the array must not matter
  const teamIds = teams.map((t) => t.id).sort()

  // Only seed the cache from SSR data when there is no active search query.
  // A search query produces a different key, so the unfiltered SSR snapshot
  // must not be used as its initial value.
  const effectiveInitialData = !searchQuery ? initialData : undefined

  return useQuery({
    queryKey: user?.id ? songsKeys.listAll(user.id, teamIds, searchQuery) : songsKeys.lists(),
    queryFn: async () => {
      if (!user?.id) return []
      const teamsMeta = teams.map((t) => ({ id: t.id, name: t.name, icon: t.icon ?? null }))
      return getSongsAllBucketsAction(user.id, teamIds, teamsMeta, searchQuery)
    },
    enabled: !!context && !!user?.id,
    staleTime: 30 * 1000,
    placeholderData: (previousData) => previousData,
    initialData: effectiveInitialData,
    // Treat the SSR snapshot as freshly fetched so React Query does not
    // fire a redundant background request immediately on mount.
    // Passed as a function reference so it is not called during render.
    initialDataUpdatedAt: effectiveInitialData ? Date.now : undefined
  })
}

/**
 * Hook to fetch songs, routing between all-buckets and per-context queries
 * based on the current viewFilter.
 */
export function useSongs(searchQuery?: string, initialData?: Song[]) {
  const { viewFilter } = useViewFilter()
  const { data: user } = useUser()

  const allSongs = useAllSongs(searchQuery, initialData)

  // Derive the effective context from viewFilter when not "all"
  const filteredContext: AppContext | null =
    viewFilter.type === "personal" && user?.id
      ? { type: "personal", userId: user.id }
      : viewFilter.type === "team" && user?.id
        ? { type: "team", teamId: viewFilter.teamId, userId: user.id }
        : null

  const perContextSongs = useQuery({
    queryKey: filteredContext ? songsKeys.list(filteredContext, searchQuery) : songsKeys.lists(),
    queryFn: async () => {
      if (!filteredContext) return []
      return getSongsAction(filteredContext, searchQuery)
    },
    enabled: viewFilter.type !== "all" && !!filteredContext && !!user?.id,
    staleTime: 30 * 1000,
    placeholderData: (previousData) => previousData
  })

  if (viewFilter.type === "all") {
    return allSongs
  }
  return perContextSongs
}

/**
 * Hook to fetch a single song by ID
 */
export function useSong(songId: string | null) {
  return useQuery({
    queryKey: songsKeys.detail(songId || ""),
    queryFn: () => api.getSong(songId!),
    enabled: !!songId
  })
}

/**
 * Hook to fetch multiple songs by their IDs
 */
export function useSongsByIds(songIds: string[]) {
  return useQuery({
    queryKey: [...songsKeys.all, "byIds", [...songIds].sort().join(",")],
    queryFn: () => api.getSongsByIds(songIds),
    enabled: songIds.length > 0
  })
}

/**
 * Hook to create a new song
 */
export function useCreateSong() {
  const queryClient = useQueryClient()
  const { t } = useLocale()
  const { context } = useAppContext()

  return useMutation({
    mutationFn: async ({
      song,
      userId,
      context: contextOverride
    }: {
      song: Partial<Song>
      userId: string
      context?: AppContext
    }) => {
      return createSongAction(song, userId, contextOverride ?? context ?? undefined)
    },
    onSuccess: (newSong) => {
      const song = newSong
      queryClient.invalidateQueries({ queryKey: songsKeys.lists() })
      // Add new song to cache
      queryClient.setQueryData(songsKeys.detail(song.id), song)
      toast.success(t.toasts?.songCreated || "Song created")
    },
    onError: (error) => {
      console.error("Error creating song:", error)
      toast.error(t.toasts?.error || "Failed to create song")
    }
  })
}

/**
 * Hook to update a song with optimistic updates
 */
export function useUpdateSong() {
  const queryClient = useQueryClient()
  const { t } = useLocale()

  return useMutation({
    mutationFn: async ({ songId, updates }: { songId: string; updates: Partial<Song> }) => {
      return updateSongAction(songId, updates)
    },
    onMutate: async ({ songId, updates }) => {
      await queryClient.cancelQueries({ queryKey: songsKeys.lists() })
      const snapshots = snapshotSongQueries(queryClient)
      queryClient.setQueriesData<Song[]>({ queryKey: songsKeys.lists() }, (old) =>
        old?.map((s) => (s.id === songId ? { ...s, ...updates } : s))
      )
      // Also update detail cache
      const previousDetail = queryClient.getQueryData<Song>(songsKeys.detail(songId))
      if (previousDetail) {
        queryClient.setQueryData(songsKeys.detail(songId), { ...previousDetail, ...updates })
      }
      return { snapshots, previousDetail }
    },
    onError: (_err, { songId }, rollbackContext) => {
      restoreSongQueries(queryClient, rollbackContext?.snapshots)
      if (rollbackContext?.previousDetail) {
        queryClient.setQueryData(songsKeys.detail(songId), rollbackContext.previousDetail)
      }
      toast.error(t.toasts?.error || "Failed to update song")
    },
    onSuccess: (updatedSong) => {
      queryClient.setQueriesData<Song[]>({ queryKey: songsKeys.lists() }, (old) =>
        old?.map((s) => (s.id === updatedSong.id ? { ...s, ...updatedSong } : s))
      )
      queryClient.setQueryData(songsKeys.detail(updatedSong.id), updatedSong)
      toast.success(t.toasts?.songUpdated || "Song updated")
    }
  })
}

/**
 * Hook to delete a song with optimistic updates
 */
export function useDeleteSong() {
  const queryClient = useQueryClient()
  const { t } = useLocale()

  return useMutation({
    mutationFn: async (songId: string) => {
      return deleteSongAction(songId)
    },
    onMutate: async (songId) => {
      await queryClient.cancelQueries({ queryKey: songsKeys.lists() })
      const snapshots = snapshotSongQueries(queryClient)
      queryClient.setQueriesData<Song[]>({ queryKey: songsKeys.lists() }, (old) =>
        old?.filter((s) => s.id !== songId)
      )
      return { snapshots }
    },
    onError: (_err, _songId, rollbackContext) => {
      restoreSongQueries(queryClient, rollbackContext?.snapshots)
      toast.error(t.toasts?.error || "Failed to delete song")
    },
    onSuccess: (_, songId) => {
      queryClient.removeQueries({ queryKey: songsKeys.detail(songId) })
      void queryClient.invalidateQueries({ queryKey: songsKeys.lists() })
      toast.success(t.toasts?.songDeleted || "Song deleted")
    }
  })
}

/**
 * Hook to transfer a personal song to a team
 */
export function useTransferSongToTeam() {
  const queryClient = useQueryClient()
  const { t } = useLocale()

  return useMutation({
    mutationFn: async ({ songId, teamId }: { songId: string; teamId: string }) => {
      return transferSongToTeamAction(songId, teamId)
    },
    onMutate: async ({ songId }) => {
      await queryClient.cancelQueries({ queryKey: songsKeys.lists() })
      const snapshots = snapshotSongQueries(queryClient)
      queryClient.setQueriesData<Song[]>({ queryKey: songsKeys.lists() }, (old) =>
        old?.filter((s) => s.id !== songId)
      )
      return { snapshots }
    },
    onSuccess: (_, { songId }) => {
      queryClient.removeQueries({ queryKey: songsKeys.detail(songId) })
      void queryClient.invalidateQueries({ queryKey: songsKeys.lists() })
      toast.success(t.toasts?.songTransferred || "Song transferred to team")
    },
    onError: (error, _vars, rollbackContext) => {
      restoreSongQueries(queryClient, rollbackContext?.snapshots)
      console.error("Error transferring song to team:", error)
      toast.error(t.toasts?.error || "Failed to transfer song")
    }
  })
}
