# Status and open items

Branch `feat/ios-p0-golden-fixtures` (based on production `origin/main`, no PR open). The app is pointed at production when built with `use-supabase.sh production`.

## Done

- Web-parity design system: 12 palettes, 12 bundled fonts (OFL), Geist Mono lyrics, 144 lucide icons (`CapoIcons`), type scale and radii.
- One shell for iPhone and iPad: slim top bar, bottom bar (Songs, Playlists, Chords, Teams), context pill, avatar menu.
- Songs: full-width sortable table, A-Z scrubber, Select mode, filters, group-by, All/Personal/team context; pushed song page.
- Playlists: table and pushed detail page, draft cart, setlist performance.
- Editor (Wrap toolbar, ChordPro reference, CifraClub import), Chords glossary and analyzer (guitar only, chord hand), Teams (cards, 80-icon picker, transfer song), Settings.
- Sidebar-tap crash fixed (`CapoTheme.adaptive` colors are pre-resolved and `@Sendable`).
- Production Google login works (`capo://auth/callback` is in the Redirect URLs).

## Open

| Item | Notes |
|---|---|
| Sign in with Apple | Release blocker (App Store 4.8); see `HUMAN_TODO.md` |
| Account deletion | Debug-only until approved; it is permanent on production |
| Web bug: column toggle overwrites `profiles.preferences` | `features/songs/api/user-preferences-api.ts:93`; not fixed |
| Web inconsistency: BPM filter 100/140 vs badges/help 90/120 | iOS follows the web filter; decide which is right |
| Settings is a sheet on iPad | Web uses a side nav |
| Language switch needs a restart | |
| CifraClub import untested live | 403 from the dev machine |
| Manual device checks | `VERIFICATION.md`, items 1-15 |
| Landscape, dark mode, Stage Manager | Not visually verified |
| CI and PR | Needs a macOS runner with Xcode 26; open the PR when ready |
| 6 API-token commits on local `main` | Not part of this branch |
