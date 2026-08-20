import { readFileSync } from "fs"
import { join } from "path"
import { parseCifraClubHtml } from "../parse-html"

// This synthetic fixture builder covers edge cases (missing JSON-LD, multiple
// <pre> blocks, etc.) that are impractical to hit with a single real page.
// The real-page behavior itself is verified separately below against a
// Chrome-saved snapshot of https://www.cifraclub.com/israel-houghton/eres-fiel/
// (__fixtures__/cifraclub-eres-fiel.html) — see "against a real CifraClub page".
const CHORD_SHEET = [
  "[Estribillo]",
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
  jsonLd?: { type?: string | string[]; name?: string; byArtist?: { name?: string } }
  ogTitle?: string
  h1?: string
  pres?: string[]
  tomLine?: string
} = {}): string {
  const jsonLdPayload = jsonLd
    ? { "@type": jsonLd.type, name: jsonLd.name, byArtist: jsonLd.byArtist }
    : undefined

  return `<!doctype html>
<html>
<head>
  ${ogTitle ? `<meta property="og:title" content="${ogTitle}">` : ""}
  ${jsonLdPayload ? `<script type="application/ld+json">${JSON.stringify(jsonLdPayload)}</script>` : ""}
</head>
<body>
  ${h1 ? `<h1>${h1}</h1>` : ""}
  ${tomLine ? `<div>${tomLine}</div>` : ""}
  ${(pres ?? []).map((content) => `<pre>${content}</pre>`).join("\n")}
</body>
</html>`
}

const SONG_URL = new URL("https://www.cifraclub.com/israel-houghton/eres-fiel/")
const URL_WITH_NO_SLUGS = new URL("https://www.cifraclub.com/")

describe("parseCifraClubHtml", () => {
  it("parses title, artist, key, and converts the chord sheet on the happy path", () => {
    const html = buildHtml({
      jsonLd: { type: "MusicComposition", name: "Eres Fiel", byArtist: { name: "Israel Houghton" } },
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

  it("strips a literal [SectionLabel] instead of letting it look like ChordPro syntax", () => {
    // Regression test: "[Estribillo]" starts with a letter in A-G, which
    // used to make detectFormat() think the whole block was already
    // ChordPro and skip conversion entirely (real chords stayed unconverted).
    const html = buildHtml({ pres: [CHORD_SHEET] })

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.lyrics).not.toContain("[Estribillo]")
    expect(result.data.lyrics).toMatch(/\[Em\]|\[C\]|\[G\]|\[D\]/)
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

  it("does not false-match a Tom: label inside a <style> or <script> block", () => {
    // Regression test: cheerio's .text() includes script/style contents, and
    // a real page's CSS once produced a false "Tom:" match inside
    // "bottom:calc(...)".
    const html = `<!doctype html>
<html>
<head><style>.foo{bottom:calc(1px)}</style></head>
<body>
  <script>var x = "tom:calc value"</script>
  <pre>${CHORD_SHEET}</pre>
</body>
</html>`

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.keyFound).toBe(false)
  })

  it("prefers a MusicComposition JSON-LD block's clean name over a combined 'Artist - Title' name", () => {
    // Regression test: a MusicRecording/Article block's `name` is often the
    // combined "Artist - Title" string, which must not be used as the title.
    const html = `<!doctype html>
<html>
<head>
  <script type="application/ld+json">{"@type":["MusicRecording","Article"],"name":"Israel Houghton - Eres Fiel","byArtist":{"name":"Israel Houghton"}}</script>
  <script type="application/ld+json">{"@type":"MusicComposition","name":"Eres Fiel"}</script>
</head>
<body><pre>${CHORD_SHEET}</pre></body>
</html>`

    const result = parseCifraClubHtml(html, URL_WITH_NO_SLUGS)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.title).toBe("Eres Fiel")
    expect(result.data.artist).toBe("Israel Houghton")
  })

  it('falls back to og:title ("Title - Artist - Cifra Club") when JSON-LD and h1 are missing', () => {
    const html = buildHtml({ ogTitle: "Eres Fiel - Israel Houghton - Cifra Club", pres: [CHORD_SHEET] })

    const result = parseCifraClubHtml(html, URL_WITH_NO_SLUGS)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.title).toBe("Eres Fiel")
    expect(result.data.artist).toBe("Israel Houghton")
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

  it("prefers the URL path slugs over JSON-LD when both are present", () => {
    const html = buildHtml({
      jsonLd: { type: "MusicComposition", name: "Some Other Title", byArtist: { name: "Some Other Artist" } },
      pres: [CHORD_SHEET]
    })

    const result = parseCifraClubHtml(html, SONG_URL)

    expect(result.success).toBe(true)
    if (!result.success) return
    expect(result.data.title).toBe("Eres Fiel")
    expect(result.data.artist).toBe("Israel Houghton")
  })

  describe("against a real CifraClub page", () => {
    // Chrome-saved snapshot of https://www.cifraclub.com/israel-houghton/eres-fiel/,
    // provided by the user. This is the ground truth for whether the parser
    // actually works against production markup, not just synthetic fixtures.
    const REAL_HTML = readFileSync(
      join(__dirname, "__fixtures__", "cifraclub-eres-fiel.html"),
      "utf8"
    )
    const REAL_URL = new URL("https://www.cifraclub.com/israel-houghton/eres-fiel/")

    it("parses the correct title and artist", () => {
      const result = parseCifraClubHtml(REAL_HTML, REAL_URL)

      expect(result.success).toBe(true)
      if (!result.success) return
      expect(result.data.title).toBe("Eres Fiel")
      expect(result.data.artist).toBe("Israel Houghton")
    })

    it("does not find a spurious key on a page with no Tom: label", () => {
      const result = parseCifraClubHtml(REAL_HTML, REAL_URL)

      expect(result.success).toBe(true)
      if (!result.success) return
      expect(result.data.keyFound).toBe(false)
    })

    it("converts the real chord sheet into ChordPro with actual chords interleaved", () => {
      const result = parseCifraClubHtml(REAL_HTML, REAL_URL)

      expect(result.success).toBe(true)
      if (!result.success) return
      expect(result.data.lyrics).toContain("[E]")
      expect(result.data.lyrics).toContain("Senor eres fiel")
      // The literal "[Estribillo]" section label must not survive as a
      // bracketed token (it would otherwise render as a bogus chord badge).
      expect(result.data.lyrics).not.toContain("[Estribillo]")
    })
  })
})
