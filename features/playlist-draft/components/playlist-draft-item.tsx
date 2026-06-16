"use client"

import { X, GripVertical, Music2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"
import { getKeyColorClasses, getBpmColorClasses } from "@/lib/badge-colors"
import { TeamIcon } from "@/components/ui/icon-picker"
import { useTranslation } from "@/hooks/use-translation"
import { TagBadge } from "@/features/songs"
import type { Song } from "@/features/songs"

interface PlaylistDraftItemProps {
  song: Song
  index: number
  onRemove: (songId: string) => void
}

export function PlaylistDraftItem({ song, index, onRemove }: PlaylistDraftItemProps) {
  const { t } = useTranslation()

  const ownershipLabel =
    song.ownership?.type === "personal"
      ? "Me"
      : song.ownership?.type === "team"
        ? song.ownership.teamName
        : null

  const teamIcon =
    song.ownership?.type === "team" ? (song.ownership.teamIcon ?? null) : null

  return (
    <div className="flex items-center gap-2.5 rounded-xl bg-card shadow-sm p-3 touch-manipulation">
      {/* Drag handle */}
      <GripVertical className="h-4 w-4 text-muted-foreground/40 cursor-grab shrink-0 touch-none" />

      {/* Position badge */}
      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary tabular-nums">
        {index + 1}
      </div>

      {/* Song info */}
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        <div className="min-w-0">
          <h4 className="truncate text-sm font-bold leading-tight">{song.title}</h4>
          <div className="flex items-center gap-1.5 mt-0.5">
            <p className="truncate text-xs text-muted-foreground">{song.artist}</p>
            {ownershipLabel && (
              <span
                className={cn(
                  "shrink-0 inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium",
                  "bg-primary/10 text-primary"
                )}
              >
                {teamIcon ? (
                  <TeamIcon icon={teamIcon} className="h-3 w-3 shrink-0" />
                ) : (
                  <span className="h-1.5 w-1.5 rounded-full shrink-0 bg-primary" />
                )}
                {ownershipLabel}
              </span>
            )}
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-1.5">
          <Badge variant="outline" className={cn("gap-1 font-mono text-xs", getKeyColorClasses(song.key))}>
            <Music2 className="h-3 w-3" />
            {song.key}
          </Badge>
          <Badge variant="secondary" className={cn("gap-1 text-xs", getBpmColorClasses(song.bpm))}>
            {song.bpm} BPM
          </Badge>
          {song.tags?.map((tag) => (
            <TagBadge key={tag.id} tag={tag} />
          ))}
        </div>
      </div>

      {/* Remove */}
      <Button
        variant="ghost"
        size="icon"
        className="h-9 w-9 shrink-0 text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
        aria-label={t.common.removeSong}
        onClick={() => onRemove(song.id)}
      >
        <X className="h-4 w-4" />
      </Button>
    </div>
  )
}
