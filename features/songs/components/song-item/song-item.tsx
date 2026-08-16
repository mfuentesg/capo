"use client"
import { memo } from "react"
import { Music2, Turtle, Rabbit, Zap, Check, Plus, Repeat } from "lucide-react"
import { Badge } from "@/components/ui/badge"
import { cn } from "@/lib/utils"
import { getKeyColorClasses, getBpmColorClasses, getFrequencyColorClasses } from "@/lib/badge-colors"
import { TeamIcon } from "@/components/ui/icon-picker"
import type { Song } from "@/features/songs/types"
import { TagBadge } from "../tag-badge"

interface SongFrequencyBadgeInfo {
  count: number
  isRecentlyPlayed: boolean
  lastPlayedLabel: string
}

interface SongItemProps {
  song: Song
  isSelected: boolean
  isInCart: boolean
  isDisabled?: boolean
  isPreview?: boolean
  bucketColor?: string
  frequency?: SongFrequencyBadgeInfo
  onSelect: (song: Song) => void
  onToggleCart: (song: Song) => void
}

export const SongItem = memo(function SongItem({
  song,
  isSelected,
  isInCart,
  isDisabled = false,
  isPreview = false,
  bucketColor,
  frequency,
  onSelect,
  onToggleCart
}: SongItemProps) {
  const ownershipLabel =
    song.ownership?.type === "personal"
      ? "Me"
      : song.ownership?.type === "team"
        ? song.ownership.teamName
        : null

  const teamIcon = song.ownership?.type === "team" ? (song.ownership.teamIcon ?? null) : null

  return (
    <div
      onClick={() => !isDisabled && onSelect(song)}
      className={cn(
        "relative group flex items-center gap-3 rounded-xl p-3 overflow-hidden touch-manipulation shadow-sm transition",
        isPreview
          ? "bg-muted cursor-default"
          : isSelected && !isDisabled
            ? "bg-accent-songs/8 shadow-md ring-2 ring-accent-songs/50 cursor-pointer"
            : "bg-card hover:shadow-md hover:-translate-y-px cursor-pointer",
        isDisabled && "opacity-50 cursor-not-allowed"
      )}
    >
      {/* Left icon badge — tapping toggles playlist cart */}
      <button
        onClick={(e) => {
          e.stopPropagation()
          if (!isDisabled) onToggleCart(song)
        }}
        disabled={isDisabled}
        aria-label={isInCart ? "Remove from playlist" : "Add to playlist"}
        title={isInCart ? "Remove from playlist" : "Add to playlist"}
        className={cn(
          "shrink-0 h-11 w-11 rounded-full flex items-center justify-center transition active:scale-90",
          isInCart
            ? "bg-accent-playlists text-white shadow-sm"
            : "bg-accent-songs/12 text-accent-songs group-hover:bg-accent-songs/20",
          isDisabled && "cursor-not-allowed"
        )}
      >
        {isInCart ? <Check className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
      </button>

      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <div className="min-w-0">
          <h4 className="truncate text-sm font-bold leading-tight">{song.title}</h4>
          <div className="flex items-center gap-1.5 mt-0.5">
            <p className="truncate text-xs text-muted-foreground">{song.artist}</p>
            {ownershipLabel && bucketColor && (
              <span
                className="shrink-0 inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium"
                style={{
                  color: bucketColor,
                  background: `color-mix(in oklch, ${bucketColor} 15%, transparent)`
                }}
              >
                {teamIcon ? (
                  <TeamIcon
                    data-testid="ownership-dot"
                    icon={teamIcon}
                    className="h-3 w-3 shrink-0"
                  />
                ) : (
                  <span
                    data-testid="ownership-dot"
                    className="h-1.5 w-1.5 rounded-full shrink-0"
                    style={{ background: bucketColor }}
                  />
                )}
                {ownershipLabel}
              </span>
            )}
          </div>
        </div>

        {/* Metadata Row */}
        <div className="flex flex-wrap items-center gap-1.5">
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
          {frequency && (
            <Badge
              variant="outline"
              className={cn("gap-1.5 text-xs", getFrequencyColorClasses(frequency.isRecentlyPlayed))}
            >
              <Repeat className="h-3 w-3" />
              {`${frequency.count}× · ${frequency.lastPlayedLabel}`}
            </Badge>
          )}
          {song.tags?.map((tag) => (
            <TagBadge key={tag.id} tag={tag} />
          ))}
        </div>
      </div>
    </div>
  )
})
