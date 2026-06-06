"use client"

import { Music2, Turtle, Rabbit, Zap } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"
import { getKeyColorClasses, getBpmColorClasses } from "@/lib/badge-colors"
import type { SongWithPosition } from "@/types/extended"

interface PlaylistSongItemProps {
  song: SongWithPosition
  index: number
  className?: string
  showDragHandle?: boolean
}

export function PlaylistSongItem({ song, index, className, showDragHandle }: PlaylistSongItemProps) {
  return (
    <div
      className={cn(
        "group flex items-start gap-4 rounded-xl bg-white dark:bg-card border border-border/60 shadow-sm p-4 transition-shadow hover:shadow-md hover:border-border",
        showDragHandle && "pr-10",
        className
      )}
    >
      {/* Position number — morphs to a music icon on hover to hint that the item is tappable */}
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary/10 text-base font-bold text-primary">
        {showDragHandle ? (
          <>
            <span className="group-hover:hidden">{index + 1}</span>
            <Music2 className="hidden h-4 w-4 group-hover:block" />
          </>
        ) : (
          index + 1
        )}
      </div>

      {/* Song Info */}
      <div className="flex min-w-0 flex-1 flex-col gap-2">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <h4 className="truncate text-base font-semibold leading-tight">{song.title}</h4>
            <p className="mt-0.5 truncate text-sm text-muted-foreground">{song.artist}</p>
          </div>
        </div>

        {/* Metadata Row */}
        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="outline" className={cn("gap-1.5 font-mono text-xs", getKeyColorClasses(song.key))}>
            <Music2 className="h-3 w-3" />
            {song.key}
          </Badge>
          <Badge variant="secondary" className={cn("gap-1.5 text-xs", getBpmColorClasses(song.bpm))}>
            {song.bpm < 90 ? (
              <Turtle className="h-3 w-3" />
            ) : song.bpm <= 120 ? (
              <Rabbit className="h-3 w-3" />
            ) : (
              <Zap className="h-3 w-3" />
            )}
            {song.bpm} BPM
          </Badge>
        </div>
      </div>
    </div>
  )
}
