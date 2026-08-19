// "cheerio/slim" excludes the fromURL()/undici network helper we don't use
// (we fetch ourselves) — this also avoids undici's web-fetch shim requiring
// browser globals (ReadableStream, MessagePort, ...) that jsdom lacks.
import * as cheerio from "cheerio/slim"
import { convertToChordPro } from "@/features/lyrics-editor/utils/chordpro-converter"
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

function readJsonLd($: cheerio.CheerioAPI): { title?: string; artist?: string } {
  for (const el of $('script[type="application/ld+json"]').toArray()) {
    try {
      const json: unknown = JSON.parse($(el).contents().text())
      const entries = Array.isArray(json) ? json : [json]
      for (const entry of entries) {
        if (typeof entry !== "object" || entry === null) continue
        const record = entry as Record<string, unknown>
        const name = typeof record.name === "string" ? record.name : undefined
        const byArtist = record.byArtist as Record<string, unknown> | undefined
        const artist = typeof byArtist?.name === "string" ? byArtist.name : undefined
        if (name || artist) return { title: name, artist }
      }
    } catch {
      // Malformed JSON-LD block — skip it and try the next one/fallback.
    }
  }
  return {}
}

// CifraClub URLs follow /artist-slug/song-slug/, the most stable signal on
// the page (more so than markup, which may change without notice).
function readTitleArtistFromUrl(url: URL): { title?: string; artist?: string } {
  const segments = url.pathname.split("/").filter(Boolean)
  const [artistSlug, songSlug] = segments
  return {
    artist: artistSlug ? humanizeSlug(artistSlug) : undefined,
    title: songSlug ? humanizeSlug(songSlug) : undefined
  }
}

function readTitleArtistFromMeta($: cheerio.CheerioAPI): { title?: string; artist?: string } {
  const ogTitle = $('meta[property="og:title"]').attr("content")?.trim()
  if (ogTitle?.includes(" - ")) {
    const [first, second] = ogTitle.split(" - ")
    return { artist: first?.trim(), title: second?.trim() }
  }
  const h1 = $("h1").first().text().trim()
  return { title: h1 || undefined }
}

function readKey($: cheerio.CheerioAPI): { key: string; keyFound: boolean } {
  const match = $("body").text().match(KEY_PATTERN)
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

  const fromJsonLd = readJsonLd($)
  const fromUrl = readTitleArtistFromUrl(sourceUrl)
  const fromMeta = readTitleArtistFromMeta($)

  const title = fromJsonLd.title || fromUrl.title || fromMeta.title || ""
  const artist = fromJsonLd.artist || fromUrl.artist || fromMeta.artist || ""
  const { key, keyFound } = readKey($)
  const { output: lyrics } = convertToChordPro(rawChordBlock.trim())

  return { success: true, data: { title, artist, key, lyrics, keyFound } }
}
