/**
 * Query key factory for songs
 *
 * Provides consistent query key patterns for React Query cache management
 */

import type { AppContext } from "@/features/app-context"

/**
 * Query key factory for songs
 */
export const songsKeys = {
  all: ["songs"] as const,
  lists: () => [...songsKeys.all, "list"] as const,
  list: (context: AppContext, searchQuery?: string) =>
    [...songsKeys.lists(), context, searchQuery ?? ""] as const,
  listAll: (userId: string, teamIds: string[], searchQuery?: string) =>
    [...songsKeys.lists(), "all", userId, teamIds, searchQuery ?? ""] as const,
  details: () => [...songsKeys.all, "detail"] as const,
  detail: (id: string) => [...songsKeys.details(), id] as const,
  allUserSettings: () => [...songsKeys.all, "user-settings", "all"] as const,
  userSettings: (songId: string) => [...songsKeys.detail(songId), "user-settings"] as const,
  userPreferences: () => [...songsKeys.all, "user-preferences"] as const
} as const
