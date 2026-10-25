## WP7a notes

### Structure (`ios/Packages/CapoUI/Sources/CapoRendering`)
- `LayoutMath.swift`: pure, nonisolated math (`LineWrapper`, `ChordLyricsArrangeMath`, `ColumnBalance`) under test with fixed sizes.
- `Layouts.swift`: `ChordLyricsLineLayout` and `BalancedColumnsLayout` (thin `Layout` wrappers over the math).
- `RenderParts.swift`: line, card, segment and header views. Context is passed explicitly (`RenderContext`), not via Environment.
- `ChordProContentView.swift`: public entry plus `RenderUnit` flattening.

### Deviations and decisions
- `SongRenderStyle` gained an additive `commentLabel` (default empty): `BodyLine.comment` carries no header text, so the caller passes the localized "Comment". Empty hides the card header.
- A `.normal` segment is split into column-atomic chunks after each blank line, so section-less songs can still balance across two columns. Sections, repeats and extends stay fully atomic.
- Two columns apply only at width >= 640pt (web switches to one column under 768px). No column rule is drawn.
- Section accent comes from `CapoDesign.SectionAccent`; chord colour outside sections is the web `--chord` (Catppuccin mauve) via `OKLCH.dynamic`.
- Chord tap: stacked chords use a tap gesture; inline chords use a `capochord://` link handled by a local `OpenURLAction`.
- "not found" text uses `String(localized: "chords.notFound", bundle: .capoDesign)` with `// TODO(i18n)`.
- Web auto-shrink-to-fit is not implemented (COULD).

### TODO
- Chord diagrams (WP14), column rule, Dynamic Type is intentionally ignored.
