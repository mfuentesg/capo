"use client"

import { memo, startTransition } from "react"
import { GripVerticalIcon, X } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent
} from "@dnd-kit/core"
import { restrictToVerticalAxis } from "@dnd-kit/modifiers"
import { SortableContext, verticalListSortingStrategy, useSortable } from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"

import { PlaylistSongItem } from "@/features/playlists"
import { type SongWithPosition, type PlaylistWithSongs } from "@/types/extended"
import { blockNextDocumentClick } from "@/lib/dnd"

const SortableSong = memo(
  ({
    song,
    index,
    onSongClick,
    onRemoveSong
  }: {
    song: SongWithPosition
    index: number
    onSongClick?: (index: number) => void
    onRemoveSong?: (songId: string) => void
  }) => {
    const { t } = useTranslation()
    const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
      id: song.id
    })

    const sortStyle = {
      transform: CSS.Transform.toString(transform),
      transition
    }

    return (
      <div
        ref={setNodeRef}
        style={sortStyle}
        {...attributes}
        className={`flex items-center gap-2.5 rounded-xl bg-card shadow-sm p-3 touch-manipulation ${isDragging ? "opacity-70 z-50" : ""}`}
      >
        {/* Drag handle — left side, non-interactive visual only */}
        <div
          {...listeners}
          className="shrink-0 flex items-center justify-center self-stretch px-1 cursor-grab touch-none"
        >
          <GripVerticalIcon className="h-4 w-4 text-muted-foreground/40" />
        </div>

        {/* Song row — tappable to open lyrics */}
        <div
          className={`relative flex-1 min-w-0 cursor-pointer ${isDragging ? "cursor-grabbing" : ""}`}
          onClick={() => startTransition(() => onSongClick?.(index))}
        >
          <PlaylistSongItem song={song} index={index} />
        </div>

        {/* Remove button — right side, properly sized for touch */}
        {onRemoveSong && (
          <button
            type="button"
            aria-label={t.common.removeSong}
            onPointerDown={(e) => e.stopPropagation()}
            onClick={(e) => {
              e.stopPropagation()
              onRemoveSong(song.id)
            }}
            className="shrink-0 flex h-9 w-9 items-center justify-center rounded-full text-muted-foreground/60 hover:text-destructive hover:bg-destructive/10 transition-colors active:scale-90 touch-manipulation"
          >
            <X className="h-4 w-4" />
          </button>
        )}
      </div>
    )
  }
)

SortableSong.displayName = "SortableSong"

export function DraggablePlaylist({
  playlist,
  songs,
  onPlaylistSort,
  onSongClick,
  onRemoveSong
}: {
  playlist: PlaylistWithSongs
  songs: SongWithPosition[]
  onPlaylistSort: (s: number, d: number) => Promise<void>
  onSongClick?: (index: number) => void
  onRemoveSong?: (songId: string) => void
}) {
  const sensors = useSensors(
    useSensor(PointerSensor, {
      // Long-press to activate drag so a quick tap still opens lyrics without
      // accidentally triggering a reorder.
      activationConstraint: { delay: 200, tolerance: 5 }
    })
  )

  const handleDragEnd = (event: DragEndEvent) => {
    // Block the synthetic click that follows pointerup so it doesn't open lyrics.
    blockNextDocumentClick()

    const { active, over } = event
    if (!over || active.id === over.id) return
    const oldIndex = songs.findIndex((s) => s.id === active.id)
    const newIndex = songs.findIndex((s) => s.id === over.id)
    if (oldIndex !== -1 && newIndex !== -1) {
      onPlaylistSort(oldIndex, newIndex)
    }
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      modifiers={[restrictToVerticalAxis]}
      onDragEnd={handleDragEnd}
      onDragCancel={blockNextDocumentClick}
    >
      <SortableContext items={songs.map((s) => s.id)} strategy={verticalListSortingStrategy}>
        <div key={playlist.id} className="space-y-2">
          {songs.map((song, index) => (
            <SortableSong
              key={song.id}
              song={song}
              index={index}
              onSongClick={onSongClick}
              onRemoveSong={onRemoveSong}
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  )
}
