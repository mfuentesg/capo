import { parseCifraClubHtml } from "../parse-html"

// NOTE: this fixture HTML is a hand-authored approximation of CifraClub's
// markup (JSON-LD block, a <pre> chord sheet with chords wrapped in <b>
// tags, a "Tom:" key label) — it has NOT been verified against a live
// CifraClub page, since this environment's network egress to cifraclub.com
// is blocked. It exercises parse-html.ts's own fallback logic; adjust it (and
// the parser's selectors) once real markup can be inspected.
const CHORD_SHEET = [
  "<b>Em</b>            <b>C</b>",
  "Test lyric line one",
  "<b>G</b>             <b>D</b>",
  "Test lyric line two"
].join("\n")

function buildHtml({
  jsonLd,
  ogTitle,
  h1,
  pres,
  tomLine
}: {
  jsonLd?: { name?: string; byArtist?: { name?: string } }
  ogTitle?: string
  h1?: string
  pres?: string[]
  tomLine?: string
} = {}): string {
  return `<!doctype html>
<html>
<head>
  ${ogTitle ? `<meta property="og:title" content="${ogTitle}">` : ""}
  ${jsonLd ? `<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>` : ""}
</head>
<body>
  ${h1 ? `<h1>${h1}</h1>` : ""}
  ${tomLine ? `<div>${tomLine}</div>` : ""}
  ${(pres ?? []).map((content) => `<pre>${content}</pre>`).join("\n")}
</body>
</html>`
}

const SONG_URL = new URL("https://www.cifraclub.com/israel-houghton/eres-fiel/")

describe("parseCifraClubHtml", () => {
  it("parses title, artist, key, and converts the chord sheet on the happy path", () => {
    const html = buildHtml({
      jsonLd: { name: "Eres Fiel", byArtist: { name: "Israel Houghton" } },
      pres: [CHORD_SHEET],
      tomLine: "Tom: Em"
    })

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.title).toBe("Eres Fiel")
    expect(result.data.artist).toBe("Israel Houghton")
    expect(result.data.key).toBe("Em")
    expect(result.data.keyFound).toBe(true)
    expect(result.data.lyrics).toContain("[")
  })

  it("fails with no_chord_block when there are no <pre> tags", () => {
    const html = buildHtml({ jsonLd: { name: "Eres Fiel", byArtist: { name: "Israel Houghton" } } })

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result).toEqual({ success: false, error: "no_chord_block" })
  })

  it("fails with no_chord_block when the only <pre> is too short to be a chord sheet", () => {
    const html = buildHtml({ pres: ["just one line"] })

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result).toEqual({ success: false, error: "no_chord_block" })
  })

  it("picks the largest <pre> block when multiple are present", () => {
    const html = buildHtml({ pres: ["short\nblock", CHORD_SHEET] })

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result.success).toBe(true)
    if (!result.success) return
    // ChordsOverWordsParser may split a chord bracket mid-word depending on
    // column alignment, so compare with chord brackets stripped out.
    const lyricsWithoutChords = result.data.lyrics.replace(/\[[^\]]*\]/g, "")
    expect(lyricsWithoutChords).toContain("Test lyric line one")
    expect(lyricsWithoutChords).not.toContain("short")
    expect(lyricsWithoutChords).not.toContain("block")
  })

  it("succeeds with keyFound: false when no Tom: label is present", () => {
    const html = buildHtml({
      jsonLd: { name: "Eres Fiel", byArtist: { name: "Israel Houghton" } },
      pres: [CHORD_SHEET]
    })

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.keyFound).toBe(false)
    expect(result.data.key).toBe("")
  })

  it("falls back to og:title (\"Artist - Title\") when JSON-LD is missing", () => {
    const html = buildHtml({ ogTitle: "Israel Houghton - Eres Fiel", pres: [CHORD_SHEET] })
    const urlWithNoSlugs = new URL("https://www.cifraclub.com/")

    const result = parseCifraClubHtml(html, urlWithNoSlugs)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.artist).toBe("Israel Houghton")
    expect(result.data.title).toBe("Eres Fiel")
  })

  it("falls back to the URL path slugs when JSON-LD and meta tags are missing", () => {
    const html = buildHtml({ pres: [CHORD_SHEET] })
    const url = new URL("https://www.cifraclub.com/john-mayer/gravity/")

    const result = parseCifraClubHtml(html, url)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.artist).toBe("John Mayer")
    expect(result.data.title).toBe("Gravity")
  })
})
