"use client"

import { useMemo, useState, useRef, useCallback } from "react"
import dynamic from "next/dynamic"
import { ChevronLeft, ChevronRight, Music2, Repeat2 } from "lucide-react"
import { useLocale } from "@/features/settings"
import { Button } from "@/components/ui/button"
import { buildSectionMap, buildSegments } from "../utils/lyrics-parser"
import type { LyricsSegment } from "../utils/lyrics-parser"
import { cn } from "@/lib/utils"

const ChordDiagram = dynamic(() => import("./chord-diagram").then((m) => m.ChordDiagram), {
  ssr: false
})

interface SectionSlideViewProps {
  lyrics?: string
  transpose: number
  capo: number
  fontSize: number
  showChords?: boolean
  showLyrics?: boolean
}

function slideTitle(segment: LyricsSegment, t: { songSections: Record<string, string> }): string {
  if (segment.type === "normal") return ""
  if (segment.type === "section" || segment.type === "repeat") {
    const label =
      segment.count > 1 ? `${segment.name} × ${segment.count}` : segment.name
    return label
  }
  return ""
}

export function SectionSlideView({
  lyrics,
  transpose,
  capo,
  fontSize,
  showChords = true,
  showLyrics = true
}: SectionSlideViewProps) {
  const { t } = useLocale()
  const [currentIndex, setCurrentIndex] = useState(0)
  const [selectedChord, setSelectedChord] = useState<string | null>(null)
  const touchStartRef = useRef<{ x: number; y: number } | null>(null)

  const sectionLabels = useMemo(
    () => ({
      chorus: t.songSections.chorus,
      verse: t.songSections.verse,
      bridge: t.songSections.bridge,
      tab: t.songSections.tab,
      grid: t.songSections.grid,
      intro: t.songSections.intro,
      outro: t.songSections.outro,
      pre_chorus: t.songSections.pre_chorus
    }),
    [t]
  )

  const slides = useMemo(() => {
    if (!lyrics) return []
    try {
      const sectionMap = buildSectionMap(lyrics)
      const segments = buildSegments(
        lyrics,
        sectionMap,
        transpose,
        capo,
        sectionLabels,
        t.songSections.comment
      )
      // Keep sections/repeats always; keep normals only if they have content
      return segments.filter((s) => s.type !== "normal" || s.html.trim().length > 0)
    } catch {
      return []
    }
  }, [lyrics, transpose, capo, sectionLabels, t.songSections.comment])

  // Reset to first slide when lyrics or transposition changes
  const prevLyrics = useRef(lyrics)
  const prevTranspose = useRef(transpose)
  const prevCapo = useRef(capo)
  if (
    prevLyrics.current !== lyrics ||
    prevTranspose.current !== transpose ||
    prevCapo.current !== capo
  ) {
    prevLyrics.current = lyrics
    prevTranspose.current = transpose
    prevCapo.current = capo
    if (currentIndex >= slides.length) setCurrentIndex(0)
  }

  const safeIndex = Math.min(currentIndex, Math.max(0, slides.length - 1))
  const currentSlide = slides[safeIndex]

  const goNext = useCallback(
    () => setCurrentIndex((i) => Math.min(i + 1, slides.length - 1)),
    [slides.length]
  )
  const goPrev = useCallback(() => setCurrentIndex((i) => Math.max(i - 1, 0)), [])

  const handleTouchStart = useCallback((e: React.TouchEvent) => {
    const touch = e.touches[0]
    touchStartRef.current = { x: touch.clientX, y: touch.clientY }
  }, [])

  const handleTouchEnd = useCallback(
    (e: React.TouchEvent) => {
      if (!touchStartRef.current) return
      const touch = e.changedTouches[0]
      const dx = touch.clientX - touchStartRef.current.x
      const dy = touch.clientY - touchStartRef.current.y
      touchStartRef.current = null
      if (Math.abs(dx) < 50 || Math.abs(dx) < Math.abs(dy)) return
      if (dx < 0) goNext()
      else goPrev()
    },
    [goNext, goPrev]
  )

  const handleChordClick = useCallback((e: React.MouseEvent) => {
    const target = e.target as HTMLElement
    const chordEl = target.closest(".chord")
    if (chordEl) setSelectedChord(chordEl.textContent)
  }, [])

  if (!lyrics || slides.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-muted mb-4">
          <Music2 className="h-8 w-8 text-muted-foreground" />
        </div>
        <p className="text-lg font-medium">{t.songs.noLyrics}</p>
        <p className="text-sm text-muted-foreground mt-2">{t.songs.addLyricsDescription}</p>
      </div>
    )
  }

  const visibilityClass = [!showChords && "hide-chords", !showLyrics && "hide-lyrics"]
    .filter(Boolean)
    .join(" ")

  const title = currentSlide ? slideTitle(currentSlide, t) : ""
  const sectionType =
    currentSlide && currentSlide.type !== "normal" ? currentSlide.sectionType : undefined
  const isRepeat = currentSlide?.type === "repeat"
  const showDots = slides.length <= 10

  return (
    <div
      className="flex flex-col"
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
    >
      {/* Section header bar */}
      <div
        className={cn(
          "flex items-center gap-2 px-4 py-3 border-b min-h-[3rem]",
          sectionType && "section-repeat"
        )}
        {...(sectionType ? { "data-section-type": sectionType } : {})}
      >
        <div className="flex items-center gap-2 flex-1 min-w-0">
          {title ? (
            <>
              {isRepeat ? (
                <Repeat2 className="w-3.5 h-3.5 shrink-0" style={{ color: "var(--section-accent)" }} />
              ) : (
                <div
                  className="w-2 h-2 rounded-full shrink-0"
                  style={{
                    background: "var(--section-accent)",
                    boxShadow:
                      "0 0 0 2px var(--background), 0 0 0 4px color-mix(in oklch, var(--section-accent) 25%, transparent)"
                  }}
                />
              )}
              <span
                className="text-sm font-bold uppercase tracking-[0.18em] truncate"
                style={{ color: "var(--section-accent)" }}
              >
                {title}
              </span>
            </>
          ) : (
            <span className="text-sm text-muted-foreground">&mdash;</span>
          )}
        </div>
        <span className="text-xs tabular-nums text-muted-foreground shrink-0">
          {safeIndex + 1} / {slides.length}
        </span>
      </div>

      {/* Slide content — scrollable */}
      <div
        className="flex-1 overflow-y-auto px-4 py-6"
        onClick={handleChordClick}
        data-vaul-no-drag
      >
        {currentSlide && (
          <div className={visibilityClass || undefined}>
            <pre
              className="chordsheet-content"
              style={{ fontSize: `${fontSize * 14}px` }}
              dangerouslySetInnerHTML={{ __html: currentSlide.html }}
            />
          </div>
        )}
      </div>

      {/* Navigation bar */}
      <div className="flex items-center justify-between gap-2 px-2 py-2 border-t">
        <Button
          variant="ghost"
          size="icon"
          className="h-9 w-9 shrink-0"
          onClick={goPrev}
          disabled={safeIndex === 0}
          aria-label={t.common.previous}
        >
          <ChevronLeft className="h-4 w-4" />
        </Button>

        {/* Dots or segment list */}
        <div className="flex items-center gap-1.5 min-w-0 flex-wrap justify-center">
          {showDots
            ? slides.map((_, i) => (
                <button
                  key={i}
                  onClick={() => setCurrentIndex(i)}
                  aria-label={`${t.songs.lyrics.sectionView} ${i + 1}`}
                  className="w-2 h-2 rounded-full shrink-0"
                  style={{
                    background: i === safeIndex ? "var(--foreground)" : "var(--muted-foreground)",
                    opacity: i === safeIndex ? 1 : 0.3
                  }}
                />
              ))
            : slides.map((slide, i) => {
                const label =
                  slide.type === "normal" ? "…" : slide.name.slice(0, 4)
                return (
                  <button
                    key={i}
                    onClick={() => setCurrentIndex(i)}
                    className={`text-[10px] font-medium px-1.5 py-0.5 rounded shrink-0 ${
                      i === safeIndex
                        ? "bg-foreground text-background"
                        : "text-muted-foreground hover:text-foreground"
                    }`}
                  >
                    {label}
                  </button>
                )
              })}
        </div>

        <Button
          variant="ghost"
          size="icon"
          className="h-9 w-9 shrink-0"
          onClick={goNext}
          disabled={safeIndex === slides.length - 1}
          aria-label={t.common.next}
        >
          <ChevronRight className="h-4 w-4" />
        </Button>
      </div>

      <ChordDiagram chordName={selectedChord} onClose={() => setSelectedChord(null)} />
    </div>
  )
}
