"use client"

import { useState } from "react"
import { Calendar as CalendarIcon, ListMusic, X, Sparkles } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Textarea } from "@/components/ui/textarea"
import { Calendar } from "@/components/ui/calendar"
import { Popover, PopoverTrigger, PopoverContent } from "@/components/ui/popover"
import { Label } from "@/components/ui/label"
import { cn, formatLongDate, formatDateISO } from "@/lib/utils"
import { useTranslation } from "@/hooks/use-translation"
import { useLocale } from "@/features/settings"
import type { Playlist } from "@/features/playlists/types"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import type { AppContext } from "@/features/app-context"
import { BucketSelector, useAppContext } from "@/features/app-context"

interface PlaylistCreateFormProps {
  onSubmit: (playlist: Playlist, bucket?: AppContext) => Promise<void>
  onCancel: () => void
  autoFocus?: boolean
  selectedBucket?: AppContext | null
  onBucketChange?: (ctx: AppContext) => void
}

export function PlaylistCreateForm({
  onSubmit,
  onCancel,
  autoFocus = false,
  selectedBucket,
  onBucketChange
}: PlaylistCreateFormProps) {
  const { t } = useTranslation()
  const { locale } = useLocale()
  const { teams, context } = useAppContext()
  const userId = context?.userId ?? ""
  const [name, setName] = useState("")
  const [description, setDescription] = useState("")
  const [date, setDate] = useState<Date | undefined>(undefined)
  const [isCalendarOpen, setIsCalendarOpen] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isSuggesting, setIsSuggesting] = useState(false)

  const suggestPlaylistName = () => {
    const adjectives = [
      "Sunday", "Midnight", "Golden", "Electric", "Acoustic", "Sacred",
      "Morning", "Twilight", "Revival", "Worship", "Vibrant", "Eternal"
    ]
    const nouns = [
      "Setlist", "Sessions", "Worship", "Gathering", "Anthems", "Melodies",
      "Journey", "Voices", "Moments", "Reflections", "Praise", "Songs"
    ]
    const adj = adjectives[Math.floor(Math.random() * adjectives.length)]
    const noun = nouns[Math.floor(Math.random() * nouns.length)]
    setIsSuggesting(true)
    setTimeout(() => {
      setName(`${adj} ${noun}`)
      setIsSuggesting(false)
    }, 400)
  }
  const calendarPopoverIds = createOverlayIds("playlist-create-calendar-popover")

  const canSubmit = name.trim().length > 0 && !isSubmitting

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!canSubmit) return

    setIsSubmitting(true)
    try {
      const playlist: Playlist = {
        id: "",
        name: name.trim(),
        description: description.trim() || undefined,
        date: date ? formatDateISO(date) : undefined,
        songs: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        visibility: "private"
      }
      await onSubmit(playlist, selectedBucket ?? context ?? undefined)
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <div className="flex flex-1 flex-col bg-muted/30">
      <div className="shrink-0 flex items-center justify-between border-b bg-background p-4 lg:p-6">
        <div className="flex items-center gap-2">
          <ListMusic className="h-5 w-5 text-muted-foreground" />
          <h2 className="text-lg font-semibold">{t.playlists.createPlaylist}</h2>
        </div>
        <button
          type="button"
          onClick={onCancel}
          className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors shrink-0"
          aria-label={t.common.close}
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-4 lg:p-6">
        <div className="space-y-4 max-w-md">
          {onBucketChange !== undefined && (
            <BucketSelector
              value={selectedBucket ?? context}
              onChange={onBucketChange}
              userId={userId}
              teams={teams}
              label={t.playlists.bucket}
            />
          )}

          <div className="space-y-2">
            <Label htmlFor="playlist-name">{t.playlists.playlistName}</Label>
            <div className="flex gap-2">
              <div className="relative flex-1">
                <ListMusic className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  id="playlist-name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder={t.playlists.playlistNamePlaceholder}
                  autoFocus={autoFocus}
                  className="pl-9"
                />
              </div>
              <button
                type="button"
                onClick={suggestPlaylistName}
                disabled={isSuggesting}
                title={t.playlists.suggestName}
                aria-label={t.playlists.suggestName}
                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md border border-input bg-background text-muted-foreground transition-colors hover:bg-primary/10 hover:text-primary hover:border-primary/30 disabled:opacity-50"
              >
                <Sparkles className={`h-4 w-4 ${isSuggesting ? "animate-pulse" : ""}`} />
              </button>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="playlist-description">{t.playlistDetail.addDescription}</Label>
            <Textarea
              id="playlist-description"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
            />
          </div>

          <div className="space-y-2">
            <Label>{t.playlistDetail.pickDate}</Label>
            <Popover open={isCalendarOpen} onOpenChange={setIsCalendarOpen}>
              <PopoverTrigger asChild>
                <Button
                  type="button"
                  variant="outline"
                  id={calendarPopoverIds.triggerId}
                  aria-controls={calendarPopoverIds.contentId}
                  className={cn(
                    "w-full justify-start gap-2 font-normal",
                    !date && "text-muted-foreground"
                  )}
                >
                  <CalendarIcon className="h-4 w-4" />
                  {date ? formatLongDate(date, locale) : t.playlistDetail.pickDate}
                </Button>
              </PopoverTrigger>
              <PopoverContent
                className="w-auto p-0"
                align="start"
                id={calendarPopoverIds.contentId}
                aria-labelledby={calendarPopoverIds.triggerId}
              >
                <Calendar
                  mode="single"
                  selected={date}
                  onSelect={(d) => {
                    setDate(d)
                    setIsCalendarOpen(false)
                  }}
                  autoFocus
                />
              </PopoverContent>
            </Popover>
          </div>

          <div className="flex gap-2 pt-4">
            <Button type="submit" disabled={!canSubmit}>
              {isSubmitting ? t.common.loading : t.playlists.createPlaylist}
            </Button>
            <Button type="button" variant="outline" onClick={onCancel} disabled={isSubmitting}>
              {t.common.cancel}
            </Button>
          </div>
        </div>
      </form>
    </div>
  )
}
