# Known divergences: CapoChordPro vs song-pipeline.ts

None of these occur in the goldens. They need integrator sign-off (PLAN §3, WP1).

1. **Repeat counts above `Int.max`.** `{sov: A, 1e20}` gives the web a count of `1e20`. `LyricsSegment.count` is an `Int`, so the Swift engine stores `Int.max`. This can't be fixed without changing the frozen render model.
2. **Fallback shape when the web pipeline throws.** rendered-song.tsx catches the error and shows the raw lyrics as pre-wrapped text, with no segments. `ChordProEngine.render` returns one `.normal` segment whose lines are the raw lyrics as `.text`. The visible text is the same, but there is no web HTML to compare this against. The engine throws in the same places the web does (unparseable ChordPro, `{key}` values that fail to parse, tag names that are `Object.prototype` members, `{meta}` without a value, out-of-range `SECTSTART` tokens, chords like `[do]` that crash chordsheetjs when transposed). A differential run of 48 edge inputs × 18 transpose/capo cases confirmed this.
3. **Unicode details nobody types in practice:**
   - Section names are matched with Swift `lowercased()`. JS `toLowerCase()` also handles final sigma in context.
   - Suffix and enharmonic lookups compare `String`s by canonical equivalence. JS compares code units.
