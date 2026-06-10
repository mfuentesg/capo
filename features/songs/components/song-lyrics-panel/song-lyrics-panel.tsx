"use client"

import { useMemo } from "react"
import { LyricsView } from "@/features/lyrics-editor"
import { Skeleton } from "@/components/ui/skeleton"
import { useUserSongSettings, useEffectiveSongSettings, useUpsertUserSongSettings } from "../../hooks/use-user-song-settings"
import { useUpdateSong, useSong } from "../../hooks/use-songs"
import { SongActionsMenu } from "../song-actions-menu"
import type { Song } from "../../types"

interface SongLyricsPanelProps {
  song: Song
  onClose: () => void
  onDelete: (songId: string) => void
  onTransferSuccess: () => void
}

export function SongLyricsPanel({ song, onClose, onDelete, onTransferSuccess }: SongLyricsPanelProps) {
  // List queries exclude lyrics/notes (heavy text), so fetch the full song here.
  // Everything else (title, tags, optimistic updates) stays driven by the list item.
  const { data: fullSong, isPending: isLoadingContent } = useSong(song.id)
  const resolvedSong = useMemo<Song>(
    () => ({
      ...song,
      lyrics: song.lyrics ?? fullSong?.lyrics,
      notes: song.notes ?? fullSong?.notes
    }),
    [song, fullSong]
  )

  useUserSongSettings(resolvedSong, undefined)
  const effectiveSettings = useEffectiveSongSettings(resolvedSong)
  const { mutate: upsertSettings } = useUpsertUserSongSettings(resolvedSong)
  const { mutate: updateSong } = useUpdateSong()

  if (resolvedSong.lyrics === undefined && isLoadingContent) {
    return (
      <div className="flex flex-1 flex-col p-4 lg:p-6 space-y-4">
        <div className="flex items-center justify-between">
          <div className="space-y-2">
            <Skeleton className="h-5 w-40" />
            <Skeleton className="h-4 w-28" />
          </div>
          <Skeleton className="h-8 w-8 rounded-md" />
        </div>
        <div className="space-y-3 pt-4">
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-5/6" />
          <Skeleton className="h-4 w-2/3" />
          <Skeleton className="h-4 w-3/4" />
          <Skeleton className="h-4 w-1/2" />
        </div>
      </div>
    )
  }

  return (
    <LyricsView
      song={resolvedSong}
      mode="panel"
      readOnly
      onClose={onClose}
      initialSettings={effectiveSettings}
      onSettingsChange={upsertSettings}
      actionsSlot={
        <SongActionsMenu
          song={resolvedSong}
          onUpdate={(songId, updates) => updateSong({ songId, updates })}
          onDelete={onDelete}
          onTransferSuccess={onTransferSuccess}
        />
      }
    />
  )
}
