# Web vs iOS design parity

Date: 2026-10-25. Scope: visual language and shared components (not behaviour; that lives in
`GAP_ANALYSIS.md`). Sources compared: `app/globals.css`, `components/ui/*`, `features/*/components`
versus `ios/Packages/CapoUI/Sources/CapoDesign` and `CapoIcons`.

Status legend: SYNC (matches), FIXED (drift found and fixed in this change), DIVERGENT (intentional,
native idiom), FOLLOW-UP (drift inside a feature screen owned by another work package, numbered in
section 5).

## 1. Guards that keep the two in sync

| What | Guard | State |
|---|---|---|
| Colour tokens, 12 palettes x light/dark (21 tokens each) | `ios/scripts/check-design-tokens.mjs` parses `app/globals.css` (oklch) and compares with `Generated/PaletteTables.swift` (tolerance 3/255 per channel for gamut mapping) | SYNC: 504 tokens |
| Radius scale (`--radius` 0.65rem, md = -2px, xl = +4px) | same script, against `CapoRadius` | SYNC |
| Palette table generation | `ios/scripts/gen-palettes.mjs --check` (from `WEB_PARITY_ANALYSIS.md` 5.4) | SYNC |
| Lucide icon set | `ios/scripts/gen-icons.mjs --check` (every icon imported by the web, plus the team icon picker) | SYNC |
| Copy (en/es) | `ios/scripts/gen-i18n.mjs --check`; iOS reads the web's `lib/i18n/locales/*.json` plus `ios/i18n/ios.*.json` | SYNC (1020 keys) |
| Component metrics | `PaletteTests.buttonSizesFollowTheWebVariants`, `radiiFollowTheWebScale`, `tabletScaleStartsAt768` | SYNC |

Run `node ios/scripts/check-design-tokens.mjs` after touching `app/globals.css` or regenerating
palettes; it is also called from `ios/scripts/test-packages.sh`.

Note on the three PaletteTests dark-mode failures reported earlier: `CapoDesignTests` passes in full on
current `main` and the token guard shows no colour drift, so there is no token error behind them; they
were not reproducible here (likely simulator dynamic-colour resolution).

## 2. Tokens

| Area | Web | iOS | Status |
|---|---|---|---|
| Colours | oklch custom properties per palette, `:root` / `.dark` | rendered sRGB hex tables, resolved per interface style (`CapoTheme.token`) | SYNC (guard) |
| Palettes | 12 (`html[data-palette]`) | 12, same ids and order, picker swatches from `palette-settings.tsx` | SYNC |
| Section accents | `--section-accent`, Rosé Pine overrides | `CapoPalette.sectionAccents` | SYNC for catppuccin and Rosé Pine overrides; other palettes inherit the default accents on both sides |
| Typography, UI | Geist (variable) plus 11 optional UI fonts | Geist + same 12 `CapoUIFont` families, bundled | SYNC |
| Typography, lyrics/chords | Geist Mono | `GeistMono-Regular/Bold`, editor now Geist Mono too | SYNC |
| Type scale | Tailwind `text-xs..4xl` with line heights, `html` 17px at >= 768px | `CapoTextSize` + `CapoScale` (1.0625 tablet) | SYNC |
| Radius | sm 6.4, md 8.4, lg 10.4, xl 14.4 | `CapoRadius` | SYNC (guard) |
| Spacing | Tailwind 4px grid | literal points in views, scaled by `capoUIScale` | SYNC by convention |
| Shadows | `shadow-xs` on outline buttons/inputs, `shadow-lg` toast | button and toast ok; fields lacked it | FIXED (`capoField`) |
| Dark-mode alpha rules | `dark:bg-input/30`, `dark:bg-destructive/60`, `dark:hover:bg-accent/50` | was missing | FIXED (below) |

## 3. Shared components (`components/ui` vs CapoDesign)

| Web | iOS | Status | Notes |
|---|---|---|---|
| `button` default | `CapoPrimaryButtonStyle` | SYNC | h-9, hover /90 as pressed 0.9, disabled 0.5 |
| `button` outline | `CapoSecondaryButtonStyle` | FIXED | dark fill is now `input/30` (pressed `input/50`) |
| `button` destructive | `CapoDestructiveButtonStyle` | FIXED | dark fill is now `destructive/60` |
| `button` ghost | `CapoGhostButtonStyle` | FIXED (new) | transparent, pressed `accent` (`accent/50` dark) |
| `button` sizes xs/sm/default/lg | `CapoButtonSize` `.extraSmall/.small/.regular/.large` | FIXED | xs (h-6, px-2, text-xs) was missing |
| `button` secondary / link variants | none | FOLLOW-UP 9 | not used by an iOS screen yet |
| `button` icon sizes | `CapoIconButtonStyle` (44pt hit area) | DIVERGENT | touch target |
| `input`, `textarea` | `capoField()` modifier | FIXED (new) | border `input`, `dark:bg-input/30`, shadow-xs, radius md; screens still hand-roll the chrome (follow-up 1) |
| `badge` | `TagChip`, `FlagBadge`, ownership chip | SYNC | tag chips are colour-coded on both |
| `empty` | `EmptyStateView` | FIXED | now accepts a lucide `icon:`; the SF-Symbol init remains for unconverted screens (follow-up 2) |
| `sonner` toast | `capoToast` | SYNC | bottom-center, border, shadow-lg, 356 max width |
| `dialog`, `alert-dialog` | system `.alert` / `.confirmationDialog` | DIVERGENT | native |
| `sheet`, `drawer` | `.sheet` with detents | DIVERGENT | native; overlay is the system dimming (web uses black/80) |
| `dropdown-menu`, `select`, `popover` | `Menu`, `Picker` | DIVERGENT | native menus |
| `switch` | system `Toggle` tinted with `primary` | DIVERGENT | native control |
| `tabs` | segmented/tab bar | DIVERGENT | native |
| `skeleton`, `spinner` | `ProgressView` | DIVERGENT | no skeleton rows on iOS (data is local) |
| `avatar`, `breadcrumb`, `calendar` | `AsyncImage` initials, back button, `DatePicker` | DIVERGENT | native |

## 4. Screens

| Screen | Web | iOS | Status |
|---|---|---|---|
| Songs list | list rows with key/BPM/tags/played badges, bucket chip | table (regular) or two-line rows, same badges and chip | SYNC; iOS adds sort strip and A-Z index (GAP_ANALYSIS) |
| Song detail / editor | inline edit panel | full editor with Geist Mono source and preview | DIVERGENT (editor), SYNC (fonts, section colours) |
| Lyrics view | `rendered-song` columns, section accents, chord pills | `CapoRendering`, same accents, chord fill 12% | SYNC |
| Playlists list | cards with date/count/visibility pills | cards/table rows, same pills | SYNC |
| Playlist detail | header fields, songs, privacy/sharing, danger zone | same sections, wide two-column layout | SYNC |
| Draft dialog | dialog with songs, target select, name, Clear/Add | sheet with reorderable list and same actions | SYNC (copy shared); fields hand-rolled (follow-up 1) |
| Teams | cards with role badge, members, invitations | same | SYNC |
| Settings | cards for profile, theme, palette, font, language, chord hand | grouped cards, same palette/font pickers | SYNC; iOS adds sync section |
| Auth | login card with Google | auth screen with Google (+ debug email) | SYNC (Sign in with Apple pending, GAP-005) |
| Empty states | `Empty` with icon tile | `EmptyStateView` / `LibraryEmptyState` tile with tint | FIXED (lucide init), follow-up 2 for the rest; follow-up 4 for icons |
| Dialogs/sheets | radix dialog/drawer | native sheets | DIVERGENT |

## 5. Follow-ups inside other work packages' screens

1. Text fields: replace hand-rolled `TextField` chrome (`AddToPlaylistView.nameField`, playlist form,
   team forms, auth) with `.capoField()`. Owners: playlists, teams, auth/settings.
2. Empty states: switch the 14 `EmptyStateView(systemImage:)` call sites to the lucide `icon:` init
   (suggested: Music for songs, Lock for viewer notice, ListMusic for playlists, FolderX for "not
   found"). Owners: shell, playlists, editor, performance, teams.
3. System colours instead of tokens: `ConflictsView` (orange warnings, `.borderedProminent` /
   `.bordered` buttons) and `TagSheets` (`.red` error text) should use `CapoTheme.warning` /
   `destructive` and the Capo button styles.
4. SF Symbols still drawn with `Image(systemName:)` in teams (`TeamDetailView`), playlists
   (`PlaylistsView`, `PlaylistRow`, `SetlistPerformanceView`), performance (`LyricsHeader`,
   `StageComponents`, `SongQueueViews`, `FloatingControls`), auth and the editor: switch to
   `CapoIcon` where the web uses a lucide icon (the mapping is in `ICON_MAP.md`). Chord diagram and
   rendering glyphs are not affected.
5. Toolbar-style actions use `CapoSecondaryButtonStyle(size: .small)` (outline) in
   `PlaylistDetailView`, `LyricsHeader` and `SettingsView`; check against the web (outline vs ghost)
   screen by screen and use `CapoGhostButtonStyle` where the web is ghost.
6. Add `secondary` and `link` button variants when a screen needs them.
