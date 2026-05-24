"use client"

import { useEffect, useRef } from "react"
import { createClient } from "@/lib/supabase/client"
import { api } from "@/features/playlists"
import type { Song } from "@/features/songs"

interface PublicPlaylistRealtimeCallbacks {
  onSongsChange: (songs: Song[]) => void
  onPlaylistChange: (update: { visibility: "public" | "private"; allowGuestEditing: boolean }) => void
}

/**
 * Subscribes to realtime changes for a publicly shared playlist.
 *
 * Listens for:
 * - playlist metadata changes (visibility, guest-editing toggle)
 * - song additions, removals, and reorders via playlist_songs
 * - song data edits via the songs table
 *
 * @param playlistId  - UUID of the playlist
 * @param shareCode   - Public share code used to re-fetch songs via the public API
 * @param callbacks   - Called whenever playlist metadata or song list changes
 */
export function usePublicPlaylistRealtime(
  playlistId: string,
  shareCode: string,
  callbacks: PublicPlaylistRealtimeCallbacks
) {
  // Keep callbacks in a ref so the subscription effect never needs to re-run when they change.
  // Update via a separate effect (not during render) to satisfy react-hooks/refs.
  const callbacksRef = useRef(callbacks)
  useEffect(() => {
    callbacksRef.current = callbacks
  })

  // Sequence counter to discard stale fetch results when multiple realtime events fire
  // concurrently (e.g. the two-phase reorder sends 2N events for N songs). Only the result
  // from the latest-initiated fetch is applied; any earlier fetch that resolves out-of-order
  // is ignored to prevent it from overwriting the correct final state.
  const fetchSeqRef = useRef(0)

  useEffect(() => {
    if (!playlistId || !shareCode) return

    const supabase = createClient()

    const fetchSongs = async () => {
      const seq = ++fetchSeqRef.current
      const updated = await api.getPublicPlaylistByShareCode(shareCode)
      if (seq === fetchSeqRef.current && updated) {
        callbacksRef.current.onSongsChange(updated.songs)
      }
    }

    const channel = supabase
      .channel(`share-view:${playlistId}`)
      .on(
        "postgres_changes",
        {
          event: "UPDATE",
          schema: "public",
          table: "playlists",
          filter: `id=eq.${playlistId}`
        },
        (payload) => {
          const updated = payload.new as { is_public: boolean; allow_guest_editing: boolean }
          callbacksRef.current.onPlaylistChange({
            visibility: updated.is_public ? "public" : "private",
            allowGuestEditing: updated.allow_guest_editing ?? false
          })
        }
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "playlist_songs",
          filter: `playlist_id=eq.${playlistId}`
        },
        fetchSongs
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "songs"
          // No row-level filter: songs.playlist_id doesn't exist (relationship is via
          // playlist_songs). Any song edit triggers a refetch via the public share-code
          // API, which naturally scopes the result to this playlist.
        },
        fetchSongs
      )
      .subscribe()

    return () => {
      channel.unsubscribe()
    }
  }, [playlistId, shareCode])
}
