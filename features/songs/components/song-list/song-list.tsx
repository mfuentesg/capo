"use client"

import { memo, useMemo } from "react"
import { Music } from "lucide-react"
import { SongItem } from "@/features/songs"
import { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription } from "@/components/ui/empty"
import { Skeleton } from "@/components/ui/skeleton"
import type { Song, SongListProps } from "@/features/songs/types"
import { usePlaylistDraft } from "@/features/playlist-draft"
import { useTranslation } from "@/hooks/use-translation"
import { useAppContext, useViewFilter } from "@/features/app-context"
import { getBucketColor } from "@/features/songs/utils"

export function SongSkeleton() {
  return (
    <div className="flex items-start gap-4 rounded-lg border p-4 bg-card">
      <Skeleton className="h-10 w-10 shrink-0 rounded-full" />
      <div className="flex-1 min-w-0 space-y-2">
        <div className="space-y-1">
          <Skeleton className="h-4 w-3/4" />
          <Skeleton className="h-3 w-1/2" />
        </div>
        <div className="flex gap-2">
          <Skeleton className="h-5 w-16 rounded-full" />
          <Skeleton className="h-5 w-20 rounded-full" />
        </div>
      </div>
    </div>
  )
}

export const SongList = memo(function SongList({
  songs,
  previewSong,
  selectedSong,
  groupBy,
  filterStatus,
  bpmRange,
  filterTags = [],
  isCreatingNewSong = false,
  isLoading = false,
  onSelectSong
}: SongListProps & { isLoading?: boolean }) {
  const { toggleSongInDraft, isSongInDraft } = usePlaylistDraft()
  const { t } = useTranslation()
  const { teams } = useAppContext()
  const { viewFilter } = useViewFilter()
  const showBucketColors = viewFilter.type === "all"

  const filteredSongs = useMemo(() => {
    return songs.filter((song) => {
      const matchesStatus =
        filterStatus === "all" ||
        (filterStatus === "drafts" ? song.isDraft === true : song.isDraft !== true)

      const bpm = song.bpm ?? 0
      const matchesBpm =
        bpmRange === "all" ||
        (bpmRange === "slow"
          ? bpm < 100
          : bpmRange === "medium"
            ? bpm >= 100 && bpm <= 140
            : bpm > 140)

      const matchesTags =
        filterTags.length === 0 ||
        filterTags.every((tagId) => song.tags?.some((t) => t.id === tagId))

      return matchesStatus && matchesBpm && matchesTags
    })
  }, [bpmRange, filterStatus, filterTags, songs])

  const groupedSongs = useMemo(() => {
    if (groupBy === "none") {
      return { "All Songs": filteredSongs }
    }

    return filteredSongs.reduce(
      (groups, song) => {
        let groupKey: string
        if (groupBy === "key") {
          groupKey = song.key
        } else if (groupBy === "artist") {
          groupKey = song.artist
        } else {
          // "bucket"
          groupKey =
            song.ownership?.type === "team" ? song.ownership.teamName : t.nav?.personal ?? "Personal"
        }
        if (!groups[groupKey]) {
          groups[groupKey] = []
        }
        groups[groupKey].push(song)
        return groups
      },
      {} as Record<string, Song[]>
    )
  }, [filteredSongs, groupBy, t.nav?.personal])

  const sortedGroupKeys = useMemo(() => {
    return Object.keys(groupedSongs).sort((a, b) => a.localeCompare(b))
  }, [groupedSongs])

  const hasAnySongs =
    Object.keys(groupedSongs).length > 0 &&
    Object.values(groupedSongs).some((group) => group.length > 0)

  if (isLoading) {
    return (
      <div className="p-4 space-y-3">
        {Array.from({ length: 8 }).map((_, i) => (
          <SongSkeleton key={i} />
        ))}
      </div>
    )
  }

  if (!hasAnySongs) {
    return (
      <Empty>
        <EmptyHeader>
          <EmptyMedia
            variant="icon"
            className="bg-blue-500/10 text-blue-500 ring-1 ring-blue-500/20"
          >
            <Music />
          </EmptyMedia>
          <EmptyTitle>{t.songs.noSongs}</EmptyTitle>
          <EmptyDescription>{t.common.tryDifferentSearch}</EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  return (
    <div className="p-4">
      {/* Preview Song Entry */}
      {previewSong && (
        <div className="mb-6 relative">
          <div className="rounded-xl border-2 border-orange-500 dark:border-orange-600 bg-orange-100/50 dark:bg-orange-900/20 shadow-lg">
            <div className="relative">
              <div className="absolute top-2 right-2 z-20">
                <span className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-semibold text-white bg-orange-600 rounded-full">
                  <span className="relative flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-white opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-white"></span>
                  </span>
                  {t.playlists.draft}
                </span>
              </div>
              <SongItem
                song={previewSong}
                isSelected={true}
                isInCart={false}
                isPreview={true}
                onSelect={() => {}}
                onToggleCart={() => {}}
              />
            </div>
          </div>
        </div>
      )}

      {sortedGroupKeys.map((groupKey) => (
        <div key={groupKey} className="mb-6">
          {groupBy !== "none" && (
            <div className="sticky top-0 z-10 bg-background py-2 mb-3">
              <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {groupKey}
              </span>
              <span className="ml-2 text-xs text-muted-foreground">
                ({groupedSongs[groupKey].length})
              </span>
            </div>
          )}
          <div className="space-y-3">
            {groupedSongs[groupKey].map((song) => (
              <SongItem
                key={song.id}
                song={song}
                isSelected={!isCreatingNewSong && selectedSong?.id === song.id}
                isInCart={isSongInDraft(song.id)}
                isDisabled={isCreatingNewSong}
                bucketColor={showBucketColors ? getBucketColor(song.ownership, teams) : undefined}
                onSelect={onSelectSong}
                onToggleCart={toggleSongInDraft}
              />
            ))}
          </div>
        </div>
      ))}
    </div>
  )
})
