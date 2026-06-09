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
}

export function PlaylistSongItem({ song, index, className }: PlaylistSongItemProps) {
  return (
    <div className={cn("flex items-center gap-2.5", className)}>
      {/* Position badge */}
      <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary tabular-nums">
        {index + 1}
      </div>

      {/* Song Info */}
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        <div className="min-w-0">
          <h4 className="truncate text-sm font-bold leading-tight">{song.title}</h4>
          <p className="mt-0.5 truncate text-xs text-muted-foreground">{song.artist}</p>
        </div>

        <div className="flex flex-wrap items-center gap-1.5">
          <Badge variant="outline" className={cn("gap-1 font-mono text-xs", getKeyColorClasses(song.key))}>
            <Music2 className="h-3 w-3" />
            {song.key}
          </Badge>
          <Badge variant="secondary" className={cn("gap-1 text-xs", getBpmColorClasses(song.bpm))}>
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
