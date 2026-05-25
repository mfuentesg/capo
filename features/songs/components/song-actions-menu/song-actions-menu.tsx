"use client"

import { useState } from "react"
import { MoreVertical, Pencil, ArrowRightFromLine, Trash2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle
} from "@/components/ui/alert-dialog"
import { useTranslation } from "@/hooks/use-translation"
import { useTeams } from "@/features/teams"
import { useDeleteSong } from "@/features/songs"
import { SongEditDialog } from "../song-edit-dialog"
import { TransferToTeamDialog } from "../transfer-to-team-dialog"
import type { Song } from "@/features/songs/types"

interface SongActionsMenuProps {
  song: Song
  onUpdate: (songId: string, updates: Partial<Song>) => void
  onDelete: (songId: string) => void
  onTransferSuccess: () => void
}

export function SongActionsMenu({ song, onUpdate, onDelete, onTransferSuccess }: SongActionsMenuProps) {
  const { t } = useTranslation()
  const { data: teams = [] } = useTeams()
  const deleteSongMutation = useDeleteSong()
  const canTransfer = song.ownership?.type === "personal" && teams.length > 0

  const [isEditOpen, setIsEditOpen] = useState(false)
  const [isTransferOpen, setIsTransferOpen] = useState(false)
  const [isDeleteOpen, setIsDeleteOpen] = useState(false)

  const handleConfirmDelete = () => {
    deleteSongMutation.mutate(song.id, {
      onSuccess: () => onDelete(song.id)
    })
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon" className="h-9 w-9" aria-label={t.common.more}>
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => setIsEditOpen(true)}>
            <Pencil className="mr-2 h-4 w-4" />
            {t.songs.editDetails}
          </DropdownMenuItem>
          {canTransfer && (
            <DropdownMenuItem onClick={() => setIsTransferOpen(true)}>
              <ArrowRightFromLine className="mr-2 h-4 w-4" />
              {t.songs.transferToTeam}
            </DropdownMenuItem>
          )}
          <DropdownMenuSeparator />
          <DropdownMenuItem
            className="text-destructive focus:text-destructive"
            onClick={() => setIsDeleteOpen(true)}
          >
            <Trash2 className="mr-2 h-4 w-4" />
            {t.songs.deleteSong}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <SongEditDialog
        song={song}
        open={isEditOpen}
        onOpenChange={setIsEditOpen}
        onUpdate={onUpdate}
      />

      {canTransfer && (
        <TransferToTeamDialog
          song={song}
          open={isTransferOpen}
          onOpenChange={setIsTransferOpen}
          onSuccess={onTransferSuccess}
        />
      )}

      <AlertDialog open={isDeleteOpen} onOpenChange={setIsDeleteOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t.songs.deleteSongConfirmTitle}</AlertDialogTitle>
            <AlertDialogDescription>
              {t.songs.deleteSongConfirmDescription.replace("{title}", song.title)}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
            <AlertDialogAction variant="destructive" onClick={handleConfirmDelete}>
              {t.songs.deleteSong}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
