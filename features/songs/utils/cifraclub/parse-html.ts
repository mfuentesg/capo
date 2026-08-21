// "cheerio/slim" excludes the fromURL()/undici network helper we don't use
// (we fetch ourselves) — this also avoids undici's web-fetch shim requiring
// browser globals (ReadableStream, MessagePort, ...) that jsdom lacks.
import * as cheerio from "cheerio/slim"
import { convertChordAboveLyricsBlocks } from "@/features/lyrics-editor/utils/chordpro-converter"
import type { CifraClubParsedSong, CifraClubParseError } from "../../types/cifraclub-import.types"

const MIN_CHORD_BLOCK_LINES = 2
const KEY_PATTERN = /Tom:\s*([A-G][#b]?m?)/i

export type ParseCifraClubHtmlResult =
  | { success: true; data: CifraClubParsedSong }
  | { success: false; error: Extract<CifraClubParseError, "no_chord_block"> }

function humanizeSlug(slug: string): string {
  return slug
    .split("-")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ")
}

// CifraClub URLs follow /artist-slug/song-slug/ — the most stable signal on
// the page, since it doesn't depend on markup that can change without
// notice. Checked first; JSON-LD/meta are only fallbacks for non-standard URLs.
function readTitleArtistFromUrl(url: URL): { title?: string; artist?: string } {
  const segments = url.pathname.split("/").filter(Boolean)
  const [artistSlug, songSlug] = segments
  return {
    artist: artistSlug ? humanizeSlug(artistSlug) : undefined,
    title: songSlug ? humanizeSlug(songSlug) : undefined
  }
}

// CifraClub embeds several JSON-LD blocks. A MusicRecording/Article block's
// `name` is often the combined "Artist - Title" — not a clean title — so
// only the MusicComposition block's `name` is trusted for title; `byArtist`
// is read from whichever block has it.
function readJsonLd($: cheerio.CheerioAPI): { title?: string; artist?: string } {
  let title: string | undefined
  let artist: string | undefined

  for (const el of $('script[type="application/ld+json"]').toArray()) {
    try {
      const json: unknown = JSON.parse($(el).contents().text())
      const entries = Array.isArray(json) ? json : [json]
      for (const entry of entries) {
        if (typeof entry !== "object" || entry === null) continue
        const record = entry as Record<string, unknown>
        const type = record["@type"]
        const types = Array.isArray(type) ? type : [type]
        const name = typeof record.name === "string" ? record.name : undefined
        const byArtist = record.byArtist as Record<string, unknown> | undefined
        const artistName = typeof byArtist?.name === "string" ? byArtist.name : undefined

        if (!title && types.includes("MusicComposition") && name) {
          title = name
        }
        if (!artist && artistName) {
          artist = artistName
        }
      }
    } catch {
      // Malformed JSON-LD block — skip it and try the next one/fallback.
    }
  }

  return { title, artist }
}

function readTitleFromH1($: cheerio.CheerioAPI): string | undefined {
  const h1 = $("h1").first().text().trim()
  return h1 || undefined
}

// Observed og:title format is "Title - Artist - Cifra Club".
function readTitleArtistFromOgTitle($: cheerio.CheerioAPI): { title?: string; artist?: string } {
  const raw = $('meta[property="og:title"]').attr("content")?.trim()
  if (!raw) return {}
  const withoutSuffix = raw.replace(/\s*-\s*Cifra Club\s*$/i, "").trim()
  const [title, artist] = withoutSuffix.split(" - ").map((part) => part.trim())
  return { title: title || undefined, artist: artist || undefined }
}

// Cheerio's .text() includes <script>/<style> contents (unlike a browser's
// rendered text), so those are stripped first — otherwise the regex can
// false-match inside CSS/JS (e.g. "tom:c" inside "bottom:calc(...)").
function readKey($: cheerio.CheerioAPI): { key: string; keyFound: boolean } {
  const body = $("body").clone()
  body.find("script, style").remove()
  const match = body.text().match(KEY_PATTERN)
  return match ? { key: match[1], keyFound: true } : { key: "", keyFound: false }
}

// Extracts the chord sheet: CifraClub song pages have a single <pre> block
// containing chords (wrapped in inline tags like <b>) above lyric lines. If
// several <pre> tags are present, the chord sheet is assumed to be the
// largest one — ads/widgets are not <pre>-wrapped chord sheets.
function readChordBlock($: cheerio.CheerioAPI): string | null {
  const pres = $("pre").toArray()
  if (pres.length === 0) return null

  const texts = pres.map((el) => $(el).text())
  const largest = texts.reduce((best, current) => (current.length > best.length ? current : best))

  const nonEmptyLines = largest.split("\n").filter((line) => line.trim().length > 0)
  if (nonEmptyLines.length < MIN_CHORD_BLOCK_LINES) return null

  return largest
}

export function parseCifraClubHtml(html: string, sourceUrl: URL): ParseCifraClubHtmlResult {
  const $ = cheerio.load(html)

  const rawChordBlock = readChordBlock($)
  if (rawChordBlock === null) {
    return { success: false, error: "no_chord_block" }
  }

  const fromUrl = readTitleArtistFromUrl(sourceUrl)
  const fromJsonLd = readJsonLd($)
  const fromH1 = readTitleFromH1($)
  const fromOgTitle = readTitleArtistFromOgTitle($)

  const title = fromUrl.title || fromJsonLd.title || fromH1 || fromOgTitle.title || ""
  const artist = fromUrl.artist || fromJsonLd.artist || fromOgTitle.artist || ""
  const { key, keyFound } = readKey($)

  // CifraClub inlines its own bracketed section labels (e.g. "[Estribillo]")
  // in the same text as the chord-above-lyrics content. Chords themselves
  // never appear bracketed in the flattened text (only their plain name,
  // e.g. "E"), so any "[...]" here is a section label, not a chord — strip
  // the brackets so the parser below can't mistake it for ChordPro syntax
  // (which would make it skip conversion entirely).
  const withoutSectionBrackets = rawChordBlock.replace(/\[([^\]]*)\]/g, "$1")
  const { output: lyrics } = convertChordAboveLyricsBlocks(withoutSectionBrackets.trim())

  return { success: true, data: { title, artist, key, lyrics, keyFound } }
}
