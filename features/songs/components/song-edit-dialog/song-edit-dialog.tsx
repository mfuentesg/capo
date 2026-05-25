"use client"

import { useState, useEffect } from "react"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { KeySelect } from "@/features/songs/components/key-select"
import { useTranslation } from "@/hooks/use-translation"
import type { Song } from "@/features/songs/types"

interface SongEditDialogProps {
  song: Song
  open: boolean
  onOpenChange: (open: boolean) => void
  onUpdate: (songId: string, updates: Partial<Song>) => void
}

export function SongEditDialog({ song, open, onOpenChange, onUpdate }: SongEditDialogProps) {
  const { t } = useTranslation()
  const [title, setTitle] = useState(song.title)
  const [artist, setArtist] = useState(song.artist)
  const [key, setKey] = useState(song.key)
  const [bpmDraft, setBpmDraft] = useState(String(song.bpm ?? 0))

  useEffect(() => {
    if (open) {
      setTitle(song.title)
      setArtist(song.artist)
      setKey(song.key)
      setBpmDraft(String(song.bpm ?? 0))
    }
  }, [open, song])

  const handleSave = () => {
    const parsedBpm = Number.parseInt(bpmDraft, 10)
    const bpm = Number.isNaN(parsedBpm) ? song.bpm : Math.max(20, Math.min(parsedBpm, 500))
    onUpdate(song.id, {
      title: title.trim() || song.title,
      artist: artist.trim(),
      key,
      bpm
    })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t.songs.editDetails}</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-1.5">
            <Label htmlFor="song-edit-title">{t.songs.songTitle}</Label>
            <Input
              id="song-edit-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder={t.songs.songTitlePlaceholder}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="song-edit-artist">{t.songs.artist}</Label>
            <Input
              id="song-edit-artist"
              value={artist}
              onChange={(e) => setArtist(e.target.value)}
              placeholder={t.songs.artistPlaceholder}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>{t.songs.key}</Label>
              <KeySelect value={key} onValueChange={setKey} className="w-full" />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="song-edit-bpm">{t.songs.bpm}</Label>
              <Input
                id="song-edit-bpm"
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                value={bpmDraft}
                onChange={(e) => {
                  if (/^\d*$/.test(e.target.value)) setBpmDraft(e.target.value)
                }}
              />
            </div>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t.common.cancel}
          </Button>
          <Button onClick={handleSave}>{t.common.save}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
