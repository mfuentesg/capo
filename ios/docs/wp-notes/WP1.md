## WP1 notes

**Scope delivered.** `CapoChordPro` is a byte-exact Swift port of `song-pipeline.ts`. It sits on a port of the chordsheetjs 12.3.1 ChordPro grammar, done rule by rule with PEG semantics, and of its Key/Chord transposer. `lib/music-theory.ts` is ported too.

**Source layout:**
- `Engine/`: `ChordProEngine`, the segment builder, the content processor (volta, box and line rendering), section values, directive matchers, and JS string semantics on UTF-16.
- `Parser/`: the ChordPro grammar.
- `Transpose/`: Key, Chord, the scales and enharmonic tables, and the generated suffix mapping.
- `MusicTheory/`
- `Legacy/LegacyHTMLSerializer`

**Approach:**
- The pipeline works on `[UInt16]` so that it matches JS exactly:
  - `\s` and `trim` sets
  - UTF-16 lengths for `min-width:Nch`
  - ASCII-only `/i` folding
- Regexes are hand-written scanners. They reproduce backtracking where it changes captures (`[^}]+` takes back one whitespace character).
- HTML string trims and joins (`trimEnd`, `"\n"` joins, empty parts) are applied to `SongBody` lines. `LegacyHTMLSerializer` is then a pure function of the model.

**Tests** (`swift test --filter CapoChordProTests`):
- `GoldenPipelineTests`: every pipeline golden (8 files, 120 cases, 495 segments), exact equality on every field.
- `ChordGoldenTests`: `chords.json` (parse, transpose −12…12, normalize with and without suffix, and the two-pass pipeline through the engine).
- `MusicTheoryGoldenTests`: `music-theory.json`.
- `DirectiveTests`: 17 per-directive cases whose expected values come from the web pipeline, including a throw-to-raw-lyrics case.
- `PerfTests`: a 300-line song renders in about 2.7 ms median in release, against a 5 ms budget (`swift test -c release --filter Perf`). A per-pass chord transposition cache keeps it there.

**Deviations:** see `ios/Fixtures/known-divergences.md`. None of them show up in the goldens.

**TODO / follow-ups:**
- A CRLF corpus fixture (PLAN §10) would pin `\r` handling in golden form. A differential run already matched it.
- `ChordTransposer.normalize` uses chordsheetjs' default suffix normalization. The pipeline itself never normalizes suffixes.
