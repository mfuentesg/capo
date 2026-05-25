"use client"

import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from "react"
import { useUpsertUserPreferences } from "@/features/songs"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  ArrowLeft,
  BookOpen,
  Music2,
  Type,
  Plus,
  Minus,
  Guitar,
  Settings2,
  X,
  Eye,
  Pencil,
  Save,
  Columns2,
  ExternalLink,
  ChevronUp,
  ChevronDown,
  Turtle,
  Rabbit,
  Zap,
  Share2
} from "lucide-react"
import { useRouter } from "next/navigation"
import type { Song } from "@/types"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Separator } from "@/components/ui/separator"
import { useLyricsSettings } from "@/features/lyrics-editor"
import { RenderedSong } from "./rendered-song"
import { LazyChordProReference } from "./chordpro-reference-lazy"
import { LazySongEditor, preloadSongEditor } from "./song-editor"
import { useTranslation } from "@/hooks/use-translation"
import { useAutoSave } from "@/hooks/use-auto-save"
import { useAutoScroll } from "@/hooks/use-auto-scroll"
import { AutoScrollControls } from "./auto-scroll-controls"
import { SaveStatus } from "@/components/ui/save-status"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import { cn } from "@/lib/utils"
import { toast } from "sonner"

const MIN_SCROLL_SPEED = 10
const MAX_SCROLL_SPEED = 300
const SCROLL_SPEED_STEP = 10
const DEFAULT_SCROLL_SPEED = 30
const BEATS_PER_LINE = 4

function buildShareText(lyrics: string, showChords: boolean, showLyrics: boolean): string {
  // Strip all ChordPro directives {…} and normalize blank lines
  const withoutDirectives = lyrics
    .replace(/\{[^}]*\}/g, "")
    .replace(/[ \t]+$/gm, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim()

  if (!showChords) {
    // Lyrics only: strip [chord] markers
    return withoutDirectives.replace(/\[[^\]]*\]/g, "")
  }

  if (!showLyrics) {
    // Chords only: per line, extract chord names; keep plain text lines as-is
    return withoutDirectives
      .split("\n")
      .map((line) => {
        const chords = [...line.matchAll(/\[([^\]]+)\]/g)].map((m) => m[1])
        if (chords.length > 0) return chords.join("  ")
        return line.replace(/\[[^\]]*\]/g, "").trim()
      })
      .join("\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim()
  }

  // Both visible: keep [chord] inline markers (standard ChordPro plain text)
  return withoutDirectives
}

export interface LyricsViewHandle {
  requestClose: () => void
}

interface LyricsViewProps {
  song: Song
  mode?: "page" | "panel"
  readOnly?: boolean
  onClose?: () => void
  onSaveLyrics?: (lyrics: string) => void
  isSaving?: boolean
  initialSettings?: { capo?: number; transpose?: number; fontSize?: number }
  onSettingsChange?: (settings: { capo: number; transpose: number; fontSize: number }) => void
  initialLyricsColumns?: 1 | 2
  onPrevSong?: () => void
  onNextSong?: () => void
  hasPrevSong?: boolean
  hasNextSong?: boolean
  songPosition?: { current: number; total: number }
  slideDirection?: "next" | "prev"
  actionsSlot?: React.ReactNode
}

export const LyricsView = forwardRef<LyricsViewHandle, LyricsViewProps>(function LyricsView(
  {
    song,
    mode = "page",
    readOnly = false,
    onClose,
    onSaveLyrics,
    isSaving = false,
    initialSettings,
    onSettingsChange,
    initialLyricsColumns = 1,
    onPrevSong,
    onNextSong,
    hasPrevSong = false,
    hasNextSong = false,
    songPosition,
    slideDirection,
    actionsSlot
  }: LyricsViewProps,
  ref
) {
  const { t } = useTranslation()
  const router = useRouter()
  const containerRef = useRef<HTMLDivElement>(null)
  const touchStartRef = useRef<{ x: number; y: number } | null>(null)
  const [isEditing, setIsEditing] = useState(false)
  const [isPreviewing, setIsPreviewing] = useState(false)
  const [isReferenceOpen, setIsReferenceOpen] = useState(false)
  const [hasInitializedEditor, setHasInitializedEditor] = useState(false)
  const [editedLyrics, setEditedLyrics] = useState(song.lyrics || "")
  const [savedLyrics, setSavedLyrics] = useState(song.lyrics || "")
  const [editorResetKey, setEditorResetKey] = useState(0)
  const [lyricsColumns, setLyricsColumnsState] = useState<1 | 2>(initialLyricsColumns)
  const [showChords, setShowChords] = useState(true)
  const [showLyrics, setShowLyrics] = useState(true)
  const { mutate: upsertPreferences } = useUpsertUserPreferences()

  const [scrollSpeed, setScrollSpeed] = useState(() =>
    song.bpm > 0 ? song.bpm : DEFAULT_SCROLL_SPEED
  )
  const { isScrolling, stop: stopAutoScroll, toggle: toggleAutoScroll } = useAutoScroll({
    speed: scrollSpeed,
    containerRef
  })

  const setLyricsColumns = useCallback(
    (value: 1 | 2) => {
      setLyricsColumnsState(value)
      upsertPreferences({ lyricsColumns: value })
    },
    [upsertPreferences]
  )

  const handleClose = useCallback(() => {
    if (onClose) {
      onClose()
    } else {
      router.back()
    }
  }, [onClose, router])

  // Auto-save lyrics while editing
  const { status: saveStatus } = useAutoSave(
    editedLyrics,
    async (lyrics) => {
      if (onSaveLyrics) {
        onSaveLyrics(lyrics)
        setSavedLyrics(lyrics)
      }
    },
    { enabled: isEditing && editedLyrics !== savedLyrics }
  )

  useImperativeHandle(ref, () => ({ requestClose: handleClose }), [handleClose])

  const settingsPopoverIds = createOverlayIds(`lyrics-settings-${song.id}`)
  const isPanel = mode === "panel"
  const canEdit = !readOnly

  useEffect(() => {
    preloadSongEditor()
  }, [])

  const { font, transpose, capo, hasModifications } = useLyricsSettings({
    initialFontSize: initialSettings?.fontSize ?? song.fontSize,
    initialTranspose: initialSettings?.transpose ?? song.transpose,
    initialCapo: initialSettings?.capo ?? song.capo,
    onSettingsChange
  })

  const handleEdit = () => {
    if (!canEdit) return
    stopAutoScroll()
    setHasInitializedEditor(true)
    setIsEditing(true)
    setIsPreviewing(false)
    setEditedLyrics(savedLyrics)
    setEditorResetKey((k) => k + 1)
  }

  const handleCancel = useCallback(() => {
    setIsEditing(false)
    setIsPreviewing(false)
    setEditedLyrics(savedLyrics)
    setEditorResetKey((k) => k + 1)
  }, [savedLyrics])

  const handleSave = () => {
    onSaveLyrics?.(editedLyrics)
    setSavedLyrics(editedLyrics)
    setIsEditing(false)
    setIsPreviewing(false)
  }

  const handleLyricsChange = (value: string) => {
    if (!canEdit) return
    setEditedLyrics(value)
  }

  const togglePreview = () => {
    if (!canEdit || !isEditing) return
    setIsPreviewing((prev) => !prev)
  }

  const handleBack = useCallback(() => {
    handleClose()
  }, [handleClose])

  const handleShare = useCallback(async () => {
    const text = buildShareText(savedLyrics, showChords, showLyrics)
    const header = [song.title, song.artist].filter(Boolean).join(" - ")
    const fullText = header ? `${header}\n\n${text}` : text

    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share({ title: song.title, text: fullText })
      } catch (error) {
        if (error instanceof Error && error.name !== "AbortError") {
          toast.error(t.toasts.error)
        }
      }
    } else {
      try {
        await navigator.clipboard.writeText(fullText)
        toast.success(t.toasts.lyricsCopied)
      } catch {
        toast.error(t.toasts.error)
      }
    }
  }, [savedLyrics, showChords, showLyrics, song.title, song.artist, t.toasts])

  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    if (isEditing || (!onPrevSong && !onNextSong)) return
    const touch = e.touches[0]
    touchStartRef.current = { x: touch.clientX, y: touch.clientY }
  }, [isEditing, onPrevSong, onNextSong])

  const handleTouchEnd = useCallback((e: React.TouchEvent) => {
    if (isEditing || !touchStartRef.current || (!onPrevSong && !onNextSong)) return
    const touch = e.changedTouches[0]
    const dx = touch.clientX - touchStartRef.current.x
    const dy = touch.clientY - touchStartRef.current.y
    touchStartRef.current = null
    // Only trigger if horizontal swipe dominates and exceeds threshold
    if (Math.abs(dx) < 60 || Math.abs(dx) < Math.abs(dy)) return
    if (dx < 0 && hasNextSong) onNextSong?.()
    else if (dx > 0 && hasPrevSong) onPrevSong?.()
  }, [isEditing, onPrevSong, onNextSong, hasPrevSong, hasNextSong])

  // Reset scroll position and stop auto-scroll when song changes
  useEffect(() => {
    if (containerRef.current) {
      const scrollContainer = containerRef.current.closest(".overflow-y-auto") || window
      scrollContainer.scrollTo({ top: 0 })
    }
    stopAutoScroll()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [song.id])

  // Infer scroll speed from actual content height, line count, and BPM
  useEffect(() => {
    if (song.bpm <= 0) {
      setScrollSpeed(DEFAULT_SCROLL_SPEED)
      return
    }
    const lines =
      (song.lyrics || "")
        .split("\n")
        .filter((l) => {
          const trimmed = l.trim()
          return trimmed.length > 0 && !trimmed.startsWith("{")
        }).length || 1

    const durationSec = (lines * BEATS_PER_LINE) / (song.bpm / 60)

    let scrollableHeight = 0
    if (containerRef.current) {
      const el = containerRef.current.closest(".overflow-y-auto")
      if (el instanceof HTMLElement) {
        scrollableHeight = el.scrollHeight - el.clientHeight
      }
    }
    if (scrollableHeight <= 0) {
      scrollableHeight = document.documentElement.scrollHeight - window.innerHeight
    }
    if (scrollableHeight <= 0) {
      scrollableHeight = lines * 30
    }

    const inferred = Math.round(scrollableHeight / durationSec)
    setScrollSpeed(Math.min(Math.max(inferred, MIN_SCROLL_SPEED), MAX_SCROLL_SPEED))
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [song.id])

  const settingsPopoverContent = (
    <div className="space-y-4">
      <div className="space-y-2">
        <h4 className="font-medium leading-none">{t.songs.lyrics.displaySettings}</h4>
        <p className="text-sm text-muted-foreground">{t.songs.lyrics.displaySettingsDescription}</p>
      </div>

      <Separator />

      {/* Font Size */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <Type className="h-4 w-4" />
          <span className="text-sm font-medium">{t.songs.lyrics.fontSize}</span>
        </div>
        <div className="flex items-center gap-2">
          <Button onClick={font.decrease} variant="outline" size="sm" disabled={font.isAtMin()}>
            <Minus className="h-4 w-4" />
          </Button>
          <div className="flex items-center gap-2 px-3 py-1.5 bg-muted rounded-md min-w-20 justify-center">
            <Type className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-sm font-medium">{font.value.toFixed(2)}</span>
          </div>
          <Button onClick={font.increase} variant="outline" size="sm" disabled={font.isAtMax()}>
            <Plus className="h-4 w-4" />
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={font.reset}
            disabled={font.isAtDefault()}
            className="text-xs"
          >
            {t.songs.reset}
          </Button>
        </div>
      </div>

      <Separator />

      {/* Transpose */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <Music2 className="h-4 w-4" />
          <span className="text-sm font-medium">{t.songs.transpose}</span>
        </div>
        <div className="flex items-center gap-2">
          <Button
            onClick={transpose.decrease}
            variant="outline"
            size="sm"
            disabled={transpose.isAtMin()}
          >
            <Minus className="h-4 w-4" />
          </Button>
          <div className="flex items-center gap-2 px-3 py-1.5 bg-muted rounded-md min-w-20 justify-center">
            <Music2 className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-sm font-medium">{transpose.display()}</span>
            <span className="text-xs text-muted-foreground">{t.songs.semitones}</span>
          </div>
          <Button
            onClick={transpose.increase}
            variant="outline"
            size="sm"
            disabled={transpose.isAtMax()}
          >
            <Plus className="h-4 w-4" />
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={transpose.reset}
            disabled={transpose.isAtDefault()}
            className="text-xs"
          >
            {t.songs.reset}
          </Button>
        </div>
      </div>

      <Separator />

      {/* Capo */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <Guitar className="h-4 w-4" />
          <span className="text-sm font-medium">{t.songs.capo}</span>
        </div>
        <div className="flex items-center gap-2">
          <Button onClick={capo.decrease} variant="outline" size="sm" disabled={capo.isAtMin()}>
            <Minus className="h-4 w-4" />
          </Button>
          <div className="flex items-center gap-2 px-3 py-1.5 bg-muted rounded-md min-w-20 justify-center">
            <Guitar className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-sm font-medium">{capo.display()}</span>
          </div>
          <Button onClick={capo.increase} variant="outline" size="sm" disabled={capo.isAtMax()}>
            <Plus className="h-4 w-4" />
          </Button>
          <Button
            variant="ghost"
            size="sm"
            onClick={capo.reset}
            disabled={capo.isAtDefault()}
            className="text-xs"
          >
            {t.songs.reset}
          </Button>
        </div>
      </div>

      <Separator />

      {/* Column Layout */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <Columns2 className="h-4 w-4" />
          <span className="text-sm font-medium">{t.songs.lyrics.columnLayout}</span>
        </div>
        <div className="grid grid-cols-2 gap-2">
          <Button
            onClick={() => setLyricsColumns(1)}
            variant={lyricsColumns === 1 ? "default" : "outline"}
            size="sm"
            className="justify-center"
          >
            {t.songs.lyrics.oneColumn}
          </Button>
          <Button
            onClick={() => setLyricsColumns(2)}
            variant={lyricsColumns === 2 ? "default" : "outline"}
            size="sm"
            className="justify-center"
          >
            {t.songs.lyrics.twoColumns}
          </Button>
        </div>
      </div>

      <Separator />

      {/* Visibility */}
      <div className="space-y-2">
        <div className="flex items-center gap-2">
          <Eye className="h-4 w-4" />
          <span className="text-sm font-medium">{t.songs.lyrics.visibility}</span>
        </div>
        <div className="grid grid-cols-2 gap-2">
          <Button
            onClick={() => setShowChords((v) => !v)}
            variant={showChords ? "default" : "outline"}
            size="sm"
            className="justify-center gap-1.5"
          >
            <Guitar className="h-3.5 w-3.5" />
            {t.songs.lyrics.showChordsLabel}
          </Button>
          <Button
            onClick={() => setShowLyrics((v) => !v)}
            variant={showLyrics ? "default" : "outline"}
            size="sm"
            className="justify-center gap-1.5"
          >
            <Type className="h-3.5 w-3.5" />
            {t.songs.lyrics.showLyricsLabel}
          </Button>
        </div>
      </div>
    </div>
  )

  return (
    <div
      ref={containerRef}
      className={cn(
        "bg-background",
        isPanel ? "min-h-full" : "min-h-screen",
        slideDirection === "next" && "animate-in slide-in-from-right-4 fade-in-0 duration-200",
        slideDirection === "prev" && "animate-in slide-in-from-left-4 fade-in-0 duration-200"
      )}
    >
      {/* Header */}
      <div className="sticky top-0 z-10 border-b bg-background">
        <div className={cn("px-4 pt-2 pb-1", !isPanel && "container mx-auto")}>
          {/* Row 1: back button + song title */}
          <div className="flex items-center gap-1.5 min-w-0">
            <Button
              variant="ghost"
              size="icon"
              onClick={handleBack}
              className="h-8 w-8 shrink-0"
              aria-label={t.common.goBack}
            >
              {onClose ? <X className="h-4 w-4" /> : <ArrowLeft className="h-4 w-4" />}
            </Button>
            <p className="text-base font-semibold truncate min-w-0">{song.title}</p>
          </div>

          {/* Row 2: metadata (artist · key · bpm) on left, actions on right */}
          <div className="flex items-center gap-1 mt-0.5 pl-1">
            <div className="flex items-center gap-1.5 min-w-0 flex-1 overflow-hidden">
              {song.artist && (
                <span className="text-xs text-muted-foreground truncate shrink">{song.artist}</span>
              )}
              {song.key && (
                <Badge variant="secondary" className="shrink-0 text-xs">
                  {song.key}
                </Badge>
              )}
              {song.bpm > 0 && (
                <Badge variant="outline" className="shrink-0 text-xs gap-1">
                  {song.bpm < 90 ? (
                    <Turtle className="h-3 w-3" />
                  ) : song.bpm <= 120 ? (
                    <Rabbit className="h-3 w-3" />
                  ) : (
                    <Zap className="h-3 w-3" />
                  )}
                  {song.bpm} {t.songs.bpm}
                </Badge>
              )}
            </div>

            <div className="flex items-center gap-0.5 shrink-0">
              {canEdit && isEditing ? (
                <>
                  <SaveStatus status={saveStatus} className="mr-1" />
                  <Button
                    variant="outline"
                    className="h-9 gap-1.5 px-2.5"
                    onClick={handleCancel}
                    aria-label={t.common.cancel}
                  >
                    <X className="h-4 w-4" />
                    <span className="text-sm">{t.common.cancel}</span>
                  </Button>
                  <Button
                    variant={isPreviewing ? "secondary" : "ghost"}
                    size="icon"
                    className="h-9 w-9"
                    onClick={togglePreview}
                    aria-label={isPreviewing ? t.common.edit : t.songs.preview}
                  >
                    {isPreviewing ? (
                      <Pencil className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </Button>
                  <Button
                    variant="default"
                    size="icon"
                    className="h-9 w-9"
                    onClick={handleSave}
                    disabled={isSaving || saveStatus === "saved"}
                    aria-label={t.common.save}
                  >
                    <Save className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-9 w-9"
                    onClick={() => setIsReferenceOpen(true)}
                    aria-label={t.songs.lyrics.chordproReference}
                  >
                    <BookOpen className="h-4 w-4" />
                  </Button>
                </>
              ) : (
                <>
                  {canEdit && (
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-9 w-9"
                      onClick={handleEdit}
                      aria-label={t.songs.editLyrics}
                    >
                      <Pencil className="h-4 w-4" />
                    </Button>
                  )}
                  {isPanel && (
                    <Button
                      variant="ghost"
                      size="icon"
                      className="hidden sm:flex h-9 w-9"
                      asChild
                      title={t.songs.viewLyrics}
                    >
                      <a
                        href={`/dashboard/songs/${song.id}`}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <ExternalLink className="h-4 w-4" />
                      </a>
                    </Button>
                  )}
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-9 w-9"
                    onClick={handleShare}
                    aria-label={t.songs.shareLyrics}
                  >
                    <Share2 className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-9 w-9"
                    onClick={() => setIsReferenceOpen(true)}
                    aria-label={t.songs.lyrics.chordproReference}
                  >
                    <BookOpen className="h-4 w-4" />
                  </Button>
                  {actionsSlot}
                </>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Lyrics Content */}
      <div
        className={cn("px-4 py-8", !isPanel && "container mx-auto")}
        onTouchStart={handleTouchStart}
        onTouchEnd={handleTouchEnd}
      >
        <div className="w-full">
          <div className="max-w-5xl mx-auto">
            {isEditing && (
              <div className="mb-4">
                <h3 className="text-sm font-medium text-muted-foreground mb-2">
                  {isPreviewing ? t.songs.preview : t.songs.lyricsFormatInfo}
                </h3>
              </div>
            )}

            {(isPreviewing || !isEditing) && (
              <div
                className={cn(
                  isEditing && isPreviewing
                    ? "rounded-lg border bg-card p-4 md:p-6 overflow-hidden"
                    : "block"
                )}
              >
                <RenderedSong
                  lyrics={isEditing && isPreviewing ? editedLyrics : savedLyrics}
                  transpose={transpose.value}
                  capo={capo.value}
                  fontSize={font.value}
                  columns={lyricsColumns}
                  showChords={showChords}
                  showLyrics={showLyrics}
                />
              </div>
            )}

            {canEdit && hasInitializedEditor && (
              <div
                className={cn(
                  "rounded-lg border bg-card",
                  isEditing && !isPreviewing ? "block" : "hidden"
                )}
              >
                <LazySongEditor key={editorResetKey} content={savedLyrics} onChange={handleLyricsChange} />
              </div>
            )}
          </div>
        </div>
      </div>
      {/* Floating controls — song navigation (left) + auto-scroll/settings (right) */}
      {!isEditing && (
        <>
          {/* Song navigation — bottom-left, only when playlist context is active */}
          {(onPrevSong || onNextSong) && (
            <div className="fixed bottom-6 left-4 z-20 flex items-center gap-1 rounded-2xl border bg-background px-2 py-1.5 shadow-lg">
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8"
                onClick={onPrevSong}
                disabled={!hasPrevSong}
                aria-label={t.common.previous}
              >
                <ChevronUp className="h-4 w-4" />
              </Button>
              {songPosition && (
                <span className="min-w-8 text-center text-xs tabular-nums text-muted-foreground">
                  {songPosition.current}/{songPosition.total}
                </span>
              )}
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8"
                onClick={onNextSong}
                disabled={!hasNextSong}
                aria-label={t.common.next}
              >
                <ChevronDown className="h-4 w-4" />
              </Button>
            </div>
          )}

          {/* Auto-scroll + display settings — bottom-right */}
          <div className="fixed bottom-6 right-4 z-20 flex items-center gap-1 rounded-2xl border bg-background px-2 py-1.5 shadow-lg">
          <AutoScrollControls
            isScrolling={isScrolling}
            onToggle={toggleAutoScroll}
            speed={scrollSpeed}
            onIncrease={() =>
              setScrollSpeed((s) => Math.min(s + SCROLL_SPEED_STEP, MAX_SCROLL_SPEED))
            }
            onDecrease={() =>
              setScrollSpeed((s) => Math.max(s - SCROLL_SPEED_STEP, MIN_SCROLL_SPEED))
            }
            isAtMin={scrollSpeed <= MIN_SCROLL_SPEED}
            isAtMax={scrollSpeed >= MAX_SCROLL_SPEED}
          />
          <Separator orientation="vertical" className="mx-0.5 h-4" />
          <Popover>
            <PopoverTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="relative h-8 w-8"
                id={settingsPopoverIds.triggerId}
                aria-controls={settingsPopoverIds.contentId}
                aria-label={t.songs.lyrics.settings}
              >
                <Settings2 className="h-3.5 w-3.5" />
                {(hasModifications() || !showChords || !showLyrics) && (
                  <span className="absolute -top-0.5 -right-0.5 flex h-2 w-2">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-primary"></span>
                  </span>
                )}
              </Button>
            </PopoverTrigger>
            <PopoverContent
              side="top"
              align="end"
              className="w-auto"
              id={settingsPopoverIds.contentId}
              aria-labelledby={settingsPopoverIds.triggerId}
            >
              {settingsPopoverContent}
            </PopoverContent>
          </Popover>
          </div>
        </>
      )}
      <LazyChordProReference open={isReferenceOpen} onOpenChange={setIsReferenceOpen} />
    </div>
  )
})
