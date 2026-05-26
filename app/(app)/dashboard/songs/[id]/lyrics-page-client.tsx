"use client"

import { useSearchParams } from "next/navigation"
import {
  useUpdateSong,
  useUserSongSettings,
  useEffectiveSongSettings,
  useUpsertUserSongSettings,
  useSongRealtime
} from "@/features/songs"
import { LyricsView } from "@/features/lyrics-editor"
import type { Song } from "@/types"
import type { UserSongSettings } from "@/features/songs"

interface LyricsPageClientProps {
  song: Song
  initialUserSettings: UserSongSettings | null
  initialLyricsColumns?: 1 | 2
}

export function LyricsPageClient({
  song,
  initialUserSettings,
  initialLyricsColumns = 2
}: LyricsPageClientProps) {
  useSongRealtime(song.id)
  const { mutate: updateSong, isPending: isSaving } = useUpdateSong()
  useUserSongSettings(song, initialUserSettings)
  const effectiveSettings = useEffectiveSongSettings(song)
  const { mutate: upsertSettings } = useUpsertUserSongSettings(song)
  const searchParams = useSearchParams()
  const initialEditing = searchParams.get("edit") === "true"

  return (
    <LyricsView
      song={song}
      onSaveLyrics={(lyrics) => updateSong({ songId: song.id, updates: { lyrics } })}
      isSaving={isSaving}
      initialSettings={effectiveSettings}
      onSettingsChange={upsertSettings}
      initialLyricsColumns={initialLyricsColumns}
      initialEditing={initialEditing}
    />
  )
}
