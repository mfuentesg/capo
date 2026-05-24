"use client"

import { useMemo, useState, useRef, useCallback } from "react"
import dynamic from "next/dynamic"
import { ChevronLeft, ChevronRight, Music2, Repeat2 } from "lucide-react"
import { useLocale } from "@/features/settings"
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

function segmentLabel(segment: LyricsSegment): string {
  if (segment.type === "normal") return "…"
  const name = segment.type === "section" || segment.type === "repeat" ? segment.name : ""
  return segment.count > 1 ? `${name} × ${segment.count}` : name
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
  const prevSlide = safeIndex > 0 ? slides[safeIndex - 1] : undefined
  const nextSlide = safeIndex < slides.length - 1 ? slides[safeIndex + 1] : undefined

  const goNext = useCallback(
    () => setCurrentIndex((i) => Math.min(i + 1, slides.length - 1)),
    [slides.length]
  )
  const goPrev = useCallback(() => setCurrentIndex((i) => Math.max(i - 1, 0)), [])

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

  const title = currentSlide ? segmentLabel(currentSlide) : ""
  const sectionType =
    currentSlide && currentSlide.type !== "normal" ? currentSlide.sectionType : undefined
  const isRepeat = currentSlide?.type === "repeat"
  const showDots = slides.length <= 8

  return (
    <div className="flex flex-col">
      {/* Section header */}
      <div
        className={cn(
          "flex items-center gap-2 px-4 py-3 border-b min-h-[3rem]",
          sectionType && "section-repeat"
        )}
        {...(sectionType ? { "data-section-type": sectionType } : {})}
      >
        <div className="flex items-center gap-2 flex-1 min-w-0">
          {title && title !== "…" ? (
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

      {/* Slide content */}
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

      {/* Navigation — large tap targets with adjacent section names */}
      <div className="flex items-stretch border-t min-h-[3.5rem]">
        <button
          onClick={goPrev}
          disabled={!prevSlide}
          aria-label={t.common.previous}
          className="flex flex-1 items-center gap-1.5 px-3 py-3 text-left disabled:opacity-25 active:bg-muted"
        >
          <ChevronLeft className="h-4 w-4 shrink-0 text-muted-foreground" />
          <span className="text-xs text-muted-foreground truncate">
            {prevSlide ? segmentLabel(prevSlide) : ""}
          </span>
        </button>

        {/* Dots / position indicator */}
        {showDots ? (
          <div className="flex items-center gap-1.5 px-2 shrink-0">
            {slides.map((_, i) => (
              <button
                key={i}
                onClick={() => setCurrentIndex(i)}
                className="w-1.5 h-1.5 rounded-full shrink-0"
                style={{
                  background: i === safeIndex ? "var(--foreground)" : "var(--muted-foreground)",
                  opacity: i === safeIndex ? 1 : 0.3
                }}
              />
            ))}
          </div>
        ) : (
          <div className="flex items-center px-2 shrink-0">
            <span className="text-xs tabular-nums text-muted-foreground">
              {safeIndex + 1} / {slides.length}
            </span>
          </div>
        )}

        <button
          onClick={goNext}
          disabled={!nextSlide}
          aria-label={t.common.next}
          className="flex flex-1 items-center justify-end gap-1.5 px-3 py-3 text-right disabled:opacity-25 active:bg-muted"
        >
          <span className="text-xs text-muted-foreground truncate">
            {nextSlide ? segmentLabel(nextSlide) : ""}
          </span>
          <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" />
        </button>
      </div>

      <ChordDiagram chordName={selectedChord} onClose={() => setSelectedChord(null)} />
    </div>
  )
}
