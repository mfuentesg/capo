"use client"

import { ChordProParser } from "chordsheetjs"

export const SECTION_FLAGS = [
  "attention",
  "skip",
  "forte",
  "piano",
  "vamp",
  "tag",
  "break",
  "inline",
  "label"
] as const
export type SectionFlag = (typeof SECTION_FLAGS)[number]

export type LyricsSegment =
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
  | { type: "repeat"; name: string; count: number; html: string; found: boolean; sectionType: string }

// Unique tokens that survive ChordProParser unchanged (no [A-G] at word start).
const COMMENT_TOKEN = "SECTIONLBL"
const SECTION_START_TOKEN = "SECTSTART"
const PERF_NOTE_TOKEN = "PERFORMNOTE"

// Regex that matches {start_of_volta: label}...{end_of_volta} (and shorthand sovt/eovt).
const VOLTA_SPLIT_RE =
  /\{(?:start_of_volta|sovt)(?::\s*([^}]*))?\}([\s\S]*?)\{(?:end_of_volta|eovt)\}/gi

const BOX_OPEN_RE = /\{(?:start_of_box|sbox)(?::\s*([^}]*))?\}/gi
const BOX_CLOSE_RE = /\{(?:end_of_box|ebox)\}/i

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

export const SECTION_DIRECTIVE_MAP: Record<string, string> = {
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

  let processedText = text.replace(
    /\{c(?:omment(?:_italic|_box)?)?: *([^}]*)\}/gi,
    (_, content: string) => {
      commentLabels.push(content.trim())
      return `${COMMENT_TOKEN}${commentLabels.length - 1}`
    }
  )

  processedText = processedText.replace(/\{note: *([^}]*)\}/gi, (_, content: string) => {
    noteTexts.push(content.trim())
    return `${PERF_NOTE_TOKEN}${noteTexts.length - 1}`
  })

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
      const lineLyrics = line.items
        .map((item) => (item as { lyrics?: string | null }).lyrics ?? "")
        .join("")

      const commentMatch = lineLyrics.match(new RegExp(`${COMMENT_TOKEN}(\\d+)`))
      if (commentMatch) {
        const raw = commentLabels[parseInt(commentMatch[1], 10)]
        if (!raw) return ""
        const { name: text, flags: cflags } = parseSectionValue(raw)
        return cflags.includes("label")
          ? `<div class="lyrics-label">${escapeHtml(text)}</div>`
          : `<div class="lyrics-comment"><div class="lyrics-comment-label">${escapeHtml(commentLabel)}</div><div class="lyrics-comment-body">${escapeHtml(text)}</div></div>`
      }

      const noteMatch = lineLyrics.match(new RegExp(`${PERF_NOTE_TOKEN}(\\d+)`))
      if (noteMatch) {
        const noteText = noteTexts[parseInt(noteMatch[1], 10)]
        return noteText ? `<span class="performance-note">${escapeHtml(noteText)}</span>` : ""
      }

      const sectionMatch = lineLyrics.match(new RegExp(`${SECTION_START_TOKEN}(\\d+)`))
      if (sectionMatch) {
        const { type, label } = sectionStarts[parseInt(sectionMatch[1], 10)]
        return `<span class="section-label section-label--${type}">${escapeHtml(label)}</span>`
      }

      let hasChords = false
      let lyricsLine = ""
      const inlineParts: string[] = []
      const chordColParts: string[] = []
      let lyricsAccum = ""
      let hasContentItems = false

      line.items.forEach((item) => {
        const chordPair = item as { chords?: string; lyrics?: string | null }
        const contentItem = item as { content?: string }

        const chord = chordPair.chords || ""
        const lyrics = chordPair.lyrics || ""

        if (chord || lyrics) {
          if (chord) hasChords = true

          if (inline) {
            if (lyrics) inlineParts.push(lyrics)
            if (chord) inlineParts.push(`<span class="chord">${chord}</span> `)
          } else {
            const colWidth = Math.max(chord.length, lyrics.length)
            const chordSpan = chord ? `<span class="chord">${chord}</span>` : ``
            chordColParts.push(
              `<span class="clp-col" style="min-width:${colWidth}ch">${chordSpan}</span>`
            )
            lyricsAccum += lyrics
          }

          lyricsLine += lyrics

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
        return `<span class="clp-pair"><span class="clp-chords">${chordColParts.join("")}</span><span class="clp-lyric-text">${lyricsAccum}</span></span>`
      }
      return lyricsLine
    })
    .join("\n")
}

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
      parts.push(
        processChordProContent(before, transpose, capo, sectionLabels, inline, commentLabel).trimEnd()
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

  const openRe = new RegExp(BOX_OPEN_RE.source, "gi")
  let match: RegExpExecArray | null

  while ((match = openRe.exec(text)) !== null) {
    const before = text.slice(lastIndex, match.index)
    if (before) {
      parts.push(
        splitAndProcessVolta(before, transpose, capo, sectionLabels, inline, commentLabel).trimEnd()
      )
    }

    const label = match[1]?.trim() ?? ""
    const afterOpen = match.index + match[0].length
    const remaining = text.slice(afterOpen)
    const closeMatch = BOX_CLOSE_RE.exec(remaining)

    let content: string
    if (closeMatch) {
      content = remaining.slice(0, closeMatch.index)
      lastIndex = afterOpen + closeMatch.index + closeMatch[0].length
    } else {
      content = remaining
      lastIndex = text.length
    }
    openRe.lastIndex = lastIndex

    const { name: parsedLabel, flags: boxFlags } = parseSectionValue(label || "x")
    const boxLabelText = label ? parsedLabel : ""
    if (boxFlags.includes("label")) {
      parts.push(`<div class="lyrics-label">${escapeHtml(boxLabelText)}</div>`)
    } else {
      const innerHtml = splitAndProcessVolta(
        content.trim(),
        transpose,
        capo,
        sectionLabels,
        inline,
        commentLabel
      )
      const labelHtml = boxLabelText
        ? `<div class="lyrics-box-label">${escapeHtml(boxLabelText)}</div>`
        : ""
      parts.push(
        `<div class="lyrics-box">${labelHtml}<div class="lyrics-box-content">${innerHtml}</div></div>`
      )
    }
  }

  const tail = text.slice(lastIndex)
  if (tail) {
    const tailHtml = splitAndProcessVolta(
      lastIndex > 0 ? tail.trimStart() : tail,
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

export function formatLyricsToHtml(
  text: string,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  commentLabel: string
): string {
  return splitAndProcessBox(text, transpose, capo, sectionLabels, false, commentLabel)
}

export function formatInlineLyricsToHtml(
  text: string,
  transpose: number,
  capo: number,
  sectionLabels: Record<string, string>,
  commentLabel: string
): string {
  return splitAndProcessBox(text, transpose, capo, sectionLabels, true, commentLabel)
}

const SECTION_BOUNDARY_RE =
  /\{(?:c(?:omment(?:_italic|_box)?)?|start_of_(?:chorus|verse|bridge|tab|grid|intro|outro|pre_chorus)|soc|sov|sob|sot|sog|soi|soo|sopc|repeat)(?:[:\s}])/

const SEGMENT_SCAN_RE =
  /\{(start_of_chorus|soc|start_of_verse|sov|start_of_bridge|sob|start_of_tab|sot|start_of_grid|sog|start_of_intro|soi|start_of_outro|soo|start_of_pre_chorus|sopc|c(?:omment(?:_italic|_box)?)?|repeat)(?::\s*([^}]*))?\}/gi

interface SectionEntry {
  content: string
  sectionType: string
}

export function buildSectionMap(lyrics: string): Map<string, SectionEntry> {
  const map = new Map<string, SectionEntry>()

  const blockRe =
    /\{(start_of_chorus|soc|start_of_verse|sov|start_of_bridge|sob|start_of_intro|soi|start_of_outro|soo|start_of_pre_chorus|sopc|start_of_tab|sot|start_of_grid|sog)(?::\s*([^}]+))?\}([\s\S]*?)\{(?:end_of_chorus|eoc|end_of_verse|eov|end_of_bridge|eob|end_of_intro|eoi|end_of_outro|eoo|end_of_pre_chorus|eopc|end_of_tab|eot|end_of_grid|eog)\}/gi
  let match: RegExpExecArray | null
  while ((match = blockRe.exec(lyrics)) !== null) {
    const directive = match[1].toLowerCase()
    const sectionType = SECTION_DIRECTIVE_MAP[directive] ?? "section"
    const name = match[2]?.trim()
    if (name) {
      const { name: cleanName } = parseSectionValue(name)
      map.set(cleanName.toLowerCase(), { content: match[3].trim(), sectionType })
    }
  }

  const commentRe = /\{c(?:omment(?:_italic|_box)?)?: *([^}]+)\}/gi
  while ((match = commentRe.exec(lyrics)) !== null) {
    const name = match[1].trim()
    if (!name || map.has(name.toLowerCase())) continue

    const contentStart = match.index + match[0].length
    const remaining = lyrics.slice(contentStart)
    const nextBoundary = SECTION_BOUNDARY_RE.exec(remaining)
    const content = (nextBoundary ? remaining.slice(0, nextBoundary.index) : remaining).trim()

    if (content) map.set(name.toLowerCase(), { content, sectionType: "comment" })
  }

  return map
}

export function parseSectionValue(raw: string): { name: string; count: number; flags: SectionFlag[] } {
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

export function buildSegments(
  lyrics: string,
  sectionMap: Map<string, SectionEntry>,
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
        const entry = sectionMap.get(name.toLowerCase())
        if (entry) {
          segments.push({
            type: "repeat",
            name,
            count,
            html: formatLyricsToHtml(entry.content, transpose, capo, sectionLabels, commentLabel),
            found: true,
            sectionType: entry.sectionType
          })
        } else {
          segments.push({ type: "repeat", name, count, html: "", found: false, sectionType: "repeat" })
        }
      }
    } else if (/^c(omment(_italic|_box)?)?$/.test(directive)) {
      if (value) {
        const { name, flags: cflags } = parseSectionValue(value)
        segments.push({
          type: "section",
          name,
          sectionType: cflags.includes("label") ? "comment-label" : "comment",
          html: "",
          count: 1,
          flags: [],
          inline: false
        })
      }
    } else {
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
