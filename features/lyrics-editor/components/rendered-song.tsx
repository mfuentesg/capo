"use client"

import { type ReactNode, useMemo, useState } from "react"
import dynamic from "next/dynamic"
import { ChevronDown, Music2, Repeat2 } from "lucide-react"
import { useLocale } from "@/features/settings"
import { buildSectionMap, buildSegments } from "../utils/lyrics-parser"
import type { LyricsSegment, SectionFlag } from "../utils/lyrics-parser"

const ChordDiagram = dynamic(() => import("./chord-diagram").then((m) => m.ChordDiagram), {
  ssr: false
})

interface RenderedSongProps {
  lyrics?: string
  transpose: number
  capo: number
  fontSize: number
  columns?: 1 | 2
  showChords?: boolean
  showLyrics?: boolean
}

const FLAG_CONFIG: Record<SectionFlag, { label: string; className: string }> = {
  attention: {
    label: "!",
    className: "bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-400"
  },
  skip: { label: "skip", className: "bg-muted text-muted-foreground" },
  forte: {
    label: "f",
    className: "bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-400 italic"
  },
  piano: {
    label: "p",
    className: "bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-400 italic"
  },
  vamp: {
    label: "vamp",
    className: "bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-400"
  },
  tag: {
    label: "tag",
    className: "bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-400"
  },
  break: { label: "break", className: "bg-muted text-muted-foreground" },
  inline: { label: "inline", className: "bg-muted text-muted-foreground" },
  label: { label: "label", className: "bg-muted text-muted-foreground" }
}

interface SectionHeaderProps {
  name: string
  isCollapsed: boolean
  onToggle?: () => void
  icon?: ReactNode
  flags?: SectionFlag[]
}

function SectionHeader({ name, isCollapsed, onToggle, icon, flags }: SectionHeaderProps) {
  const dot = (
    <div
      className="w-1.5 h-1.5 rounded-full shrink-0"
      style={{
        background: "var(--section-accent)",
        boxShadow:
          "0 0 0 2px var(--background), 0 0 0 4px color-mix(in oklch, var(--section-accent) 25%, transparent)"
      }}
    />
  )

  const flagBadges =
    flags && flags.some((f) => f !== "inline" && f !== "label") ? (
      <span className="flex items-center gap-1 shrink-0">
        {flags
          .filter((f) => f !== "inline" && f !== "label")
          .map((flag) => {
            const cfg = FLAG_CONFIG[flag]
            return (
              <span
                key={flag}
                className={`text-[9px] font-bold uppercase tracking-wide px-1 py-0.5 rounded leading-none ${cfg.className}`}
              >
                {cfg.label}
              </span>
            )
          })}
      </span>
    ) : null

  const label = (
    <span className="flex items-center gap-1.5 flex-1 min-w-0">
      <span
        className="text-[12px] font-bold uppercase tracking-[0.18em]"
        style={{ color: "var(--section-accent)" }}
      >
        {name}
      </span>
      {flagBadges}
    </span>
  )

  const chevron = onToggle ? (
    <span className="text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity duration-200">
      <ChevronDown
        className={`section-repeat-chevron w-3.5 h-3.5${isCollapsed ? " is-collapsed" : ""}`}
      />
    </span>
  ) : null

  if (!onToggle) {
    return (
      <div className="flex items-center gap-2.5 mb-3 select-none">
        {icon ?? dot}
        {label}
      </div>
    )
  }

  return (
    <button
      className="flex items-center gap-2.5 mb-3 group cursor-pointer select-none w-full text-left bg-transparent border-0 p-0"
      onClick={onToggle}
      aria-expanded={!isCollapsed}
    >
      {icon ?? dot}
      {label}
      {chevron}
    </button>
  )
}

export function RenderedSong({
  lyrics,
  transpose,
  capo,
  fontSize,
  columns = 2,
  showChords = true,
  showLyrics = true
}: RenderedSongProps) {
  const [collapsedSet, setCollapsedSet] = useState<Set<number>>(new Set())
  const [selectedChord, setSelectedChord] = useState<string | null>(null)

  const { t } = useLocale()

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

  const handleChordClick = (e: React.MouseEvent) => {
    const target = e.target as HTMLElement
    const chordElement = target.closest(".chord")
    if (chordElement) {
      setSelectedChord(chordElement.textContent)
    }
  }

  const toggleCollapse = (index: number) => {
    setCollapsedSet((prev) => {
      const next = new Set(prev)
      if (next.has(index)) {
        next.delete(index)
      } else {
        next.add(index)
      }
      return next
    })
  }

  const segments = useMemo(() => {
    if (!lyrics) return null

    try {
      const sectionMap = buildSectionMap(lyrics)
      return buildSegments(
        lyrics,
        sectionMap,
        transpose,
        capo,
        sectionLabels,
        t.songSections.comment
      )
    } catch (error) {
      console.error("Error parsing ChordPro:", error)
      return null
    }
  }, [lyrics, transpose, capo, sectionLabels, t.songSections.comment])

  if (!lyrics) {
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

  if (segments) {
    const columnStyle = columns === 2 ? { columnCount: 2 as const } : { columnCount: 1 as const }
    const fontStyle = { fontSize: `${fontSize * 14}px`, ...columnStyle }
    const hasComplexSegments = segments.some((s) => s.type === "repeat" || s.type === "section")
    const visibilityClass = [!showChords && "hide-chords", !showLyrics && "hide-lyrics"]
      .filter(Boolean)
      .join(" ")

    if (!hasComplexSegments) {
      return (
        <div className={visibilityClass || undefined} onClick={handleChordClick}>
          <pre
            className="chordsheet-content multi-column-lyrics"
            style={fontStyle}
            dangerouslySetInnerHTML={{ __html: segments[0]?.html ?? "" }}
          />
          <ChordDiagram chordName={selectedChord} onClose={() => setSelectedChord(null)} />
        </div>
      )
    }

    return (
      <div
        className={`multi-column-lyrics space-y-6${visibilityClass ? ` ${visibilityClass}` : ""}`}
        style={fontStyle}
        onClick={handleChordClick}
      >
        {segments.map((segment, index) => {
          if (segment.type === "normal") {
            return (
              <pre
                key={index}
                className="chordsheet-content"
                dangerouslySetInnerHTML={{ __html: segment.html }}
              />
            )
          }

          if (segment.type === "section" && segment.sectionType === "comment") {
            return (
              <div key={index} className="lyrics-comment">
                <div className="lyrics-comment-label">{t.songSections.comment}</div>
                <div className="lyrics-comment-body">{segment.name}</div>
              </div>
            )
          }

          if (segment.type === "section" && segment.sectionType === "comment-label") {
            return <div key={index} className="lyrics-label">{segment.name}</div>
          }

          if (segment.type === "section") {
            const isCollapsed = collapsedSet.has(index)
            const sectionLabel =
              segment.count > 1 ? `${segment.name} × ${segment.count}` : segment.name
            return (
              <div key={index} className="section-repeat" data-section-type={segment.sectionType}>
                <SectionHeader
                  name={sectionLabel}
                  isCollapsed={isCollapsed}
                  onToggle={() => toggleCollapse(index)}
                  flags={segment.flags}
                />
                {!isCollapsed && (
                  <div className="section-repeat-content">
                    <pre
                      className="chordsheet-content"
                      dangerouslySetInnerHTML={{ __html: segment.html }}
                    />
                  </div>
                )}
              </div>
            )
          }

          // repeat segment
          const repeatLabel =
            segment.count > 1 ? `${segment.name} × ${segment.count}` : segment.name

          if (!segment.found) {
            return (
              <div
                key={index}
                className="section-repeat section-repeat--not-found"
                data-section-type="repeat"
              >
                <SectionHeader name={`${repeatLabel} (${t.chords.notFound})`} isCollapsed={false} />
              </div>
            )
          }

          const isCollapsed = collapsedSet.has(index)
          return (
            <div key={index} className="section-repeat" data-section-type={segment.sectionType}>
              <SectionHeader
                name={repeatLabel}
                isCollapsed={isCollapsed}
                onToggle={() => toggleCollapse(index)}
                icon={
                  <Repeat2
                    className="w-3 h-3 shrink-0"
                    style={{ color: "var(--section-accent)" }}
                  />
                }
              />
              {!isCollapsed && (
                <div className="section-repeat-content">
                  <pre
                    className="chordsheet-content"
                    dangerouslySetInnerHTML={{ __html: segment.html }}
                  />
                </div>
              )}
            </div>
          )
        })}
        <ChordDiagram chordName={selectedChord} onClose={() => setSelectedChord(null)} />
      </div>
    )
  }

  return (
    <div
      className="whitespace-pre-wrap leading-relaxed multi-column-lyrics"
      style={{ fontSize: `${fontSize * 14}px`, lineHeight: 1.4, columnCount: columns }}
    >
      {lyrics}
    </div>
  )
}
