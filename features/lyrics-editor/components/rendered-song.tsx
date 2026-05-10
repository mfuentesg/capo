"use client"

import { type ReactNode, useMemo, useState } from "react"
import dynamic from "next/dynamic"
import { ChordProParser } from "chordsheetjs"
import { ChevronDown, Music2, Repeat2 } from "lucide-react"
import { useLocale } from "@/features/settings"

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

const SECTION_FLAGS = [
  "attention",
  "skip",
  "forte",
  "piano",
  "vamp",
  "tag",
  "break",
  "inline"
] as const
type SectionFlag = (typeof SECTION_FLAGS)[number]

type LyricsSegment =
  | { type: "normal"; html: string }
  | {
      type: "section"
      name: string
      sectionType: string
      html: string
      count: number
      flags: SectionFlag[]
      inline: boolean
    }
  | { type: "repeat"; name: string; count: number; html: string; found: boolean }

// Unique tokens that survive ChordProParser unchanged (no [A-G] at word start).
const COMMENT_TOKEN = "SECTIONLBL"
const SECTION_START_TOKEN = "SECTSTART"
const PERF_NOTE_TOKEN = "PERFORMNOTE"

// Regex that matches {start_of_volta: label}...{end_of_volta} (and shorthand sovt/eovt).
// Lazy [\s\S]*? prevents over-matching across multiple volta blocks.
const VOLTA_SPLIT_RE =
  /\{(?:start_of_volta|sovt)(?::\s*([^}]*))?\}([\s\S]*?)\{(?:end_of_volta|eovt)\}/gi

// Regex that matches {start_of_box: label}...{end_of_box} (and shorthand sbox/ebox).
const BOX_SPLIT_RE =
  /\{(?:start_of_box|sbox)(?::\s*([^}]*))?\}([\s\S]*?)\{(?:end_of_box|ebox)\}/gi

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

const SECTION_DIRECTIVE_MAP: Record<string, string> = {
  start_of_chorus: "chorus",
  soc: "chorus",
  start_of_verse: "verse",
  sov: "verse",
  start_of_bridge: "bridge",
  sob: "bridge",
  start_of_tab: "tab",
  sot: "tab",
  start_of_grid: "grid",
  sog: "grid",
  start_of_intro: "intro",
  soi: "intro",
  start_of_outro: "outro",
  soo: "outro",
  start_of_pre_chorus: "pre_chorus",
  sopc: "pre_chorus"
}

const SECTION_END_RE =
  /\{(?:end_of_chorus|eoc|end_of_verse|eov|end_of_bridge|eob|end_of_tab|eot|end_of_grid|eog|end_of_intro|eoi|end_of_outro|eoo|end_of_pre_chorus|eopc)\}/gi

const SECTION_START_RE =
  /\{(start_of_chorus|soc|start_of_verse|sov|start_of_bridge|sob|start_of_tab|sot|start_of_grid|sog|start_of_intro|soi|start_of_outro|soo|start_of_pre_chorus|sopc)(?::\s*([^}]+))?\}/gi

// Processes a plain ChordPro text block (no volta markers) through the parser
// and returns an HTML string. Handles {comment}, {note}, and section-start tokens.
// inline=true uses the side-by-side chord/lyric layout instead of stacked.
function processChordProContent(
  text: string,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  inline: boolean,
  commentLabel: string
): string {
  const commentLabels: string[] = []
  const sectionStarts: { type: string; label: string }[] = []
  const noteTexts: string[] = []

  // Replace {comment}/{c} with placeholder tokens.
  let processedText = text.replace(
    /\{c(?:omment(?:_italic|_box)?)?: *([^}]*)\}/gi,
    (_, content: string) => {
      commentLabels.push(content.trim())
      return `${COMMENT_TOKEN}${commentLabels.length - 1}`
    }
  )

  // Replace {note: text} with placeholder tokens.
  processedText = processedText.replace(/\{note: *([^}]*)\}/gi, (_, content: string) => {
    noteTexts.push(content.trim())
    return `${PERF_NOTE_TOKEN}${noteTexts.length - 1}`
  })

  // Replace section start directives with tokens; strip end markers entirely.
  processedText = processedText
    .replace(SECTION_START_RE, (_, directive: string, name?: string) => {
      const type = SECTION_DIRECTIVE_MAP[directive.toLowerCase()] ?? "section"
      const label = name?.trim() ?? sectionLabels[type] ?? type
      sectionStarts.push({ type, label })
      return `${SECTION_START_TOKEN}${sectionStarts.length - 1}`
    })
    .replace(SECTION_END_RE, "")

  const parser = new ChordProParser()
  let parsedSong = parser.parse(processedText)

  if (transpose !== 0) {
    parsedSong = parsedSong.transpose(transpose, { normalizeChordSuffix: false })
  }
  if (capo > 0) {
    parsedSong = parsedSong.transpose(-capo, { normalizeChordSuffix: false })
  }

  return parsedSong.lines
    .map((line) => {
      // line.toString() returns "[object Object]" in chordsheetjs v12 — read from items instead.
      const lineLyrics = line.items
        .map((item) => (item as { lyrics?: string | null }).lyrics ?? "")
        .join("")

      // Token: {comment}
      const commentMatch = lineLyrics.match(new RegExp(`${COMMENT_TOKEN}(\\d+)`))
      if (commentMatch) {
        const label = commentLabels[parseInt(commentMatch[1], 10)]
        return label
          ? `<div class="lyrics-comment"><div class="lyrics-comment-label">${escapeHtml(commentLabel)}</div><div class="lyrics-comment-body">${escapeHtml(label)}</div></div>`
          : ""
      }

      // Token: {note}
      const noteMatch = lineLyrics.match(new RegExp(`${PERF_NOTE_TOKEN}(\\d+)`))
      if (noteMatch) {
        const noteText = noteTexts[parseInt(noteMatch[1], 10)]
        return noteText ? `<span class="performance-note">${escapeHtml(noteText)}</span>` : ""
      }

      // Token: section start directive
      const sectionMatch = lineLyrics.match(new RegExp(`${SECTION_START_TOKEN}(\\d+)`))
      if (sectionMatch) {
        const { type, label } = sectionStarts[parseInt(sectionMatch[1], 10)]
        return `<span class="section-label section-label--${type}">${escapeHtml(label)}</span>`
      }

      let hasChords = false
      let lyricsLine = ""
      const inlineParts: string[] = []
      const clpParts: string[] = []
      let hasContentItems = false

      line.items.forEach((item) => {
        // Use type casting to safely access properties that might exist on different item types
        const chordPair = item as { chords?: string; lyrics?: string | null }
        const contentItem = item as { content?: string }

        const chord = chordPair.chords || ""
        const lyrics = chordPair.lyrics || ""

        if (chord || lyrics) {
          if (chord) hasChords = true

          if (inline) {
            // Side-by-side layout: lyrics then chord on same line
            if (lyrics) inlineParts.push(lyrics)
            if (chord) inlineParts.push(`<span class="chord">${chord}</span> `)
          } else {
            // Flex chord-lyric pair: chord stacked above its lyrics, no space-based positioning
            const chordSpan = chord
              ? `<span class="chord">${chord}</span>`
              : `<span class="clp-chord-empty"></span>`
            // When there is no lyric text the chord must stay in normal flow so it
            // sizes the .clp container — otherwise all zero-width .clp columns collapse
            // and their absolute-positioned chords overlap each other.
            const clpClass = chord && !lyrics ? "clp clp--chord-only" : "clp"
            clpParts.push(
              `<span class="${clpClass}">${chordSpan}<span class="clp-lyric">${lyrics}</span></span>`
            )
          }

          lyricsLine += lyrics

          // Also collect inline representation (lyrics precede the chord they annotate)
          if (!inline) {
            if (lyrics) inlineParts.push(lyrics)
            if (chord) inlineParts.push(`<span class="chord">${chord}</span> `)
          }
        } else if (contentItem.content) {
          lyricsLine += contentItem.content
          inlineParts.push(contentItem.content)
          hasContentItems = true
        }
      })

      // Auto-detect inline: only when plain text content items (e.g. "Bass: ") are
      // mixed with chords, as in "Bass: [Gm][Bb] x2". Normal chord-lyric verses
      // (pure ChordLyricsPairs) always use the stacked format.
      if (hasContentItems && hasChords) {
        return inlineParts
          .join("")
          .replace(/\s{2,}/g, " ")
          .trim()
      }
      if (inline) {
        return inlineParts
          .join("")
          .replace(/\s{2,}/g, " ")
          .trim()
      }
      if (hasChords) {
        return `<span class="chord-line">${clpParts.join("")}</span>`
      }
      return lyricsLine
    })
    .join("\n")
}

// Splits text at {start_of_volta}...{end_of_volta} boundaries, processes each piece
// through processChordProContent, and wraps volta pieces in a styled div card.
// Block-level <div> elements are valid inside <pre> (HTML5) and break cleanly out
// of the preformatted flow while inheriting whitespace-pre-wrap for their content.
function splitAndProcessVolta(
  text: string,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  inline: boolean,
  commentLabel: string
): string {
  const parts: string[] = []
  let lastIndex = 0
  let hasVolta = false

  const re = new RegExp(VOLTA_SPLIT_RE.source, "gi")
  let match: RegExpExecArray | null

  while ((match = re.exec(text)) !== null) {
    hasVolta = true
    const before = text.slice(lastIndex, match.index)
    if (before) {
      // trimEnd so the div block starts cleanly without extra blank lines
      parts.push(
        processChordProContent(
          before,
          transpose,
          capo,
          sectionLabels,
          inline,
          commentLabel
        ).trimEnd()
      )
    }

    const label = match[1]?.trim() ?? ""
    const content = match[2] ?? ""
    const innerHtml = processChordProContent(
      content.trim(),
      transpose,
      capo,
      sectionLabels,
      inline,
      commentLabel
    )
    const labelHtml = label ? `<div class="volta-label">${escapeHtml(label)}</div>` : ""
    parts.push(
      `<div class="volta-block">${labelHtml}<div class="volta-content">${innerHtml}</div></div>`
    )

    lastIndex = match.index + match[0].length
  }

  const tail = text.slice(lastIndex)
  if (tail) {
    // trimStart so content after a volta block doesn't have leading blank lines
    const tailHtml = processChordProContent(
      hasVolta ? tail.trimStart() : tail,
      transpose,
      capo,
      sectionLabels,
      inline,
      commentLabel
    )
    if (tailHtml) parts.push(tailHtml)
  }

  return parts.join("\n")
}

// Splits text at {start_of_box}...{end_of_box} boundaries, processes each piece
// through splitAndProcessVolta, and wraps box pieces in a labeled card using the
// same visual style as the comment box.
function splitAndProcessBox(
  text: string,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  inline: boolean,
  commentLabel: string
): string {
  const parts: string[] = []
  let lastIndex = 0
  let hasBox = false

  const re = new RegExp(BOX_SPLIT_RE.source, "gi")
  let match: RegExpExecArray | null

  while ((match = re.exec(text)) !== null) {
    hasBox = true
    const before = text.slice(lastIndex, match.index)
    if (before) {
      parts.push(
        splitAndProcessVolta(
          before,
          transpose,
          capo,
          sectionLabels,
          inline,
          commentLabel
        ).trimEnd()
      )
    }

    const label = match[1]?.trim() ?? ""
    const content = match[2] ?? ""
    const innerHtml = splitAndProcessVolta(
      content.trim(),
      transpose,
      capo,
      sectionLabels,
      inline,
      commentLabel
    )
    const labelHtml = label ? `<div class="lyrics-box-label">${escapeHtml(label)}</div>` : ""
    parts.push(
      `<div class="lyrics-box">${labelHtml}<div class="lyrics-box-content">${innerHtml}</div></div>`
    )

    lastIndex = match.index + match[0].length
  }

  const tail = text.slice(lastIndex)
  if (tail) {
    const tailHtml = splitAndProcessVolta(
      hasBox ? tail.trimStart() : tail,
      transpose,
      capo,
      sectionLabels,
      inline,
      commentLabel
    )
    if (tailHtml) parts.push(tailHtml)
  }

  return parts.join("\n")
}

function formatLyricsToHtml(
  text: string,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  commentLabel: string
): string {
  return splitAndProcessBox(text, transpose, capo, sectionLabels, false, commentLabel)
}

function formatInlineLyricsToHtml(
  text: string,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  commentLabel: string
): string {
  return splitAndProcessBox(text, transpose, capo, sectionLabels, true, commentLabel)
}

// Matches the opening { of any directive that starts a new section or a repeat
// reference, used to determine where a comment-defined section ends.
const SECTION_BOUNDARY_RE =
  /\{(?:c(?:omment(?:_italic|_box)?)?|start_of_(?:chorus|verse|bridge|tab|grid|intro|outro|pre_chorus)|soc|sov|sob|sot|sog|soi|soo|sopc|repeat)(?:[:\s}])/

// Scanner: finds all collapsible segment boundaries in order.
// Unnamed {c} / {comment} (no colon+value) are intentionally skipped — they
// render as empty labels and should not be treated as section boundaries.
const SEGMENT_SCAN_RE =
  /\{(start_of_chorus|soc|start_of_verse|sov|start_of_bridge|sob|start_of_tab|sot|start_of_grid|sog|start_of_intro|soi|start_of_outro|soo|start_of_pre_chorus|sopc|c(?:omment(?:_italic|_box)?)?|repeat)(?::\s*([^}]*))?\}/gi

function buildSectionMap(lyrics: string): Map<string, string> {
  const map = new Map<string, string>()

  // 1. Named explicit blocks: {soc/sov/sob/soi/soo/sopc/sot/sog: Name}...{end}
  const blockRe =
    /\{(?:start_of_chorus|soc|start_of_verse|sov|start_of_bridge|sob|start_of_intro|soi|start_of_outro|soo|start_of_pre_chorus|sopc|start_of_tab|sot|start_of_grid|sog)(?::\s*([^}]+))?\}([\s\S]*?)\{(?:end_of_chorus|eoc|end_of_verse|eov|end_of_bridge|eob|end_of_intro|eoi|end_of_outro|eoo|end_of_pre_chorus|eopc|end_of_tab|eot|end_of_grid|eog)\}/gi
  let match: RegExpExecArray | null
  while ((match = blockRe.exec(lyrics)) !== null) {
    const name = match[1]?.trim()
    if (name) {
      const { name: cleanName } = parseSectionValue(name)
      map.set(cleanName.toLowerCase(), match[2].trim())
    }
  }

  // 2. Comment-labeled sections: {comment: Name} → content until the next
  //    section boundary (another comment, soc, sov, etc.) or end of string.
  //    Named blocks above take priority — skip if the name is already in the map.
  const commentRe = /\{c(?:omment(?:_italic|_box)?)?: *([^}]+)\}/gi
  while ((match = commentRe.exec(lyrics)) !== null) {
    const name = match[1].trim()
    if (!name || map.has(name.toLowerCase())) continue

    const contentStart = match.index + match[0].length
    const remaining = lyrics.slice(contentStart)
    const nextBoundary = SECTION_BOUNDARY_RE.exec(remaining)
    const content = (nextBoundary ? remaining.slice(0, nextBoundary.index) : remaining).trim()

    if (content) map.set(name.toLowerCase(), content)
  }

  return map
}

// Parses directive values that accept an optional count and/or performance flags.
// Syntax: "Name" | "Name, N" | "Name, flag" | "Name, N, flag1, flag2"
// - First comma-separated token is the name (quotes stripped)
// - A positive integer token becomes the repeat count
// - Tokens matching SECTION_FLAGS become flags
// - Unknown tokens are ignored
// Used for both {repeat: Name, N} and {sov: Name, N, forte} directives.
function parseSectionValue(raw: string): { name: string; count: number; flags: SectionFlag[] } {
  const parts = raw.split(",").map((p) => p.trim())
  const name = parts[0].replace(/^["']|["']$/g, "")
  let count = 1
  const flags: SectionFlag[] = []
  for (const part of parts.slice(1)) {
    const n = Number(part)
    if (Number.isInteger(n) && n > 0) {
      count = n
      continue
    }
    if ((SECTION_FLAGS as readonly string[]).includes(part)) {
      flags.push(part as SectionFlag)
    }
  }
  return { name, count, flags }
}

function buildSegments(
  lyrics: string,
  sectionMap: Map<string, string>,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  commentLabel: string
): LyricsSegment[] {
  const segments: LyricsSegment[] = []
  let pos = 0
  const scanner = new RegExp(SEGMENT_SCAN_RE.source, "gi")

  while (true) {
    scanner.lastIndex = pos
    const match = scanner.exec(lyrics)

    if (!match) {
      const tail = lyrics.slice(pos).trim()
      if (tail)
        segments.push({
          type: "normal",
          html: formatLyricsToHtml(tail, transpose, capo, sectionLabels, commentLabel)
        })
      break
    }

    const directive = match[1].toLowerCase()
    const value = match[2]?.trim() ?? ""
    const matchEnd = match.index + match[0].length

    // Normal content before this boundary
    const before = lyrics.slice(pos, match.index).trim()
    if (before)
      segments.push({
        type: "normal",
        html: formatLyricsToHtml(before, transpose, capo, sectionLabels, commentLabel)
      })

    let newPos = matchEnd

    if (directive === "repeat") {
      if (value) {
        const { name, count } = parseSectionValue(value)
        const content = sectionMap.get(name.toLowerCase())
        if (content) {
          segments.push({
            type: "repeat",
            name,
            count,
            html: formatLyricsToHtml(content, transpose, capo, sectionLabels, commentLabel),
            found: true
          })
        } else {
          segments.push({ type: "repeat", name, count, html: "", found: false })
        }
      }
    } else if (/^c(omment(_italic|_box)?)?$/.test(directive)) {
      // Named comment section: runs until the next section boundary.
      if (value) {
        const remaining = lyrics.slice(matchEnd)
        const nextBoundary = SECTION_BOUNDARY_RE.exec(remaining)
        const content = (nextBoundary ? remaining.slice(0, nextBoundary.index) : remaining).trim()
        segments.push({
          type: "section",
          name: value,
          sectionType: "comment",
          html: formatLyricsToHtml(content, transpose, capo, sectionLabels, commentLabel),
          count: 1,
          flags: [],
          inline: false
        })
        newPos = matchEnd + (nextBoundary ? nextBoundary.index : remaining.length)
      }
    } else {
      // start_of_X — find the matching end_of_X
      const sectionType = SECTION_DIRECTIVE_MAP[directive] ?? "section"
      const {
        name: parsedName,
        count,
        flags
      } = value
        ? parseSectionValue(value)
        : { name: sectionLabels[sectionType] ?? sectionType, count: 1, flags: [] }
      const remaining = lyrics.slice(matchEnd)
      const endMatch =
        /\{(?:end_of_chorus|eoc|end_of_verse|eov|end_of_bridge|eob|end_of_tab|eot|end_of_grid|eog|end_of_intro|eoi|end_of_outro|eoo|end_of_pre_chorus|eopc)\}/i.exec(
          remaining
        )
      const content = (endMatch ? remaining.slice(0, endMatch.index) : remaining).trim()
      const inline = flags.includes("inline")
      segments.push({
        type: "section",
        name: parsedName,
        sectionType,
        html: inline
          ? formatInlineLyricsToHtml(content, transpose, capo, sectionLabels, commentLabel)
          : formatLyricsToHtml(content, transpose, capo, sectionLabels, commentLabel),
        count,
        flags,
        inline
      })
      newPos = matchEnd + (endMatch ? endMatch.index + endMatch[0].length : remaining.length)
    }

    pos = newPos
  }

  return segments
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
  inline: { label: "inline", className: "bg-muted text-muted-foreground" }
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
    flags && flags.some((f) => f !== "inline") ? (
      <span className="flex items-center gap-1 shrink-0">
        {flags
          .filter((f) => f !== "inline")
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
            <div key={index} className="section-repeat" data-section-type="repeat">
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
