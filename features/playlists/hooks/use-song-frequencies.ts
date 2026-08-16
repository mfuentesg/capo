"use client"

import { useQuery } from "@tanstack/react-query"
import { getSongFrequenciesAction } from "../api/actions"
import { playlistsKeys } from "./query-keys"
import { useAppContext } from "@/features/app-context"

/**
 * How often each song has appeared across playlists in the current app
 * context, and when it was last played.
 */
export function useSongFrequencies() {
  const { context } = useAppContext()

  return useQuery({
    queryKey: context ? playlistsKeys.frequency(context) : playlistsKeys.frequencies(),
    queryFn: () => getSongFrequenciesAction(context!),
    enabled: !!context
  })
}
