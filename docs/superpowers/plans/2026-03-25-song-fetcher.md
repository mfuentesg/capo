# Song Fetcher Script Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a CLI script (`scripts/fetch-song.ts`) that fetches chord+lyric content from CifraClub, converts it to ChordPro format via ChordSheetJS, and writes it to `scripts/output/<artist>-<title>.txt`.

**Architecture:** Provider-based: a thin CLI entry point delegates to a registry that selects the right `SongProvider` by URL hostname, or falls back to the default (CifraClub) for artist+title queries. Pure extraction helpers are separated from the network layer so they can be unit-tested without HTTP calls.

**Tech Stack:** TypeScript, `tsx` (already in devDependencies), `chordsheetjs` v12.3.1 (already installed), Node.js `fetch` + `fs/promises`, Jest + `@testing-library/jest-dom`.

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `scripts/providers/types.ts` | Create | `SongData` and `SongProvider` interfaces |
| `scripts/sanitize.ts` | Create | Pure `sanitizeFilename` function |
| `scripts/providers/cifraclub-helpers.ts` | Create | Pure HTML extraction functions (title, pre content, search URL) |
| `scripts/providers/index.ts` | Create | Provider registry (`getProviderForUrl`, `getDefaultProvider`) |
| `scripts/providers/cifraclub.ts` | Create | `CifraClubProvider` class with `fetchByUrl` + `fetchByQuery` |
| `scripts/fetch-song.ts` | Create | CLI entry point: arg parsing, provider dispatch, file write |
| `scripts/__tests__/sanitize.test.ts` | Create | Unit tests for `sanitizeFilename` |
| `scripts/__tests__/cifraclub-helpers.test.ts` | Create | Unit tests for HTML extraction helpers |
| `scripts/__tests__/registry.test.ts` | Create | Unit tests for the provider registry |
| `package.json` | Modify | Add `"fetch-song": "tsx scripts/fetch-song.ts"` script |
| `.gitignore` | Modify | Add `scripts/output/` entry |

---

## Task 1: Bootstrap — types, gitignore, package.json script

**Files:**
- Create: `scripts/providers/types.ts`
- Modify: `package.json`
- Modify: `.gitignore`

- [ ] **Step 1: Create the types file**

```typescript
// scripts/providers/types.ts
export interface SongData {
  title: string
  artist: string
  chordpro: string
}

export interface SongProvider {
  /** Hostnames this provider handles, e.g. ["www.cifraclub.com"] */
  hostnames: string[]
  /** Fetch and convert a song by its direct URL */
  fetchByUrl(url: string): Promise<SongData>
  /**
   * Search for a song by artist and title and return the best match.
   * Providers that do not support search must throw a descriptive error.
   */
  fetchByQuery(artist: string, title: string): Promise<SongData>
}
```

- [ ] **Step 2: Add the npm script to package.json**

In `package.json`, inside the `"scripts"` object, add after `"optimize:logos"`:

```json
"fetch-song": "tsx scripts/fetch-song.ts",
```

- [ ] **Step 3: Add scripts/output/ to .gitignore**

Append to `.gitignore`:

```
scripts/output/
```

- [ ] **Step 4: Commit**

```bash
git add scripts/providers/types.ts package.json .gitignore
git commit -m "feat: scaffold song fetcher types and config"
```

---

## Task 2: sanitizeFilename — TDD

**Files:**
- Create: `scripts/sanitize.ts`
- Create: `scripts/__tests__/sanitize.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// scripts/__tests__/sanitize.test.ts
import { sanitizeFilename } from "../sanitize"

describe("sanitizeFilename", () => {
  it("lowercases input", () => {
    expect(sanitizeFilename("Hello World")).toBe("hello-world")
  })

  it("replaces spaces with dashes", () => {
    expect(sanitizeFilename("foo bar baz")).toBe("foo-bar-baz")
  })

  it("transliterates accented characters", () => {
    expect(sanitizeFilename("Legião Urbana")).toBe("legiao-urbana")
    expect(sanitizeFilename("Cássia Eller")).toBe("cassia-eller")
    expect(sanitizeFilename("João")).toBe("joao")
  })

  it("removes non-alphanumeric characters", () => {
    expect(sanitizeFilename("Rock 'n' Roll")).toBe("rock-n-roll")
    expect(sanitizeFilename("A/B")).toBe("a-b")
  })

  it("collapses consecutive dashes", () => {
    expect(sanitizeFilename("foo  bar")).toBe("foo-bar")
    expect(sanitizeFilename("a--b")).toBe("a-b")
  })

  it("strips leading and trailing dashes", () => {
    expect(sanitizeFilename("-foo-")).toBe("foo")
  })

  it("trims to 100 characters", () => {
    expect(sanitizeFilename("a".repeat(200))).toHaveLength(100)
  })
})
```

- [ ] **Step 2: Run tests — expect failure (module not found)**

```bash
pnpm test -- --testPathPattern=scripts/__tests__/sanitize.test.ts
```

Expected: FAIL — `Cannot find module '../sanitize'`

- [ ] **Step 3: Implement sanitizeFilename**

```typescript
// scripts/sanitize.ts

/**
 * Produces a safe filename segment from arbitrary text.
 * Lowercases, strips diacritics, replaces non-alphanumeric chars with dashes,
 * collapses consecutive dashes, and limits to 100 characters.
 */
export function sanitizeFilename(input: string): string {
  return input
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // strip combining diacritical marks
    .replace(/[^a-z0-9]+/g, "-")    // non-alphanumeric → dash
    .replace(/-+/g, "-")            // collapse consecutive dashes
    .replace(/^-|-$/g, "")          // strip leading/trailing dashes
    .slice(0, 100)
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
pnpm test -- --testPathPattern=scripts/__tests__/sanitize.test.ts
```

Expected: PASS (7 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/sanitize.ts scripts/__tests__/sanitize.test.ts
git commit -m "feat: add sanitizeFilename utility with tests"
```

---

## Task 3: CifraClub HTML helpers — TDD

**Files:**
- Create: `scripts/providers/cifraclub-helpers.ts`
- Create: `scripts/__tests__/cifraclub-helpers.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
// scripts/__tests__/cifraclub-helpers.test.ts
import {
  extractTitle,
  extractChordContent,
  extractSearchResultUrl
} from "../providers/cifraclub-helpers"

describe("extractTitle", () => {
  it("extracts title and artist from CifraClub title format", () => {
    const html = "<title>Glorioso Dia - Passion - Cifra Club</title>"
    expect(extractTitle(html)).toEqual({ title: "Glorioso Dia", artist: "Passion" })
  })

  it("handles artists whose names contain dashes", () => {
    const html = "<title>Faroeste Caboclo - Legião Urbana - Cifra Club</title>"
    expect(extractTitle(html)).toEqual({ title: "Faroeste Caboclo", artist: "Legião Urbana" })
  })

  it("handles extra whitespace in the title tag", () => {
    const html = "<title>  My Song  -  My Artist  -  Cifra Club  </title>"
    expect(extractTitle(html)).toEqual({ title: "My Song", artist: "My Artist" })
  })

  it("throws when no title tag is found", () => {
    expect(() => extractTitle("<html><body></body></html>")).toThrow("Could not find <title> tag")
  })

  it("throws when title has fewer than 3 dash-separated parts", () => {
    expect(() => extractTitle("<title>Only One Part</title>")).toThrow("Unexpected title format")
  })
})

describe("extractChordContent", () => {
  it("extracts raw text from a bare pre tag", () => {
    const html = "<pre>Am  G\nLyric line</pre>"
    expect(extractChordContent(html)).toBe("Am  G\nLyric line")
  })

  it("extracts content from a pre tag with class attribute", () => {
    const html = '<pre class="cifra-mono">Am  G\nLyric line</pre>'
    expect(extractChordContent(html)).toBe("Am  G\nLyric line")
  })

  it("decodes HTML entities", () => {
    const html = "<pre>&amp; &lt;test&gt; &quot;ok&quot; &#039;yes&#039;</pre>"
    expect(extractChordContent(html)).toBe('& <test> "ok" \'yes\'')
  })

  it("strips inline HTML tags", () => {
    const html = "<pre><b>Am</b>  <span>G</span>\nLyric</pre>"
    expect(extractChordContent(html)).toBe("Am  G\nLyric")
  })

  it("throws when no pre tag is found", () => {
    expect(() => extractChordContent("<html><body></body></html>")).toThrow(
      "Could not extract chord content from page"
    )
  })
})

describe("extractSearchResultUrl", () => {
  it("returns the first two-segment song path as an absolute URL", () => {
    const html = '<a href="/passion/glorioso-dia/">Glorioso Dia</a>'
    expect(extractSearchResultUrl(html)).toBe(
      "https://www.cifraclub.com/passion/glorioso-dia/"
    )
  })

  it("ignores hrefs that are not two-segment song paths", () => {
    const html = '<a href="/busca/">Search</a><a href="/passion/glorioso-dia/">Song</a>'
    expect(extractSearchResultUrl(html)).toBe(
      "https://www.cifraclub.com/passion/glorioso-dia/"
    )
  })

  it("returns null when no song URL is found", () => {
    expect(extractSearchResultUrl("<html></html>")).toBeNull()
  })
})
```

- [ ] **Step 2: Run tests — expect failure**

```bash
pnpm test -- --testPathPattern=scripts/__tests__/cifraclub-helpers.test.ts
```

Expected: FAIL — `Cannot find module '../providers/cifraclub-helpers'`

- [ ] **Step 3: Implement the helpers**

```typescript
// scripts/providers/cifraclub-helpers.ts

/**
 * Extracts song title and artist from a CifraClub HTML page.
 * CifraClub title format: "Song Title - Artist - Cifra Club"
 */
export function extractTitle(html: string): { title: string; artist: string } {
  const match = html.match(/<title[^>]*>([^<]+)<\/title>/)
  if (!match) throw new Error("Could not find <title> tag in page")
  const parts = match[1].trim().split(" - ")
  if (parts.length < 3) {
    throw new Error(`Unexpected title format: "${match[1].trim()}"`)
  }
  const title = parts[0].trim()
  // Artist is everything between the first and last segment (site name)
  const artist = parts.slice(1, -1).join(" - ").trim()
  return { title, artist }
}

/**
 * Extracts the chord+lyric content from the first <pre> block in a CifraClub HTML page.
 * Decodes HTML entities and strips any inline tags.
 */
export function extractChordContent(html: string): string {
  const match = html.match(/<pre[^>]*>([\s\S]*?)<\/pre>/)
  if (!match) throw new Error("Could not extract chord content from page")
  return decodeHtmlEntities(stripInlineTags(match[1]))
}

/**
 * Finds the first two-segment CifraClub song path in a search results page
 * and returns it as an absolute URL. Returns null if none is found.
 *
 * Matches hrefs of the form: /artist-slug/song-slug/
 */
export function extractSearchResultUrl(html: string): string | null {
  // Match the first href with exactly two non-empty path segments
  const match = html.match(/href="(\/[^/"]+\/[^/"]+\/)"/)
  return match ? `https://www.cifraclub.com${match[1]}` : null
}

function stripInlineTags(str: string): string {
  return str.replace(/<[^>]+>/g, "")
}

function decodeHtmlEntities(str: string): string {
  return str
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
pnpm test -- --testPathPattern=scripts/__tests__/cifraclub-helpers.test.ts
```

Expected: PASS (11 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/providers/cifraclub-helpers.ts scripts/__tests__/cifraclub-helpers.test.ts
git commit -m "feat: add CifraClub HTML extraction helpers with tests"
```

---

## Task 4: Provider Registry — TDD

**Files:**
- Create: `scripts/providers/index.ts`
- Create: `scripts/__tests__/registry.test.ts`

Note: Writing the registry tests requires the `CifraClubProvider` to already exist as a class (even empty), because the registry instantiates it. Write a minimal stub first, then flesh it out in Task 5.

- [ ] **Step 1: Create a minimal CifraClubProvider stub**

```typescript
// scripts/providers/cifraclub.ts (stub — full implementation in Task 5)
import type { SongData, SongProvider } from "./types"

export class CifraClubProvider implements SongProvider {
  hostnames = ["www.cifraclub.com", "cifraclub.com"]

  async fetchByUrl(_url: string): Promise<SongData> {
    throw new Error("Not implemented")
  }

  async fetchByQuery(_artist: string, _title: string): Promise<SongData> {
    throw new Error("Not implemented")
  }
}
```

- [ ] **Step 2: Write the failing registry tests**

```typescript
// scripts/__tests__/registry.test.ts
import { getProviderForUrl, getDefaultProvider } from "../providers/index"

describe("getProviderForUrl", () => {
  it("returns a provider for www.cifraclub.com", () => {
    const provider = getProviderForUrl("https://www.cifraclub.com/passion/glorioso-dia/")
    expect(provider.hostnames).toContain("www.cifraclub.com")
  })

  it("returns a provider for cifraclub.com (without www)", () => {
    const provider = getProviderForUrl("https://cifraclub.com/passion/glorioso-dia/")
    expect(provider.hostnames).toContain("cifraclub.com")
  })

  it("throws for an unrecognized hostname", () => {
    expect(() => getProviderForUrl("https://unknown.example.com/song/")).toThrow(
      'No provider found for "unknown.example.com"'
    )
  })

  it("lists supported hostnames in the error message", () => {
    expect(() => getProviderForUrl("https://unknown.example.com/")).toThrow(
      "Supported hostnames:"
    )
  })
})

describe("getDefaultProvider", () => {
  it("returns a SongProvider with at least one hostname", () => {
    const provider = getDefaultProvider()
    expect(provider.hostnames.length).toBeGreaterThan(0)
  })

  it("returns the CifraClub provider (first registered)", () => {
    const provider = getDefaultProvider()
    expect(provider.hostnames).toContain("www.cifraclub.com")
  })
})
```

- [ ] **Step 3: Run tests — expect failure**

```bash
pnpm test -- --testPathPattern=scripts/__tests__/registry.test.ts
```

Expected: FAIL — `Cannot find module '../providers/index'`

- [ ] **Step 4: Implement the provider registry**

```typescript
// scripts/providers/index.ts
import type { SongProvider } from "./types"
import { CifraClubProvider } from "./cifraclub"

const providers: SongProvider[] = [new CifraClubProvider()]

/**
 * Returns the provider whose hostnames include the hostname of the given URL.
 * Throws with a list of supported hostnames if none is found.
 */
export function getProviderForUrl(url: string): SongProvider {
  const { hostname } = new URL(url)
  const provider = providers.find((p) => p.hostnames.includes(hostname))
  if (!provider) {
    const supported = providers.flatMap((p) => p.hostnames).join(", ")
    throw new Error(
      `No provider found for "${hostname}". Supported hostnames: ${supported}`
    )
  }
  return provider
}

/**
 * Returns the default provider (CifraClub), used for artist+title queries.
 */
export function getDefaultProvider(): SongProvider {
  return providers[0]
}
```

- [ ] **Step 5: Run tests — expect all pass**

```bash
pnpm test -- --testPathPattern=scripts/__tests__/registry.test.ts
```

Expected: PASS (6 tests)

- [ ] **Step 6: Commit**

```bash
git add scripts/providers/cifraclub.ts scripts/providers/index.ts scripts/__tests__/registry.test.ts
git commit -m "feat: add provider registry with tests"
```

---

## Task 5: CifraClub Provider — full implementation

**Files:**
- Modify: `scripts/providers/cifraclub.ts` (replace the stub from Task 4)

No new tests needed — the network layer is not unit-testable without complex mocking. The helpers (tested in Task 3) cover all pure logic. End-to-end validation happens in Task 7.

- [ ] **Step 1: Replace the stub with the full implementation**

```typescript
// scripts/providers/cifraclub.ts
import { ChordsOverWordsParser, ChordProFormatter } from "chordsheetjs"
import type { SongData, SongProvider } from "./types"
import { extractTitle, extractChordContent, extractSearchResultUrl } from "./cifraclub-helpers"

const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

async function fetchHtml(url: string): Promise<string> {
  const res = await fetch(url, {
    signal: AbortSignal.timeout(10_000),
    headers: { "User-Agent": USER_AGENT }
  })
  if (!res.ok) throw new Error(`Fetch failed: HTTP ${res.status} for ${url}`)
  return res.text()
}

export class CifraClubProvider implements SongProvider {
  hostnames = ["www.cifraclub.com", "cifraclub.com"]

  async fetchByUrl(url: string): Promise<SongData> {
    const html = await fetchHtml(url)
    const { title, artist } = extractTitle(html)
    const content = extractChordContent(html)

    const parser = new ChordsOverWordsParser()
    const parsed = parser.parse(content)

    // changeMetadata returns a new Song — chain both calls
    const song = parsed
      .changeMetadata("title", title)
      .changeMetadata("artist", artist)

    const chordpro = new ChordProFormatter().format(song)
    return { title, artist, chordpro }
  }

  async fetchByQuery(artist: string, title: string): Promise<SongData> {
    const q = encodeURIComponent(`${artist} ${title}`)
    const html = await fetchHtml(`https://www.cifraclub.com/busca/?q=${q}`)

    const songUrl = extractSearchResultUrl(html)
    if (!songUrl) {
      throw new Error(
        `No search results found for "${artist} - ${title}" on CifraClub`
      )
    }

    return this.fetchByUrl(songUrl)
  }
}
```

- [ ] **Step 2: Run all existing tests to confirm nothing broke**

```bash
pnpm test -- --testPathPattern=scripts/__tests__
```

Expected: PASS (all prior tests still green — the registry tests call `new CifraClubProvider()` but never invoke `fetchByUrl`/`fetchByQuery`)

- [ ] **Step 3: Commit**

```bash
git add scripts/providers/cifraclub.ts
git commit -m "feat: implement CifraClub provider using ChordSheetJS"
```

---

## Task 6: CLI Entry Point

**Files:**
- Create: `scripts/fetch-song.ts`

- [ ] **Step 1: Create the CLI script**

```typescript
#!/usr/bin/env tsx
// scripts/fetch-song.ts

import { mkdir, writeFile } from "fs/promises"
import { join } from "path"
import { getProviderForUrl, getDefaultProvider } from "./providers/index"
import { sanitizeFilename } from "./sanitize"

type ParsedArgs =
  | { mode: "url"; url: string }
  | { mode: "query"; artist: string; title: string }

function printUsage(): void {
  console.error(
    [
      "",
      "Usage:",
      "  pnpm fetch-song <url>",
      "  pnpm fetch-song --artist <artist> --title <title>",
      "",
      "Examples:",
      "  pnpm fetch-song https://www.cifraclub.com/passion/glorioso-dia/",
      '  pnpm fetch-song --artist "Passion" --title "Glorioso Dia"',
      ""
    ].join("\n")
  )
}

function parseArgs(args: string[]): ParsedArgs | null {
  if (args.length === 0) return null

  // URL mode: first arg starts with http
  if (args[0].startsWith("http")) {
    return { mode: "url", url: args[0] }
  }

  // Query mode: both --artist and --title flags present
  const artistIdx = args.indexOf("--artist")
  const titleIdx = args.indexOf("--title")

  if (artistIdx !== -1 && titleIdx !== -1) {
    const artist = args[artistIdx + 1]
    const title = args[titleIdx + 1]
    if (artist && !artist.startsWith("--") && title && !title.startsWith("--")) {
      return { mode: "query", artist, title }
    }
  }

  return null
}

async function main(): Promise<void> {
  const parsed = parseArgs(process.argv.slice(2))

  if (!parsed) {
    printUsage()
    process.exit(1)
  }

  const outputDir = join(process.cwd(), "scripts", "output")
  await mkdir(outputDir, { recursive: true })

  const provider =
    parsed.mode === "url" ? getProviderForUrl(parsed.url) : getDefaultProvider()

  const songData =
    parsed.mode === "url"
      ? await provider.fetchByUrl(parsed.url)
      : await provider.fetchByQuery(parsed.artist, parsed.title)

  const filename = `${sanitizeFilename(songData.artist)}-${sanitizeFilename(songData.title)}.txt`
  const outputPath = join(outputDir, filename)

  await writeFile(outputPath, songData.chordpro, "utf-8")
  console.log(`Saved to ${outputPath}`)
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.message : String(err)
  console.error(`Error: ${message}`)
  process.exit(1)
})
```

- [ ] **Step 2: Run all tests one final time**

```bash
pnpm test -- --testPathPattern=scripts/__tests__
```

Expected: PASS (all 24 tests across sanitize, cifraclub-helpers, and registry)

- [ ] **Step 3: Commit**

```bash
git add scripts/fetch-song.ts
git commit -m "feat: add fetch-song CLI entry point"
```

---

## Task 7: Smoke Test (manual)

No automated test possible here — this verifies real network access and the full end-to-end ChordPro conversion.

- [ ] **Step 1: Test URL mode**

```bash
pnpm fetch-song https://www.cifraclub.com/passion/glorioso-dia/
```

Expected output:
```
Saved to /path/to/project/scripts/output/passion-glorioso-dia.txt
```

Then inspect the file:
```bash
cat scripts/output/passion-glorioso-dia.txt
```

Expected: ChordPro-formatted text starting with `{title:Glorioso Dia}` and `{artist:Passion}` directives, followed by `{start_of_verse}` / chord + lyric lines.

- [ ] **Step 2: Test query mode**

```bash
pnpm fetch-song --artist "Legião Urbana" --title "Faroeste Caboclo"
```

Expected: file `scripts/output/legiao-urbana-faroeste-caboclo.txt` created with ChordPro content.

- [ ] **Step 3: Test error — no args**

```bash
pnpm fetch-song
```

Expected: usage message printed to stderr, exit code 1.

- [ ] **Step 4: Test error — unknown URL**

```bash
pnpm fetch-song https://unknown-site.example.com/song/
```

Expected: `Error: No provider found for "unknown-site.example.com". Supported hostnames: www.cifraclub.com, cifraclub.com`

- [ ] **Step 5: If `<pre>` content is missing (fallback investigation)**

If step 1 produces an empty or malformed output, CifraClub may have changed its HTML structure. Inspect the raw HTML:

```bash
curl -s -A "Mozilla/5.0" https://www.cifraclub.com/passion/glorioso-dia/ | grep -o '<pre[^>]*>.\{0,200\}'
```

If the `<pre>` block is absent, look for the chord content in the embedded `__NEXT_DATA__` JSON:

```bash
curl -s -A "Mozilla/5.0" https://www.cifraclub.com/passion/glorioso-dia/ | grep -o '"cifra":"[^"]*"' | head -c 500
```

Locate the relevant JSON key and update `extractChordContent` in `scripts/providers/cifraclub-helpers.ts` to parse that path instead.

- [ ] **Step 6: Final commit (if any adjustments were made)**

```bash
git add -p
git commit -m "fix: adjust CifraClub extraction for current page structure"
```
