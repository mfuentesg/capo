"use client"

import { LyricsView } from "@/features/lyrics-editor"
import { useUserSongSettings, useEffectiveSongSettings, useUpsertUserSongSettings } from "../../hooks/use-user-song-settings"
import { useUpdateSong } from "../../hooks/use-songs"
import { SongActionsMenu } from "../song-actions-menu"
import type { Song } from "../../types"

interface SongLyricsPanelProps {
  song: Song
  onClose: () => void
  onDelete: (songId: string) => void
  onTransferSuccess: () => void
}

export function SongLyricsPanel({ song, onClose, onDelete, onTransferSuccess }: SongLyricsPanelProps) {
  useUserSongSettings(song, undefined)
  const effectiveSettings = useEffectiveSongSettings(song)
  const { mutate: upsertSettings } = useUpsertUserSongSettings(song)
  const { mutate: updateSong, isPending: isSaving } = useUpdateSong()

  return (
    <LyricsView
      song={song}
      mode="panel"
      onClose={onClose}
      onSaveLyrics={(lyrics) => updateSong({ songId: song.id, updates: { lyrics } })}
      isSaving={isSaving}
      initialSettings={effectiveSettings}
      onSettingsChange={upsertSettings}
      actionsSlot={
        <SongActionsMenu
          song={song}
          onUpdate={(songId, updates) => updateSong({ songId, updates })}
          onDelete={onDelete}
          onTransferSuccess={onTransferSuccess}
        />
      }
    />
  )
}
