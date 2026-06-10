"use client"

import { memo } from "react"
import { Calendar, Music3, Lock, Globe, Users, Archive } from "lucide-react"
import { Tooltip, TooltipTrigger, TooltipContent } from "@/components/ui/tooltip"
import type { Playlist } from "@/features/playlists/types"
import { useTranslation } from "@/hooks/use-translation"
import { formatDate } from "@/lib/utils"
import { cn } from "@/lib/utils"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import { TeamIcon } from "@/components/ui/icon-picker"

interface PlaylistItemProps {
  playlist: Playlist
  isSelected: boolean
  onSelect: (playlist: Playlist) => void
  onArchive?: (playlist: Playlist) => void
  ownershipLabel?: string
  bucketColor?: string
  teamIcon?: string | null
}

export const PlaylistItem = memo(function PlaylistItem({
  playlist,
  isSelected,
  onSelect,
  onArchive,
  ownershipLabel,
  bucketColor,
  teamIcon
}: PlaylistItemProps) {
  const { t } = useTranslation()
  const privateTooltipIds = createOverlayIds(`playlist-private-tooltip-${playlist.id}`)
  const publicTooltipIds = createOverlayIds(`playlist-public-tooltip-${playlist.id}`)

  return (
    <div
      onClick={() => onSelect(playlist)}
      className={cn(
        "relative flex w-full items-center gap-3 rounded-xl p-3 cursor-pointer touch-manipulation shadow-sm transition",
        isSelected
          ? "bg-accent-playlists/10 shadow-md ring-2 ring-accent-playlists/40"
          : "bg-card hover:shadow-md hover:-translate-y-px",
        playlist.archivedAt && "opacity-50"
      )}
    >
      {/* Icon badge */}
      <div
        className="flex h-10 w-10 items-center justify-center rounded-xl shrink-0"
        style={
          bucketColor
            ? { background: `color-mix(in oklch, ${bucketColor} 15%, transparent)` }
            : { background: "color-mix(in oklch, var(--color-accent-playlists) 12%, transparent)" }
        }
      >
        <Music3
          className="h-5 w-5"
          style={
            bucketColor
              ? { color: bucketColor }
              : { color: "var(--color-accent-playlists)" }
          }
        />
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <p className="text-sm font-bold truncate">{playlist.name}</p>
          {playlist.visibility === "private" && (
            <Tooltip>
              <TooltipTrigger
                asChild
                id={privateTooltipIds.triggerId}
                aria-describedby={privateTooltipIds.contentId}
              >
                <Lock className="h-3 w-3 text-muted-foreground shrink-0" />
              </TooltipTrigger>
              <TooltipContent id={privateTooltipIds.contentId}>
                <p>{t.playlistItem.privatePlaylist}</p>
              </TooltipContent>
            </Tooltip>
          )}
          {playlist.visibility === "public" && (
            <Tooltip>
              <TooltipTrigger
                asChild
                id={publicTooltipIds.triggerId}
                aria-describedby={publicTooltipIds.contentId}
              >
                <div className="flex items-center gap-0.5 shrink-0">
                  <Globe className="h-3 w-3 text-muted-foreground" />
                  {playlist.allowGuestEditing && (
                    <Users className="h-3 w-3 text-muted-foreground" />
                  )}
                </div>
              </TooltipTrigger>
              <TooltipContent id={publicTooltipIds.contentId}>
                <p>
                  {playlist.allowGuestEditing
                    ? t.playlistItem.publicGuestEditing
                    : t.playlistItem.publicViewOnly}
                </p>
              </TooltipContent>
            </Tooltip>
          )}
          {playlist.archivedAt && (
            <span className="inline-flex items-center gap-1 rounded-full bg-muted px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground shrink-0">
              <Archive className="h-2.5 w-2.5" />
              {t.playlists.archivedBadge}
            </span>
          )}
        </div>
        <div className="flex items-center gap-3 mt-1">
          {playlist.date && (
            <div className="flex items-center gap-1">
              <Calendar className="h-3 w-3 text-muted-foreground" />
              <p className="text-xs text-muted-foreground">{formatDate(playlist.date)}</p>
            </div>
          )}
          {playlist.songs.length >= 0 && (
            <div className="flex items-center gap-1">
              <Music3 className="h-3 w-3 text-muted-foreground" />
              <p className="text-xs text-muted-foreground">{playlist.songs.length}</p>
            </div>
          )}
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

      {onArchive && (
        <button
          type="button"
          aria-label={playlist.archivedAt ? t.playlists.unarchive : t.playlists.archive}
          onPointerDown={(e) => e.stopPropagation()}
          onClick={(e) => {
            e.stopPropagation()
            onArchive(playlist)
          }}
          className="shrink-0 flex h-9 w-9 items-center justify-center rounded-full text-muted-foreground/60 hover:text-foreground hover:bg-muted transition-colors active:scale-90 touch-manipulation"
        >
          <Archive className="h-4 w-4" />
        </button>
      )}
    </div>
  )
})
