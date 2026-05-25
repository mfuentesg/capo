# Song Fetcher Script — Design Spec

**Date:** 2026-03-25
**Status:** Approved

## Overview

A CLI script (`scripts/fetch-song.ts`) that fetches chord/lyric content from an online provider (initially CifraClub), converts it to ChordPro format using `chordsheetjs`, and writes the result to a `.txt` file. Designed with a provider-based architecture so additional sources can be added later by creating one new file.

---

## Architecture

```
scripts/
├── fetch-song.ts          # CLI entry point
├── providers/
│   ├── types.ts           # SongProvider interface + SongData type
│   ├── index.ts           # Provider registry and URL matcher
│   └── cifraclub.ts       # CifraClub implementation
└── output/                # Generated .txt files (gitignored via scripts/output/)
```

---

## Interfaces

```typescript
// scripts/providers/types.ts

interface SongData {
  title: string
  artist: string
  chordpro: string  // fully converted ChordPro string
}

interface SongProvider {
  /** Hostnames this provider handles, e.g. ["www.cifraclub.com"] */
  hostnames: string[]
  /** Fetch by direct URL */
  fetchByUrl(url: string): Promise<SongData>
  /**
   * Search and fetch the best match.
   * Providers that do not support search must throw a descriptive error
   * (e.g. "CifraClub does not support search — provide a direct URL").
   * Optional in the sense that not all providers need to implement it,
   * but it must be present on every provider object and throw clearly if unsupported.
   */
  fetchByQuery(artist: string, title: string): Promise<SongData>
}
```

---

## Provider Registry (`providers/index.ts`)

- Holds an array of all registered `SongProvider` instances
- `getProviderForUrl(url: string): SongProvider` — matches by hostname, throws with list of supported hostnames if none found
- `getDefaultProvider(): SongProvider` — returns the CifraClub provider (used for artist+title queries)

---

## CLI Entry Point (`fetch-song.ts`)

**Invocation:**
```bash
# URL mode
pnpm fetch-song https://www.cifraclub.com/passion/glorioso-dia/

# Query mode
pnpm fetch-song --artist "Passion" --title "Glorioso Dia"
```

Add to `package.json` scripts:
```json
"fetch-song": "tsx scripts/fetch-song.ts"
```

**Flow:**
1. Parse `process.argv` — detect URL mode (bare URL arg) vs query mode (`--artist` + `--title` both present)
2. If neither: print usage and `process.exit(1)`
3. Select provider: `getProviderForUrl(url)` for URL mode, `getDefaultProvider()` for query mode
4. Call `fetchByUrl` or `fetchByQuery` with a 10s timeout (`AbortSignal.timeout(10_000)`)
5. Set `song.title` and `song.artist` from extracted metadata before formatting (ensures ChordPro directives are present)
6. Sanitize filename: lowercase, transliterate accented chars (e.g. `ã→a`, `é→e`), replace spaces and non-alphanumeric chars with dashes, collapse consecutive dashes, trim to 100 chars
7. Create `scripts/output/` if it doesn't exist (`mkdir` with `{ recursive: true }`)
8. Write to `scripts/output/<artist>-<title>.txt`
9. Print success message with output path, or error to stderr on failure

No third-party CLI parser — `process.argv` is sufficient for this argument surface.

**`.gitignore` addition:**
```
scripts/output/
```

---

## CifraClub Provider (`providers/cifraclub.ts`)

**Hostnames:** `["www.cifraclub.com", "cifraclub.com"]`

### `fetchByUrl(url)`

1. `fetch(url, { signal: AbortSignal.timeout(10_000), headers: { "User-Agent": "Mozilla/5.0 ..." } })`
2. Extract title and artist from `<title>` tag — CifraClub format: `"Song Title - Artist - Cifra Club"` (three dash-separated segments; first = title, second = artist, third = site name to discard)
3. **HTML content extraction strategy:** CifraClub pages are server-rendered and include chord content in the initial HTML response inside a `<pre>` tag (commonly `<pre class="cifra-mono">`). Extract using regex on the raw HTML string. If the `<pre>` block is absent (e.g. the page structure changes), fall back to extracting from the embedded `__NEXT_DATA__` JSON in `<script id="__NEXT_DATA__">` — parse the JSON and locate the chord content field.
4. The `<pre>` content is in **ChordsOverWords** format — chords on one line directly above the lyric line:
   ```
   [Verse]
   Am        G
   Some lyric line here
   ```
5. Parse with `new ChordSheetJS.ChordsOverWordsParser().parse(content)`
6. Format with `new ChordSheetJS.ChordProFormatter().format(song)`
7. Return `SongData`

### `fetchByQuery(artist, title)`

1. Build search URL: `https://www.cifraclub.com/busca/?q=${encodeURIComponent(artist + " " + title)}`
2. Fetch the search results page (same User-Agent + timeout)
3. Extract the first result link using a resilient heuristic: find the first `<a>` whose `href` attribute matches the pattern `^/[^/]+/[^/]+/$` (i.e. a two-segment CifraClub song path). Use regex on raw HTML.
4. If no link is found: throw `"No search results found for '${artist} - ${title}' on CifraClub"`
5. Prepend `https://www.cifraclub.com` to the relative path and delegate to `fetchByUrl`

---

## ChordPro Output

The `ChordProFormatter` emits `{title:}` and `{artist:}` directives only if the `Song` object has those properties set. After parsing and before formatting, explicitly assign:

```typescript
song.title = extractedTitle
song.artist = extractedArtist
```

This ensures the output `.txt` file contains proper ChordPro metadata headers.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| No args / missing required flags | Print usage to stderr, `process.exit(1)` |
| URL hostname not matched | Throw with list of supported hostnames |
| Fetch fails (network / non-200) | Throw `"Fetch failed: HTTP ${status}"` |
| Fetch times out | AbortError propagates with clear message |
| `<pre>` tag not found, `__NEXT_DATA__` fallback also empty | Throw `"Could not extract chord content from page"` |
| No search results found | Throw with artist + title in message |
| Output dir creation fails | Let error propagate |

---

## Future Extension Points

- **New provider:** create `scripts/providers/newprovider.ts`, implement `SongProvider`, add instance to registry in `providers/index.ts`
- **Search-only providers:** `getDefaultProvider()` can be made selectable or round-robin across providers that support search
- **App integration (aspirational):** `SongData` and `SongProvider` types are candidates for moving into a future `features/song-import/` feature module if the import flow is built into the app
- **Output format:** swap `ChordProFormatter` for other ChordSheetJS formatters (`UltimateGuitarFormatter`, `HtmlFormatter`, etc.)
