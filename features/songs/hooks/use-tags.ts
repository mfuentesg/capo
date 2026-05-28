"use client"

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { useUser } from "@/features/auth"
import { useAppContext } from "@/features/app-context"
import { songsKeys } from "./query-keys"
import type { SongTag } from "../types"
import {
  getTagsForUserAction,
  createTagAction,
  deleteTagAction,
  setSongTagsAction
} from "../api/actions"

/**
 * Fetch all tags accessible to the current user (personal + all team tags).
 */
export function useTags() {
  const { data: user } = useUser()
  const { teams } = useAppContext()
  const teamIds = teams.map((t) => t.id).sort()

  return useQuery({
    queryKey: user?.id ? songsKeys.tagsList(user.id, teamIds) : songsKeys.tags(),
    queryFn: async () => {
      if (!user?.id) return []
      return getTagsForUserAction(user.id, teamIds)
    },
    enabled: !!user?.id,
    staleTime: 60 * 1000
  })
}

/**
 * Create a new tag in the current context.
 */
export function useCreateTag() {
  const queryClient = useQueryClient()
  const { context } = useAppContext()

  return useMutation({
    mutationFn: async ({ name, color }: { name: string; color?: string | null }) => {
      if (!context) throw new Error("No app context")
      return createTagAction(name, color ?? null, context)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: songsKeys.tags() })
    }
  })
}

/**
 * Delete a tag by ID.
 */
export function useDeleteTag() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (tagId: string) => deleteTagAction(tagId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: songsKeys.tags() })
      queryClient.invalidateQueries({ queryKey: songsKeys.lists() })
    }
  })
}

/**
 * Replace all tags on a song. Accepts full SongTag objects so the optimistic
 * update can populate tag data without a secondary cache lookup.
 */
export function useSetSongTags(songId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ tagIds }: { tagIds: string[]; tags: SongTag[] }) =>
      setSongTagsAction(songId, tagIds),
    onMutate: async ({ tags: newTags }) => {
      await queryClient.cancelQueries({ queryKey: songsKeys.lists() })

      queryClient.setQueriesData<{ id: string; tags?: SongTag[] }[]>(
        { queryKey: songsKeys.lists() },
        (old) => {
          if (!Array.isArray(old)) return old
          return old.map((s) => (s.id === songId ? { ...s, tags: newTags } : s))
        }
      )
    },
    onError: () => {
      queryClient.invalidateQueries({ queryKey: songsKeys.lists() })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: songsKeys.lists() })
    }
  })
}
