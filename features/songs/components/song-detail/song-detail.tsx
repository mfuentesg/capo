"use client"
import { useState, useRef, useEffect } from "react"
import {
  X,
  Clock,
  Trash2,
  Check,
  Pencil,
  Music2,
  Guitar,
  Minus,
  Plus,
  ExternalLink,
  ArrowRightFromLine
} from "lucide-react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger
} from "@/components/ui/alert-dialog"
import { cn } from "@/lib/utils"
import type { Song } from "@/features/songs/types"
import { KeySelect } from "@/features/songs"
import {
  useEffectiveSongSettings,
  useUpsertUserSongSettings
} from "@/features/songs/hooks/use-user-song-settings"
import { useTeams } from "@/features/teams"
import { useAppContext } from "@/features/app-context"
import { transposeKey, calculateCapoKey } from "@/lib/music-theory"
import { useTranslation } from "@/hooks/use-translation"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import { TransferToTeamDialog } from "../transfer-to-team-dialog"

interface EditableFieldProps {
  value: string
  onSave: (value: string) => void
  className?: string
  inputClassName?: string
}

function EditableField({ value, onSave, className, inputClassName }: EditableFieldProps) {
  const [isEditing, setIsEditing] = useState(false)
  const [editValue, setEditValue] = useState(value)
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus()
      inputRef.current.select()
    }
  }, [isEditing])

  const handleSave = () => {
    if (editValue.trim() && editValue !== value) {
      onSave(editValue.trim())
    } else {
      setEditValue(value)
    }
    setIsEditing(false)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      handleSave()
    } else if (e.key === "Escape") {
      setEditValue(value)
      setIsEditing(false)
    }
  }

  if (isEditing) {
    return (
      <div className="flex items-center gap-1.5">
        <Input
          ref={inputRef}
          value={editValue}
          onChange={(e) => setEditValue(e.target.value)}
          onKeyDown={handleKeyDown}
          onBlur={handleSave}
          className={cn("h-8 px-2", inputClassName)}
        />
        <Button
          size="icon"
          variant="ghost"
          className="h-8 w-8 shrink-0"
          onClick={handleSave}
          aria-label="Save"
        >
          <Check className="h-4 w-4 text-green-600" />
        </Button>
      </div>
    )
  }

  return (
    <button
      onClick={() => setIsEditing(true)}
      className={cn(
        "group inline-flex min-w-0 items-center gap-1.5 rounded px-1 -ml-1 hover:bg-muted transition-colors text-left",
        className
      )}
    >
      <span className="truncate">{value}</span>
      <Pencil className="h-3 w-3 opacity-0 group-hover:opacity-50 transition-opacity shrink-0" />
    </button>
  )
}

interface SongDetailProps {
  song: Song
  onClose: () => void
  onUpdate: (songId: string, updates: Partial<Song>) => void
  onDelete: (songId: string) => void
  onTransferSuccess: () => void
}

export function SongDetail({ song, onClose, onUpdate, onDelete, onTransferSuccess }: SongDetailProps) {
  const { t } = useTranslation()
  const { transpose, capo: capoPosition } = useEffectiveSongSettings(song)
  const { mutate: upsertSettings } = useUpsertUserSongSettings(song)
  const deleteDialogIds = createOverlayIds(`song-detail-delete-${song.id}`)
  const [bpmDraftBySongId, setBpmDraftBySongId] = useState<Record<string, string>>({})
  const [isTransferDialogOpen, setIsTransferDialogOpen] = useState(false)
  const { context } = useAppContext()
  const { data: teams = [] } = useTeams()
  const canTransfer = context?.type === "personal" && teams.length > 0
  const bpmDraft = bpmDraftBySongId[song.id]
  const bpmInputValue = bpmDraft ?? String(song.bpm ?? 0)

  const updateTranspose = (nextValue: number) => {
    const clampedValue = Math.max(-6, Math.min(nextValue, 6))
    if (clampedValue === transpose) return
    upsertSettings({ transpose: clampedValue })
  }

  const updateCapoPosition = (nextValue: number) => {
    const clampedValue = Math.max(0, Math.min(nextValue, 12))
    if (clampedValue === capoPosition) return
    upsertSettings({ capo: clampedValue })
  }

  const setBpmDraft = (nextValue: string) => {
    setBpmDraftBySongId((prev) => ({ ...prev, [song.id]: nextValue }))
  }

  const clearBpmDraft = () => {
    setBpmDraftBySongId((prev) => {
      if (!(song.id in prev)) return prev
      const next = { ...prev }
      delete next[song.id]
      return next
    })
  }

  const commitBpmUpdate = () => {
    if (bpmDraft === undefined) return

    const parsedValue = Number.parseInt(bpmDraft, 10)
    if (Number.isNaN(parsedValue)) {
      clearBpmDraft()
      return
    }

    const clampedValue = Math.max(20, Math.min(parsedValue, 500))
    clearBpmDraft()
    if (clampedValue === song.bpm) return
    onUpdate(song.id, { bpm: clampedValue })
  }

  return (
    <div className="flex flex-1 flex-col bg-muted/30 border-t-2 border-accent-songs">
      <div className="shrink-0 flex items-center justify-between border-b bg-background p-4 lg:p-6">
        <div className="flex items-center gap-3 min-w-0">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 min-w-0">
              <EditableField
                value={song.title}
                onSave={(value) => onUpdate(song.id, { title: value })}
                className="text-lg font-bold tracking-tight"
                inputClassName="text-lg font-bold"
              />
            </div>
            <EditableField
              value={song.artist}
              onSave={(value) => onUpdate(song.id, { artist: value })}
              className="text-sm text-muted-foreground"
              inputClassName="text-sm"
            />
          </div>
        </div>
        <div className="flex items-center gap-1 shrink-0">
          <Button variant="ghost" size="icon" onClick={onClose} aria-label={t.common.close}>
            <X className="h-4 w-4" />
          </Button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 lg:p-6">
        <div className="max-w-2xl space-y-6">
          <div className="flex flex-wrap gap-3">
            <div className="flex items-center gap-2 rounded-full bg-background border px-3 py-1.5">
              <span className="text-xs text-muted-foreground">{t.songs.key}</span>
              <KeySelect
                value={song.key}
                onValueChange={(value) => onUpdate(song.id, { key: value })}
                className="h-auto border-0 p-0 font-medium text-sm w-auto gap-1"
              />
            </div>
            <div className="flex items-center gap-2 rounded-full bg-background border px-3 py-1.5">
              <Clock className="h-3.5 w-3.5 text-muted-foreground" />
              <Input
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                min={20}
                max={500}
                value={bpmInputValue}
                onChange={(e) => {
                  const nextValue = e.target.value
                  if (/^\d*$/.test(nextValue)) {
                    setBpmDraft(nextValue)
                  }
                }}
                onBlur={commitBpmUpdate}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault()
                    e.currentTarget.blur()
                    return
                  }

                  if (e.key === "Escape") {
                    e.preventDefault()
                    clearBpmDraft()
                  }
                }}
                className="h-auto border-0 p-0 font-medium text-sm tabular-nums w-14 text-center [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
              />
              <span className="text-xs text-muted-foreground">{t.songs.bpm}</span>
            </div>
          </div>

          {/* Transpose + Capo — grouped in a card */}
          <div className="rounded-xl border bg-card shadow-sm p-4 space-y-5">
            {/* Transpose */}
            <div className="space-y-3">
              <div className="flex items-center gap-1.5">
                <Music2 className="h-3.5 w-3.5 text-muted-foreground" />
                <span className="text-xs font-bold uppercase tracking-widest text-muted-foreground">
                  {t.songs.transpose}
                </span>
              </div>
              <div className="flex items-center gap-3">
                <Button
                  variant="outline"
                  size="icon"
                  onClick={() => updateTranspose(transpose - 1)}
                  disabled={transpose <= -6}
                  className="h-9 w-9 rounded-full"
                >
                  <Minus className="h-3.5 w-3.5" />
                </Button>
                <div className="flex items-center gap-2 rounded-lg bg-background border px-4 py-2 min-w-20 justify-center">
                  <span className="text-sm font-medium tabular-nums">
                    {transpose > 0 ? `+${transpose}` : transpose}
                  </span>
                  <span className="text-xs text-muted-foreground">{t.songs.semitones}</span>
                </div>
                <Button
                  variant="outline"
                  size="icon"
                  onClick={() => updateTranspose(transpose + 1)}
                  disabled={transpose >= 6}
                  className="h-9 w-9 rounded-full"
                >
                  <Plus className="h-3.5 w-3.5" />
                </Button>
                {transpose !== 0 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => updateTranspose(0)}
                    className="text-xs h-8"
                  >
                    {t.songs.reset}
                  </Button>
                )}
              </div>
              <p className="text-xs text-muted-foreground">
                {t.songs.originalKey}: <span className="font-medium">{song.key}</span>
                {transpose !== 0 && (
                  <>
                    {" → "}
                    {t.songs.transposed}:{" "}
                    <span className="font-medium">{transposeKey(song.key, transpose)}</span>
                  </>
                )}
              </p>
            </div>

            <div className="border-t" />

            {/* Capo */}
            <div className="space-y-3">
              <div className="flex items-center gap-1.5">
                <Guitar className="h-3.5 w-3.5 text-muted-foreground" />
                <span className="text-xs font-bold uppercase tracking-widest text-muted-foreground">
                  {t.songs.capo}
                </span>
              </div>
              <div className="flex items-center gap-3">
                <Button
                  variant="outline"
                  size="icon"
                  onClick={() => updateCapoPosition(capoPosition - 1)}
                  disabled={capoPosition <= 0}
                  className="h-9 w-9 rounded-full"
                >
                  <Minus className="h-3.5 w-3.5" />
                </Button>
                <div className="flex items-center gap-2 rounded-lg bg-background border px-4 py-2 min-w-30 justify-center">
                  <span className="text-sm font-medium tabular-nums">
                    {capoPosition === 0 ? t.songs.noCapo : `${t.songs.fret} ${capoPosition}`}
                  </span>
                </div>
                <Button
                  variant="outline"
                  size="icon"
                  onClick={() => updateCapoPosition(capoPosition + 1)}
                  disabled={capoPosition >= 12}
                  className="h-9 w-9 rounded-full"
                >
                  <Plus className="h-3.5 w-3.5" />
                </Button>
                {capoPosition !== 0 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => updateCapoPosition(0)}
                    className="text-xs h-8"
                  >
                    {t.songs.reset}
                  </Button>
                )}
              </div>
              {capoPosition > 0 && (
                <p className="text-xs text-muted-foreground">
                  {t.songs.playIn}:{" "}
                  <span className="font-medium">{calculateCapoKey(song.key, capoPosition)}</span>
                  {" ("}
                  {t.songs.capo} {capoPosition}
                  {" = "}
                  <span className="font-medium">{song.key}</span> {t.songs.key.toLowerCase()}
                  {")"}
                </p>
              )}
            </div>
          </div>

          <div className="flex flex-wrap gap-2 pt-2">
            <Button variant="outline" className="gap-2 transition active:scale-[0.98]" asChild>
              <Link href={`/dashboard/songs/${song.id}`}>
                <ExternalLink className="h-4 w-4" />
                {t.songs.viewLyrics}
              </Link>
            </Button>
            {canTransfer && (
              <Button
                variant="outline"
                className="gap-2 transition active:scale-[0.98]"
                onClick={() => setIsTransferDialogOpen(true)}
              >
                <ArrowRightFromLine className="h-4 w-4" />
                {t.songs.transferToTeam}
              </Button>
            )}
          </div>
          {canTransfer && (
            <TransferToTeamDialog
              song={song}
              open={isTransferDialogOpen}
              onOpenChange={setIsTransferDialogOpen}
              onSuccess={onTransferSuccess}
            />
          )}

          {/* Danger Zone */}
          <div className="rounded-2xl border border-destructive/30 bg-destructive/[0.02] p-4">
            <h3 className="text-sm font-bold text-destructive mb-3">{t.songs.dangerZone}</h3>
            <div className="flex items-center justify-between gap-4">
              <div className="space-y-0.5">
                <p className="text-sm font-medium">{t.songs.deleteSong}</p>
                <p className="text-xs text-muted-foreground">{t.songs.deleteSongDescription}</p>
              </div>
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button
                    variant="destructive"
                    size="sm"
                    className="shrink-0 gap-1.5 transition active:scale-[0.98]"
                    id={deleteDialogIds.triggerId}
                    aria-controls={deleteDialogIds.contentId}
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                    {t.songs.deleteSong}
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent id={deleteDialogIds.contentId}>
                  <AlertDialogHeader>
                    <AlertDialogTitle>{t.songs.deleteSongConfirmTitle}</AlertDialogTitle>
                    <AlertDialogDescription>
                      {t.songs.deleteSongConfirmDescription.replace("{title}", song.title)}
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
                    <AlertDialogAction variant="destructive" onClick={() => onDelete(song.id)}>
                      {t.songs.deleteSong}
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
