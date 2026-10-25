"use client"

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getUserProfileDataAction, upsertUserPreferencesAction } from "../api/actions"
import { songsKeys } from "./query-keys"
import type { UserPreferences, UserSongSettings } from "../types"

/**
 * Fetches user preferences and primes the individual song settings caches
 * in a single DB query via PostgREST nested select.
 * Pass initialData to skip the first fetch when the server already provided the value.
 */
export function useUserPreferences(initialData?: UserPreferences | null) {
  const queryClient = useQueryClient()

  return useQuery({
    queryKey: songsKeys.userPreferences(),
    queryFn: async () => {
      const result = await getUserProfileDataAction()
      if (result) {
        result.songSettings.forEach((s: UserSongSettings) => {
          queryClient.setQueryData(songsKeys.userSettings(s.songId), s)
        })
      }
      return result?.preferences ?? null
    },
    initialData: initialData === undefined ? undefined : initialData,
    staleTime: 60_000
  })
}

/**
 * Mutation to upsert the current user's preferences.
 * Merges partial updates with the existing cached preferences.
 */
export function useUpsertUserPreferences() {
  const queryClient = useQueryClient()
  const queryKey = songsKeys.userPreferences()

  return useMutation({
    mutationFn: async (updates: Partial<UserPreferences>) => {
      const existing = queryClient.getQueryData<UserPreferences | null>(queryKey)
      const merged: UserPreferences = {
        ...existing,
        ...updates,
        lyricsColumns: updates.lyricsColumns ?? existing?.lyricsColumns ?? 2
      }
      return upsertUserPreferencesAction(merged)
    },
    onMutate: async (updates) => {
      await queryClient.cancelQueries({ queryKey })
      const previous = queryClient.getQueryData<UserPreferences | null>(queryKey)
      queryClient.setQueryData<UserPreferences>(queryKey, (old) => ({
        ...old,
        ...updates,
        lyricsColumns: updates.lyricsColumns ?? old?.lyricsColumns ?? 2
      }))
      return { previous }
    },
    onError: (_err, _updates, context) => {
      queryClient.setQueryData(queryKey, context?.previous)
    },
    onSuccess: (data) => {
      if (data) queryClient.setQueryData(queryKey, data)
    }
  })
}
