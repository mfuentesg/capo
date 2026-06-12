"use client"

import { useEffect, useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { createClient } from "@/lib/supabase/client"
import { useUser } from "@/features/auth"
import { playlistsKeys } from "./query-keys"

/**
 * Real-time hook for playlist collaboration (dashboard view)
 * Subscribes to playlist_songs changes and invalidates the React Query detail cache.
 *
 * @param playlistId - Playlist UUID to subscribe to
 * @returns { isConnected } - Whether the channel is subscribed
 */
export function usePlaylistRealtime(playlistId: string) {
  const queryClient = useQueryClient()
  const { data: user } = useUser()
  const [isConnected, setIsConnected] = useState(false)

  useEffect(() => {
    if (!playlistId) return

    const supabase = createClient()
    const channel = supabase
      .channel(`playlist:${playlistId}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "playlist_songs",
          filter: `playlist_id=eq.${playlistId}`
        },
        () => {
          queryClient.invalidateQueries({ queryKey: playlistsKeys.detail(playlistId) })
        }
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "songs"
          // No row-level filter: songs.playlist_id doesn't exist (relationship is via
          // playlist_songs). Instead, the handler checks the changed song id against
          // the cached playlist and skips invalidation for unrelated songs.
        },
        (payload) => {
          const changedId =
            (payload.new as { id?: string } | null)?.id ??
            (payload.old as { id?: string } | null)?.id
          const cached = queryClient.getQueryData<{ songs?: Array<{ id: string }> }>(
            playlistsKeys.detail(playlistId)
          )
          // Only skip when we can prove the song isn't in this playlist
          if (changedId && cached?.songs && !cached.songs.some((s) => s.id === changedId)) {
            return
          }
          queryClient.invalidateQueries({ queryKey: playlistsKeys.detail(playlistId) })
        }
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "user_song_settings",
          filter: user?.id ? `user_id=eq.${user.id}` : undefined
        },
        () => {
          queryClient.invalidateQueries({ queryKey: playlistsKeys.detail(playlistId) })
        }
      )
      .subscribe((status) => {
        setIsConnected(status === "SUBSCRIBED")
      })

    return () => {
      channel.unsubscribe()
      setIsConnected(false)
    }
  }, [playlistId, queryClient, user?.id])

  return { isConnected }
}
