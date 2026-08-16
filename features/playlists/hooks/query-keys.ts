/**
 * Query key factory for playlists
 *
 * Provides consistent query key patterns for React Query cache management
 */

import type { AppContext } from "@/features/app-context"

/**
 * Query key factory for playlists
 */
export const playlistsKeys = {
  all: ["playlists"] as const,
  lists: () => [...playlistsKeys.all, "list"] as const,
  list: (context: AppContext) => [...playlistsKeys.lists(), context] as const,
  listAll: (userId: string) => [...playlistsKeys.lists(), "all", userId] as const,
  details: () => [...playlistsKeys.all, "detail"] as const,
  detail: (id: string) => [...playlistsKeys.details(), id] as const,
  public: () => [...playlistsKeys.all, "public"] as const,
  publicByCode: (shareCode: string) => [...playlistsKeys.public(), shareCode] as const,
  frequencies: () => [...playlistsKeys.all, "frequencies"] as const,
  frequency: (context: AppContext) => [...playlistsKeys.frequencies(), context] as const
} as const
