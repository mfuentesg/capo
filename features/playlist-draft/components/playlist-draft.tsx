"use client"

import { useState } from "react"
import { ListMusic } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger
} from "@/components/ui/dialog"
import {
  Drawer,
  DrawerContent,
  DrawerDescription,
  DrawerFooter,
  DrawerHeader,
  DrawerScrollArea,
  DrawerTitle,
  DrawerTrigger
} from "@/components/ui/drawer"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/components/ui/select"
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent
} from "@dnd-kit/core"
import {
  restrictToVerticalAxis,
  restrictToFirstScrollableAncestor
} from "@dnd-kit/modifiers"
import { SortableContext, verticalListSortingStrategy, useSortable } from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { PlaylistDraftItem } from "./playlist-draft-item"
import type { Song } from "@/types"
import type { Playlist } from "@/features/playlists"
import { useSongFrequencies, getFrequencyBadgeInfo } from "@/features/playlists"
import { useTranslation } from "@/hooks/use-translation"
import { useIsMobile } from "@/hooks/use-mobile"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import { blockNextDocumentClick } from "@/lib/dnd"

type SubmitSelection =
  | { type: "new"; name: string }
  | { type: "existing"; playlistId: string }

interface PlaylistDraftProps {
  songs: Song[]
  playlists: Playlist[]
  isOpen: boolean
  onOpenChange: (open: boolean) => void
  onClear: () => void
  onRemove: (songId: string) => void
  onReorder?: (sourceIndex: number, destinationIndex: number) => void
  onSubmit: (selection: SubmitSelection) => Promise<void>
  isSubmitting?: boolean
}

interface PlaylistDraftBodyProps {
  songs: Song[]
  playlists: Playlist[]
  selectedPlaylist: string
  onSelectPlaylist: (value: string) => void
  newPlaylistName: string
  onNewPlaylistNameChange: (value: string) => void
  onRemove: (songId: string) => void
  onDragEnd: (event: DragEndEvent) => void
}

function SortableDraftItem({
  song,
  index,
  frequency,
  onRemove
}: {
  song: Song
  index: number
  frequency?: ReturnType<typeof getFrequencyBadgeInfo>
  onRemove: (songId: string) => void
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: song.id
  })

  return (
    <div
      ref={setNodeRef}
      style={{ transform: CSS.Transform.toString(transform), transition }}
      {...attributes}
      {...listeners}
      className={isDragging ? "opacity-70 z-50" : ""}
    >
      <PlaylistDraftItem song={song} index={index} frequency={frequency} onRemove={onRemove} />
    </div>
  )
}

function PlaylistDraftBody({
  songs,
  playlists,
  selectedPlaylist,
  onSelectPlaylist,
  newPlaylistName,
  onNewPlaylistNameChange,
  onRemove,
  onDragEnd
}: PlaylistDraftBodyProps) {
  const { t } = useTranslation()
  const { data: frequencies = new Map() } = useSongFrequencies()
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { delay: 200, tolerance: 5 } })
  )

  return (
    <>
      <DndContext
        sensors={sensors}
        collisionDetection={closestCenter}
        modifiers={[restrictToVerticalAxis, restrictToFirstScrollableAncestor]}
        onDragEnd={onDragEnd}
        onDragCancel={blockNextDocumentClick}
      >
        <SortableContext items={songs.map((s) => s.id)} strategy={verticalListSortingStrategy}>
          <div className="space-y-2">
            {songs.map((song, index) => (
              <SortableDraftItem
                key={song.id}
                song={song}
                index={index}
                frequency={getFrequencyBadgeInfo(song.id, frequencies)}
                onRemove={onRemove}
              />
            ))}
          </div>
        </SortableContext>
      </DndContext>

      <Select value={selectedPlaylist} onValueChange={onSelectPlaylist}>
        <SelectTrigger className="w-full mt-4">
          <SelectValue placeholder={t.playlistDraft.selectPlaylist} />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="new">{t.playlistDraft.selectNewPlaylist}</SelectItem>
          {playlists.map((playlist) => (
            <SelectItem key={playlist.id} value={playlist.id}>
              {playlist.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>

      {selectedPlaylist === "new" && (
        <Input
          className="mt-2"
          placeholder={t.playlists.playlistNamePlaceholder}
          value={newPlaylistName}
          onChange={(e) => onNewPlaylistNameChange(e.target.value)}
        />
      )}
    </>
  )
}

export function PlaylistDraft({
  songs,
  playlists,
  isOpen,
  onOpenChange,
  onClear,
  onRemove,
  onReorder,
  onSubmit,
  isSubmitting = false
}: PlaylistDraftProps) {
  const [selectedPlaylist, setSelectedPlaylist] = useState<string>("new")
  const [newPlaylistName, setNewPlaylistName] = useState("")
  const { t } = useTranslation()
  const isMobile = useIsMobile()
  const drawerIds = createOverlayIds("playlist-draft-drawer")

  if (songs.length === 0) {
    return null
  }

  const handleDragEnd = (event: DragEndEvent) => {
    blockNextDocumentClick()
    const { active, over } = event
    if (!over || active.id === over.id) return
    const oldIndex = songs.findIndex((s) => s.id === active.id)
    const newIndex = songs.findIndex((s) => s.id === over.id)
    if (oldIndex !== -1 && newIndex !== -1) {
      onReorder?.(oldIndex, newIndex)
    }
  }

  const isAddDisabled = isSubmitting || (selectedPlaylist === "new" && !newPlaylistName.trim())

  const handleAdd = async () => {
    if (selectedPlaylist === "new") {
      await onSubmit({ type: "new", name: newPlaylistName.trim() })
    } else {
      await onSubmit({ type: "existing", playlistId: selectedPlaylist })
    }
  }

  const handleClear = () => {
    onClear()
    onOpenChange(false)
  }

  const trigger = (
    <div className="fixed bottom-6 right-4 sm:right-6 z-50">
      <Button
        className="h-12 rounded-full pl-3 pr-4 shadow-lg gap-2 font-semibold transition active:scale-[0.97]"
        aria-label={t.playlistDraft.openDraft}
        id={drawerIds.triggerId}
        aria-controls={drawerIds.contentId}
      >
        {/* Count bubble */}
        <span className="flex h-6 w-6 items-center justify-center rounded-full bg-primary-foreground/20 text-xs font-bold tabular-nums">
          {songs.length}
        </span>
        <ListMusic className="h-4 w-4" />
        <span className="text-sm">{t.playlistDraft.addToPlaylist}</span>
      </Button>
    </div>
  )

  const actionButtons = (
    <div className="flex gap-2 w-full">
      <Button
        variant="outline"
        className="flex-1 bg-transparent"
        onClick={handleClear}
        suppressHydrationWarning
      >
        {t.playlistDraft.clearButton}
      </Button>
      <Button
        className="flex-1"
        disabled={isAddDisabled}
        onClick={handleAdd}
        suppressHydrationWarning
      >
        {t.playlistDraft.addButton.replace("{count}", songs.length.toString())}
      </Button>
    </div>
  )

  const bodyProps: PlaylistDraftBodyProps = {
    songs,
    playlists,
    selectedPlaylist,
    onSelectPlaylist: setSelectedPlaylist,
    newPlaylistName,
    onNewPlaylistNameChange: setNewPlaylistName,
    onRemove,
    onDragEnd: handleDragEnd
  }

  if (!isMobile) {
    return (
      <Dialog open={isOpen} onOpenChange={onOpenChange}>
        <DialogTrigger asChild>{trigger}</DialogTrigger>
        <DialogContent className="sm:max-w-md flex flex-col max-h-[80vh]">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 font-bold tracking-tight">
              <ListMusic className="h-5 w-5 text-primary" />
              {t.playlistDraft.addToPlaylist}
            </DialogTitle>
            <DialogDescription>
              {songs.length} {t.playlistDraft.songsSelected}
            </DialogDescription>
          </DialogHeader>
          <div className="flex-1 overflow-y-auto py-2">
            <PlaylistDraftBody {...bodyProps} />
          </div>
          <div className="flex flex-col gap-2 pt-4">{actionButtons}</div>
        </DialogContent>
      </Dialog>
    )
  }

  return (
    <Drawer open={isOpen} onOpenChange={onOpenChange} shouldScaleBackground>
      <DrawerTrigger asChild>{trigger}</DrawerTrigger>
      <DrawerContent
        className="flex flex-col mt-0! max-h-dvh! p-0 overflow-hidden"
        id={drawerIds.contentId}
      >
        <DrawerHeader>
          <DrawerTitle className="flex items-center gap-2 font-bold tracking-tight">
            <ListMusic className="h-5 w-5 text-primary" />
            {t.playlistDraft.addToPlaylist}
          </DrawerTitle>
          <DrawerDescription>
            {songs.length} {t.playlistDraft.songsSelected}
          </DrawerDescription>
        </DrawerHeader>
        <DrawerScrollArea className="py-4 px-4">
          <PlaylistDraftBody {...bodyProps} />
        </DrawerScrollArea>
        <DrawerFooter className="flex-col gap-2">{actionButtons}</DrawerFooter>
      </DrawerContent>
    </Drawer>
  )
}
