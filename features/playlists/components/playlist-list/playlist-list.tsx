"use client"

import { useMemo } from "react"
import { ListMusic } from "lucide-react"
import { PlaylistItem } from "../playlist-item"
import { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription } from "@/components/ui/empty"
import { Skeleton } from "@/components/ui/skeleton"
import type { Playlist } from "@/features/playlists/types"
import { useTranslation } from "@/hooks/use-translation"
import { useAppContext, useViewFilter } from "@/features/app-context"
import { getBucketColor } from "@/features/songs"
import type { SongOwnership } from "@/features/songs"

interface PlaylistListProps {
  playlists: Playlist[]
  searchQuery: string
  filterVisibility?: "all" | "public" | "private"
  selectedPlaylistId?: string | null
  isLoading?: boolean
  onSelectPlaylist: (playlist: Playlist) => void
}

export function PlaylistSkeleton() {
  return (
    <div className="flex w-full items-center gap-3 rounded-lg p-3 border border-border/60">
      <Skeleton className="h-10 w-10 shrink-0" />
      <div className="flex-1 min-w-0 space-y-2">
        <div className="flex items-center gap-2">
          <Skeleton className="h-4 w-32" />
        </div>
        <div className="flex items-center gap-3">
          <Skeleton className="h-3 w-20" />
          <Skeleton className="h-3 w-10" />
        </div>
      </div>
    </div>
  )
}

export function PlaylistList({
  playlists,
  searchQuery,
  filterVisibility = "all",
  selectedPlaylistId = null,
  isLoading = false,
  onSelectPlaylist
}: PlaylistListProps) {
  const { t } = useTranslation()
  const { teams } = useAppContext()
  const { viewFilter } = useViewFilter()
  const showBucketColors = viewFilter.type === "all"

  const filteredPlaylists = useMemo(() => {
    let filtered = playlists.filter((playlist) =>
      playlist.name.toLowerCase().includes(searchQuery.toLowerCase())
    )

    // Apply visibility filter
    if (filterVisibility === "public") {
      filtered = filtered.filter((playlist) => playlist.visibility === "public")
    } else if (filterVisibility === "private") {
      filtered = filtered.filter((playlist) => playlist.visibility === "private")
    }

    return filtered
  }, [searchQuery, playlists, filterVisibility])

  if (isLoading) {
    return (
      <div className="p-2 space-y-2">
        {Array.from({ length: 5 }).map((_, i) => (
          <PlaylistSkeleton key={i} />
        ))}
      </div>
    )
  }

  if (filteredPlaylists.length === 0) {
    return (
      <Empty>
        <EmptyHeader>
          <EmptyMedia variant="icon" className="bg-accent-playlists/10 text-accent-playlists ring-1 ring-accent-playlists/20">
            <ListMusic />
          </EmptyMedia>
          <EmptyTitle>{t.playlists.noPlaylists}</EmptyTitle>
          <EmptyDescription>{t.common.tryDifferentSearch}</EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  return (
    <div className="p-2 space-y-2">
      {filteredPlaylists.map((playlist) => {
        let ownershipLabel: string | undefined
        let bucketColor: string | undefined

        let teamIcon: string | null = null

        if (showBucketColors && playlist.teamId) {
          const team = teams.find((t) => t.id === playlist.teamId)
          if (team) {
            const ownership: SongOwnership = {
              type: "team",
              teamId: team.id,
              teamName: team.name,
              teamIcon: team.icon ?? null
            }
            ownershipLabel = team.name.split(" ")[0]
            bucketColor = getBucketColor(ownership, teams)
            teamIcon = team.icon ?? null
          }
        }

        return (
          <PlaylistItem
            key={playlist.id}
            playlist={playlist}
            isSelected={selectedPlaylistId === playlist.id}
            ownershipLabel={ownershipLabel}
            bucketColor={bucketColor}
            teamIcon={teamIcon}
            onSelect={onSelectPlaylist}
          />
        )
      })}
    </div>
  )
}
