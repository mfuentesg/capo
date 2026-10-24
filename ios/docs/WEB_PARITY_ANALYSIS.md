# Web parity analysis (web → native iPad/iPhone)

Source of truth: the web code in this worktree (`/Users/mfuentesg/code/capo/.claude/worktrees/ios-p0`, equal to production). Paths are relative to the repo root. The local-only API-tokens work is out of scope. Every number here comes from the code, not from screenshots.

Conventions used below:

- **px values**: Tailwind sizes are in `rem`. `app/globals.css:1566-1570` sets `html { font-size: 17px }` at `min-width: 768px`. So every rem value is **×1.0625 on tablet/desktop**. Where it matters, sizes are written as `phone px / tablet px` (for example, `text-sm` = 14 / 14.875 px). Breakpoints are not affected because media-query rem always uses 16 px: `sm` 640, `md` 768, `lg` 1024, `xl` 1280.
- **iPad mapping**: portrait 768–1023 pt uses the **md** layout (split panes and top nav shown, no `lg` paddings). Landscape 1024–1180+ uses the **lg** layout. Below 768 (iPhone, Slide Over) uses the **mobile** layout.

---

## 0. Executive summary: answers to the four complaints

| # | Complaint | Finding from the web code |
|---|---|---|
| 1 | "Ukulele is not supported on iOS" | **The web has no ukulele and no instrument concept at all.** It is guitar only: `@tombatossals/chords-db/lib/guitar.json`, the `chord-fingering` algorithmic fallback (`findGuitarChord`), standard EADGBE tuning and acoustic-guitar audio samples. The only diagram preference is **chord hand** (`right` or `left`, default `left`), which mirrors the diagram. iOS already bundles a ukulele table (`CapoRendering/Resources/chords.json`: 12 keys, 552 chords, 2114 positions). It is exposed only as a local `@State` toggle inside `ChordDiagramView`, resets to guitar on every open, and has no persisted setting. That is why it feels unsupported. iOS has no chord-hand setting at all. See §1. |
| 2 | "Icons don't match; the web has more options" | The web uses **lucide-react** throughout (about 120 distinct glyphs in the app, plus **80 selectable team icons** stored by lucide name in `teams.icon`). iOS uses SF Symbols that differ in several places (for example, `person.3` vs lucide `users` = 2 people, `music.note.list` used for both Songs and add-to-playlist, `chevron.left` vs `arrow-left`). Worst case: **iOS renders `team.icon` as literal text** (`TeamsView.swift:59`, `ContextPicker.swift:23`), so a web team with icon `"Guitar"` shows the word "Guitar". Full inventory and mapping in §2. Option sets iOS lacks (12 palettes, 12 UI fonts, chord hand, group-by, team icon picker and others) are in §3. |
| 3 | "Sidebar items crash" | Documentation only. **The web has no sidebar.** It has a sticky 64 px top navbar (Songs, Playlists, Chords, Teams, plus an icon-only Dashboard link that redirects to Songs), a context pill and an avatar menu (Settings, Invitations, Theme radio and Surprise me, Logout). On mobile there is a left drawer (w-64) with the context filter and the nav. Exact spec in §4. |
| 4 | "Fonts and design don't match" | Three root causes. (a) **Lyrics and chords render in Geist Mono on the web.** They sit in `<pre>`, and Tailwind preflight gives `pre` the mono font. iOS renders lyrics in Geist Regular (`CapoFont.lyrics`). (b) **iOS colours are the Catppuccin hex values from the CSS *comments*, not what the browser renders.** The CSS `oklch()` values differ, and in dark mode they are much darker. For example, the dark background renders as `#080916` on the web vs `#1e1e2e` on iOS, the dark card as `#171928` vs `#313244`, and the light primary as `#eb5100` vs `#fe640b`. (c) The web scales the whole UI ×1.0625 at ≥768 px and is user-themable (12 palettes × 12 fonts × light/dark/system). iOS has one fixed palette and one font. Full token tables in §5. |

---

## 1. Instruments, chord diagrams and chord data (complaint 1)

### 1.1 What the web supports

| Aspect | Web fact | Evidence |
|---|---|---|
| Instrument enum or type | **None.** There is no `instrument` type, setting, DB column or UI. | `grep -ri "ukulele\|instrument"` finds only a "future: instrument selection (piano, ukulele, etc.)" bullet in `docs/superpowers/specs/2026-05-18-chord-audio-design.md:93` (out of scope) and the ChordPro `piano` *dynamics flag* (soft). |
| Chord database | `@tombatossals/chords-db` **guitar.json only**. `ukulele.json` ships in node_modules but is never imported. | `features/lyrics-editor/components/chord-diagram.tsx:5`, `features/chords/utils/chord-db-helpers.ts:1` |
| Fallback fingerings | `chord-fingering` → `findGuitarChord(name)`. The result is shown with the subtitle **"Generated Diagram"**; DB hits show **"Verified Shape"** (hardcoded English). | `chord-diagram.tsx:19,280-289,233` |
| Base-chord fallback | If both fail, the slash bass is dropped and the base chord is looked up (`parseChord(..., {allowBaseFallback:true})`). | `chord-diagram.tsx:292-301` |
| Position validation | `isValidChordPosition` drops physically impossible barre shapes. | `features/chords/utils/chord-db-helpers.ts:94+` |
| Tuning | Standard E2 A2 D3 G3 B3 E4, MIDI `[40,45,50,55,59,64]` | `chord-diagram.tsx:77-78` |
| Diagram renderer | Custom SVG `components/chord-position-diagram.tsx`: string spacing 40, fret spacing 36, pads L36/T30/R16/B12, **4 frets, 6 strings**, dot r=12, viewBox 242×186. Nut is a 5 px rect at opacity .75 (non-nut 2 px at .25). Fret lines 0.75 px at opacity .25, string lines 0.75 px at opacity .15. Dots use currentColor at .85 with the finger number (11 px bold, white or zinc-950). Barre is a rounded 20 px-tall bar. X/O symbols at 1.5 px stroke (O r=7). The baseFret label is 14 px/700 with a 3 px halo. Fingers are auto-assigned by fret order when the DB has zeros. | `components/chord-position-diagram.tsx:9-303` |
| Chord hand (only diagram preference) | `"right" \| "left"`, **default `"left"`**. `mirror = chordHand === "left"`. With `mirror=true` the low-E string (index 0) is drawn on the **left** (conventional chart). With `right` the diagram is mirrored (low-E on the right). | `hooks/use-chord-orientation.ts`, `features/settings/contexts/chord-hand-context.tsx:6`, `chord-position-diagram.tsx:72` |
| Chord-hand persistence | DB `profiles.preferences.chordHand` via RPC `merge_user_preference`. Fallback cookie `NEXT_CHORD_HAND`, then default `left`. | `lib/actions/chord-hand.ts`, `app/(app)/layout.tsx:46-54` |
| Chord-hand UI | Settings → Appearance → "Chord diagrams" (`t.settings.chordHand`): a 2-column radio of cards (Right hand / Left hand) with a `Guitar` icon. The left card's icon is flipped `-scale-x-100`. Saving shows a spinner (`Loader2`) and then the toast "Saved". | `features/settings/components/chord-hand-settings.tsx` |
| Chord audio | Tone.js Sampler with acoustic-guitar mp3s (A2 A3 A4 C3 C4 C5 E2 E3 E4 G3 G4) from `nbrosowsky.github.io/tonejs-instruments/samples/guitar-acoustic/`. Note duration 1.5 s, "playing" indicator 1.5 s. The `Volume2` button sits next to the chord title. | `features/chord-audio/hooks/use-chord-audio.ts`, `features/chord-audio/components/chord-play-button.tsx` |
| Where diagrams appear | (1) Tap a chord in rendered lyrics → `Dialog` (full screen on phone, `sm:max-w-[450px]`). Title 36 px bold, subtitle 10–12 px uppercase tracking-widest, a card `bg-white dark:bg-zinc-950 rounded-2xl sm:rounded-3xl` with shadow `0 20px 50px rgba(0,0,0,.1)` (dark `.3`). Pager dots: active `w-6 h-1.5 bg-primary`, inactive `w-1.5 bg-muted-foreground/30`. Footer has 2 × 48 px buttons Previous/Next (Next in primary colour). Swipe threshold 40 px. Slide animation 0.25 s, 48 px. (2) The `/dashboard/chords` Glossary grid (2/3/4 columns) with a bottom `Sheet` detail (`chord-detail-sheet.tsx`). (3) The Analyzer (fretboard input, "Beta"). | `chord-diagram.tsx:215-298`, `features/chords/components/*` |
| No-diagram state | Dialog `sm:max-w-[400px]` with title (text-xl), a 48 px muted circle with the `Info` icon, and `t.chords.noDiagram`. | `chord-diagram.tsx:309-323` |

### 1.2 iOS today

| Aspect | iOS | Evidence |
|---|---|---|
| Instruments | `ChordInstrument { guitar, ukulele }`. A pill switch inside the diagram sheet uses `@State`, defaults to `.guitar` and is never persisted. | `CapoRendering/Diagrams/ChordDatabase.swift:3-6`, `ChordDiagramView.swift:83-166`, `SongPerformanceView.swift:140` (`ChordDiagramView(chordName:)` with no instrument passed) |
| Data | `chords.json`: guitar has 6 strings, 12 keys, 529 chords, 2067 positions. Ukulele has 4 strings, 12 keys, 552 chords, 2114 positions. Fingers are not stored (positions are `[baseFret, frets, barres]`). | `CapoRendering/Resources/chords.json` |
| Fallbacks | No algorithmic (`chord-fingering`) fallback and no base-chord fallback. Slash chords use the DB slash suffix only. Unknown chords show "not found". | `ChordDatabase.swift:47-54` |
| Chord hand | **Missing.** There is no mirror setting, and `UserPreferences.chordHand` is decoded but unused. | `CapoCore/Models/Preferences.swift:49` |
| Audio | **Missing** (no AVAudio or sampler). | grep |
| Glossary / Analyzer | **Missing** (no Chords section). | grep |

### 1.3 What iOS needs (recommendation)

1. **Decide the product scope.** Strict web parity means guitar only, plus chord hand. Ukulele is an iOS-only extension. If you keep it (the user asked for it), make it a real setting:
   - Add the preference key `chordInstrument: "guitar" | "ukulele"` to `profiles.preferences` and write it with `merge_user_preference` (same RPC the web uses for `chordHand`, `palette`, `uiFont`, `locale`, `theme`). The web's `mapJsonToPreferences` ignores unknown keys (`features/songs/api/user-preferences-api.ts:13-25`).
   - **Web bug that will wipe iOS-only keys:** the web `upsertUserPreferences` *replaces* the whole JSON with `{lyricsColumns, locale?, theme?}`. Its only caller is the column toggle in lyrics-view, and it passes only `lyricsColumns`, so the JSON becomes `{lyricsColumns}`. That wipes `chordHand`, `palette`, `uiFont`, `locale`, `theme` and any iOS key (`features/songs/api/user-preferences-api.ts:93-113`, `features/songs/hooks/use-user-preferences.ts:41-46`). Fix it on the web (use `merge_user_preference` for `lyricsColumns`) before relying on extra keys.
   - Add a Settings → Appearance → "Chord diagrams" control: instrument segmented (Guitar/Ukulele) plus hand (Right/Left) cards like the web.
   - Pass the persisted instrument into `ChordDiagramView` and keep the in-sheet switch as a temporary override.
2. **Port chord hand**: draw low-E/G-string on the left when `left` (default) and mirror when `right`. Persist it via `merge_user_preference` with key `chordHand`.
3. Match the diagram geometry to `components/chord-position-diagram.tsx` (4 frets, dot r 12 at spacing 40/36, finger numbers via auto-assign, barre bar, X/O glyphs, baseFret label on the left), and match the dialog layout in §1.1.
4. Optional parity: a port of the `chord-fingering` algorithmic fallback, the "Verified Shape / Generated Diagram" subtitle, chord audio, and the Chords glossary (search, key chips, grid) plus the Analyzer.

---

## 2. Icon inventory (lucide-react → SF Symbol) (complaint 2)

The web uses `lucide-react@0.562` everywhere (`components.json: "iconLibrary": "lucide"`). Default icon size inside `Button` is 16 px (`[&_svg]:size-4`). Icons inherit text colour and use a 2 px stroke (lucide default).

**Recommendation:** for real visual parity, bundle the used lucide SVGs (ISC licence) as template images in an asset catalog (`lucide.<name>`) and render them at the web sizes. SF Symbols differ in weight and metaphor. Use the SF column below only as a fallback. Entries marked **custom** have no acceptable SF equivalent.

### 2.1 Shell / navigation

| Web location | lucide | Size | Proposed SF Symbol |
|---|---|---|---|
| Navbar: Dashboard (icon only, `hideTitle`) | `LayoutDashboard` | 16 | `square.grid.2x2` (custom for exact shape) |
| Navbar/drawer: Songs | `Music` | 16 (drawer 20) | `music.note` (lucide `music` = beamed eighth pair → custom for exact) |
| Navbar/drawer: Playlists | `ListMusic` | 16 / 20 | `music.note.list` |
| Navbar/drawer: Chords | `Guitar` | 16 / 20 | `guitars` (two guitars) → **custom** single guitar |
| Navbar/drawer: Teams | `Users` | 16 / 20 | `person.2` (iOS uses `person.3`, which is wrong) |
| Mobile drawer trigger | `Menu` | 20 | `line.3.horizontal` |
| Context pill "All" | `Layers` | 14 (pill) / 16 (row) | `square.3.layers.3d` |
| Context pill personal / avatar fallback | `CircleUserRound` | 12–24 | `person.crop.circle` |
| Context pill caret | `ChevronDown` | 12 | `chevron.down` |
| Selected row check | `Check` | 14–16, primary colour | `checkmark` |
| Avatar menu: Settings | `Settings` | 16 | `gearshape` |
| Avatar menu: Invitations | `Mail` | 16 | `envelope` |
| Avatar menu: Logout (destructive red) | `LogOut` | 16 | `rectangle.portrait.and.arrow.right` |
| Theme radio | `Sun` / `Moon` / `Monitor` | 16 | `sun.max` / `moon` / `display` |
| Surprise me | `Sparkles` | 16 | `sparkles` |
| Language switcher (public navbar) | `Languages` | 16 | `translate` |
| Login back link | `ArrowLeft` | 14 | `arrow.left` |

### 2.2 Songs library and detail

| Web location | lucide | Size | Proposed SF Symbol |
|---|---|---|---|
| CifraClub import button / editor import | `Music4` | 16 | **custom** (nearest `music.quarternote.3`) |
| Add song | `Plus` | 16 | `plus` |
| Search field | `Search` | 16 | `magnifyingglass` |
| Clear search | `X` | 16 | `xmark` |
| Filters button | `Settings2` (sliders) | 16 | `slider.horizontal.3` |
| Filter: BPM section header | `Music2` | 16 | `music.note` |
| BPM Slow / Med / Fast (filter and badges) | `Turtle` / `Rabbit` / `Zap` | 14 (filter), 12 (badge) | `tortoise` / `hare` / `bolt` |
| Filter: Group by header | `LayoutList` | 16 | `list.bullet.rectangle` |
| Song row: cart toggle | `Plus` → `Check` | 16 in a 44 px circle | `plus` / `checkmark` |
| Song row: key badge | `Music2` | 12 | `music.note` |
| Song row: played-frequency badge | `Repeat` | 12 | `repeat` |
| Empty list | `Music` | 24 in a 40 px tile | `music.note` |
| Tag "add" chip / create tag | `Plus` / `Tag` | 12 | `plus` / `tag` |
| Tag delete in picker | `Trash2` | 12 | `trash` |
| Tag remove (×) | `X` | 10 | `xmark` |
| Song actions trigger | `MoreVertical` | 16 | `ellipsis` rotated 90° (or **custom**) |
| Edit details | `Pencil` | 16 | `pencil` |
| Edit lyrics | `FileEdit` | 16 | `square.and.pencil` |
| Transfer to team | `ArrowRightFromLine` | 16 | **custom** (nearest `arrow.right.to.line`) |
| Delete song | `Trash2` | 16 | `trash` |
| Detail-panel placeholder watermark | `Music` | 45% of the panel at 4% opacity | `music.note` |

### 2.3 Lyrics / performance view (`features/lyrics-editor/components/lyrics-view.tsx`)

| Web location | lucide | Size | Proposed SF Symbol |
|---|---|---|---|
| Back (page mode) / Close (panel mode) | `ArrowLeft` / `X` | 16 | `arrow.left` / `xmark` |
| Edit lyrics | `Pencil` | 16 | `pencil` |
| Share lyrics | `Share2` (three connected nodes) | 16 | `square.and.arrow.up` (platform idiom). Exact glyph: `point.3.connected.trianglepath.dotted` |
| ChordPro reference | `BookOpen` | 16 | `book` |
| Editing: preview toggle | `Eye` ↔ `Pencil` | 16 | `eye` / `pencil` |
| Editing: parse chords (chord-over-lyrics → ChordPro) | `Wand2` | 16 | `wand.and.stars` |
| Editing: CifraClub import | `Music4` | 16 | custom |
| Editing: Done | `Check` | 14 | `checkmark` |
| Save status | `Loader2` (spin) / `Check` / `AlertCircle` | 12 | `ProgressView` / `checkmark` / `exclamationmark.circle` |
| Header BPM badge | `Turtle` / `Rabbit` / `Zap` | 12 | `tortoise` / `hare` / `bolt` |
| Settings popover trigger (with ping dot when modified) | `Settings2` | 14 | `slider.horizontal.3` |
| Font size | `Type` | 16 / 14 | `textformat.size` |
| Transpose | `Music2` | 16 / 14 | `music.note` |
| Capo | `Guitar` | 16 / 14 | custom guitar |
| Column layout | `Columns2` | 16 | `rectangle.split.2x1` |
| Visibility (chords/lyrics) | `Eye`, `Guitar`, `Type` | 16 / 14 | `eye`, custom, `textformat` |
| Step buttons | `Minus` / `Plus` | 16 (popover), 14 (auto-scroll) | `minus` / `plus` |
| Auto-scroll | `Play` / `Pause` | 14 | `play.fill` / `pause.fill` |
| Playlist prev/next song | `ChevronUp` / `ChevronDown` | 16 | `chevron.up` / `chevron.down` |
| Active-setting chips (×) | `Music2` / `Guitar` / `Type` + `X` | 12 / 10 | as above + `xmark` |
| Section collapse chevron | `ChevronDown` (rotates −90° collapsed, 150 ms) | 14 | `chevron.down` |
| `{repeat}` section icon | `Repeat2` | 12, section accent | `repeat` |
| `{extend}` section icon | `Layers` | 12, section accent | `square.3.layers.3d` |
| Empty lyrics | `Music2` | 32 in a 64 px muted circle | `music.note` |
| Chord dialog | `ChevronLeft`/`ChevronRight`, `Info`, `Volume2`, `Loader2` | 16 / 24 | `chevron.left`/`chevron.right`, `info.circle`, `speaker.wave.2`, ProgressView |
| ChordPro reference copy | `Copy` → `Check` | 12 | `doc.on.doc` / `checkmark` |

### 2.4 Playlists, draft cart, sharing

| Web location | lucide | Size | Proposed SF Symbol |
|---|---|---|---|
| Playlist row tile | `Music3` | 20 in a 40 px rounded-xl tile | `music.note` |
| Row meta: date / count | `Calendar` / `Music3` | 12 | `calendar` / `music.note` |
| Private / public / guest-edit | `Lock` / `Globe` / `Users` | 12 | `lock` / `globe` / `person.2` |
| Archived badge / archive button | `Archive` | 10 / 16 | `archivebox` |
| Unarchive | `ArchiveRestore` | 14 | **custom** (nearest `arrow.uturn.backward` + `archivebox`) |
| Create playlist | `Plus` | 16 | `plus` |
| Create-form header | `ListMusic` | 20 | `music.note.list` |
| Suggest name | `Sparkles` (pulse while loading) | 16 | `sparkles` |
| Date picker | `Calendar` | 14–16 | `calendar` |
| Detail: song count chip | `ListMusic` | 14 | `music.note.list` |
| Copy share link / open | `Copy` / `ExternalLink` | 12 | `doc.on.doc` / `arrow.up.right.square` |
| Add songs | `Plus` | 14 | `plus` |
| Drag handle | `GripVertical` (6 dots) | 16 at 40% opacity | `line.3.horizontal` (idiom) or **custom** 6-dot grip |
| Remove song from playlist | `X` | 16 (hover destructive) | `xmark` |
| Delete playlist | `Trash2` | 14 | `trash` |
| Add-songs sheet | `Search`, `Music2`, `Settings2` | 16 | `magnifyingglass`, `music.note`, `slider.horizontal.3` |
| Draft FAB / draft dialog title | `ListMusic` | 16 / 20 | `music.note.list` |
| Draft item | `GripVertical`, `Music2`, `Repeat`, `X` | 16 / 12 | as above |
| Shared view chips | `Link`, `Globe`, `CalendarDays`, `Share2`, `Settings` | 12–16 | `link`, `globe`, `calendar`, `square.and.arrow.up`, `gearshape` |
| Shared playlist not found | `Music2` | — | `music.note` |

### 2.5 Teams, invitations, settings, chords, auth

| Web location | lucide | Size | Proposed SF Symbol |
|---|---|---|---|
| Teams header: Invitations / Create team | `Mail` / `Plus` | 16 | `envelope` / `plus` |
| Teams search | `Search`, `X` | 16 | `magnifyingglass`, `xmark` |
| Team card member count | `Users` | 16 | `person.2` |
| Team card leave / delete | `LogOut` / `Trash2` | 16 (destructive) | `rectangle.portrait.and.arrow.right` / `trash` |
| Team detail back / edit / save | `ArrowLeft` / `Pencil` / `Check` | 16 / 10 / 20 | `arrow.left` / `pencil` / `checkmark` |
| Members: header / add member | `Users` / `UserPlus` | 20 / 16 | `person.2` / `person.badge.plus` |
| Member role button | `Shield` + `ChevronDown` | 16 / 12 | `shield` + `chevron.down` |
| Member more / remove | `MoreVertical` / `Trash2` | 16 | `ellipsis` (rotated) / `trash` |
| Invitations: pending / invited-on / copy link / cancel / resend | `Mail` / `Clock` / `Copy` / `Trash2` / `RefreshCw` | 16 / 12 | `envelope` / `clock` / `doc.on.doc` / `trash` / `arrow.clockwise` |
| Danger zone: transfer / leave / delete | `ArrowLeftRight` / `LogOut` / `Trash2` | 16 | `arrow.left.arrow.right` / `rectangle.portrait.and.arrow.right` / `trash` |
| Role icons | owner `UserLock`, admin `KeyRound`, member `User`, viewer `UserSearch` | 12 in badge | `person.badge.key` / `key` / `person` / **custom** (nearest `person.crop.circle.badge.questionmark`) |
| Invitations page | `Mail`, `CheckCircle`, `Clock`, `AlertCircle`, `ArrowLeft` | — | `envelope`, `checkmark.circle`, `clock`, `exclamationmark.circle`, `arrow.left` |
| Accept invitation | `CheckCircle` / `XCircle` / `AlertCircle` | — | `checkmark.circle` / `xmark.circle` / `exclamationmark.circle` |
| Settings nav | `User` (Profile), `Palette` (Appearance), `ShieldAlert` (Account) | 16 | `person`, `paintpalette`, `exclamationmark.shield` |
| Profile "Connected via" chip | `KeyRound` | 12 | `key` |
| Theme cards | `Sun` / `Moon` / `Monitor` | 20 | `sun.max` / `moon` / `display` |
| Chord-hand cards | `Guitar` (flipped for left) | 20 | custom guitar, mirrored |
| Palette "Surprise me" | `Sparkles` | 14 | `sparkles` |
| Chords tabs | `BookOpen` (Glossary), `ScanSearch` (Analyzer, "Beta") | 16 | `book`, `text.viewfinder` |
| Analyzer reset | `RotateCcw` | — | `arrow.counterclockwise` |
| Login feature dots | `Music`, `FileText`, `ListMusic`, `Users`, `Share2`, `Guitar` (blue/violet/primary/green/pink/amber at 10% bg) | 12 | `music.note`, `doc.text`, `music.note.list`, `person.2`, `square.and.arrow.up`, custom |
| Feedback (landing only) | `CheckCircle`, `Loader2` | — | `checkmark.circle`, ProgressView |

### 2.6 Team icon picker: the 80 selectable icons (`components/ui/icon-picker.tsx`)

The value is stored as the **lucide component name** in `teams.icon` (string). Default/fallback is `"Users"`. The picker is a popover `w-[min(35rem,100vw-1rem)]`, scroll area `h-72 sm:h-120`, grid 6 columns (sm: 8), gap 8/12 px, 48 px ghost buttons with 24 px icons, selected `bg-accent`. The trigger is a round `bg-primary/10 border p-2` with a 24 px icon. `TeamIcon` renders 20 px by default. **iOS must map these names to images; today it prints the string.**

| Group | lucide name → SF fallback |
|---|---|
| Music & audio (14) | Music→`music.note`, Music2→`music.note`, Music3→`music.note`, Music4→`music.quarternote.3`, Mic→`mic`, Mic2→`music.mic`, Guitar→custom, Drum→custom, Piano→`pianokeys`, Headphones→`headphones`, Radio→`radio`, Disc→`opticaldisc`, Disc3→`opticaldisc.fill`, Album→custom |
| People (4) | Users→`person.2`, Users2→`person.2`, User→`person`, UserCircle→`person.crop.circle` |
| Achievement (7) | Star→`star`, Trophy→`trophy`, Award→`rosette`, Medal→`medal`, Crown→`crown`, Target→`target`, CheckCircle2→`checkmark.circle` |
| Energy (7) | Heart→`heart`, Zap→`bolt`, Flame→`flame`, Sparkles→`sparkles`, Sparkle→`sparkle`, Rocket→custom, Lightbulb→`lightbulb` |
| Protection (3) | Shield→`shield`, ShieldCheck→`checkmark.shield`, Sword→custom |
| Precious (3) | Gem→custom, Diamond→`diamond`, Gift→`gift` |
| Organization (9) | LayoutGrid→`square.grid.2x2`, Settings→`gearshape`, Settings2→`slider.horizontal.3`, Briefcase→`briefcase`, Book→`book.closed`, BookOpen→`book`, Calendar→`calendar`, Clock→`clock`, Bell→`bell` |
| Places (8) | Globe→`globe`, Globe2→`globe.americas`, MapPin→`mappin`, Compass→`safari`, Mountain→`mountain.2`, Home→`house`, Building→`building`, Building2→`building.2` |
| Nature (7) | Sun→`sun.max`, Moon→`moon`, Cloud→`cloud`, CloudRain→`cloud.rain`, Leaf→`leaf`, Flower2→`camera.macro`, Waves→`water.waves` |
| Hobbies (6) | Coffee→`cup.and.saucer`, Palette→`paintpalette`, Camera→`camera`, Film→`film`, Gamepad2→`gamecontroller`, Puzzle→`puzzlepiece` |
| Maritime (3) | Anchor→custom, Ship→`ferry`, Umbrella→`umbrella` |
| Fun (6) | Smile→`face.smiling`, Ghost→custom, Cat→`cat`, Dog→`dog`, Bird→`bird`, Fish→`fish` |
| Status (3) | Lock→`lock`, Flag→`flag`, AlertCircle→`exclamationmark.circle` |

---

## 3. Selectable option sets the web exposes (complaint 2)

| Option set | Values (default **bold**) | Persistence | Web source | iOS today |
|---|---|---|---|---|
| Theme | light, dark, **system** | `preferences.theme` (merge RPC) + cookie `NEXT_THEME` + localStorage | `lib/display-preferences.ts`, `theme-settings.tsx`, `theme-menu-item.tsx` | Picker present (Settings) |
| Colour palette | **catppuccin**, aura, nord, rose-pine, dracula, one-dark-pro, tokyo-night, gruvbox, monokai, night-owl, horizon, shades-of-purple (labels/descs in `palette-settings.tsx:72-85`) | `preferences.palette` + cookie `NEXT_PALETTE` | `lib/palette.ts`, `app/globals.css:421-1175` | **Missing** (Catppuccin only, and with wrong hexes) |
| UI font | **geist**, inter, dm-sans, roboto, poppins, nunito, outfit, plus-jakarta-sans, montserrat, lato, space-grotesk, manrope | `preferences.uiFont` + cookie `NEXT_UI_FONT` | `lib/font.ts`, `app/layout.tsx:28-109`, `globals.css:1183-1225` | **Missing** (Geist only; 4 weights + Mono 2 weights bundled) |
| Surprise me | random other palette + font (avatar menu version also flips light/dark) | — | `palette-settings.tsx:229`, `profile-menu-actions.tsx:21-33` | Missing |
| Language | **en** (English 🇬🇧), es (Español 🇪🇸) | `preferences.locale` + cookie `NEXT_LOCALE` | `lib/i18n/config.ts`, `language-settings.tsx` | Present |
| Chord diagram hand | right, **left** | `preferences.chordHand` + cookie | §1 | **Missing** |
| Instrument | guitar only (no setting) | — | §1 | guitar/ukulele, sheet-local |
| Chord notation | English letters only, accidentals as authored. No Latin/solfège/German/Nashville. Transposition keeps suffix spelling (`normalizeChordSuffix:false`). | — | `song-pipeline.ts:118-123`, `lib/music-theory.ts` | English only (match) |
| Song key list | 38 keys: C C# Db D D# Eb E F F# Gb G G# Ab A A# Bb B Cb Fb, plus the same 19 minors (`m`) | `songs.key` | `lib/constants.ts` (`MUSICAL_KEYS`), `key-select.tsx` | check `CapoCore` key list |
| Transpose | −6 … +6, step 1, display `+n` | `user_song_settings.transpose` | `use-lyrics-settings.ts` | `transposeRange -6...6` (match) |
| Capo | 0 … 12 ("None" / "Fret n") | `user_song_settings.capo` | same | `0...12` (match) |
| Lyrics font scale | 0.5 … 3.0, step 0.25, default 1, shown `1.00` / chip `1.25×` | `user_song_settings.font_size` | same | match |
| Lyrics columns | 1, 2 (DB default **2**; songs-panel default 1; song page and playlist sheet use the DB value) | `preferences.lyricsColumns` | `lyrics-view.tsx:151`, `user-preferences-api.ts:15` | present |
| Visibility | show chords on/off, show lyrics on/off (session only) | none | `lyrics-view.tsx:152-153` | present (`showChords`) |
| Auto-scroll speed | 10 … 300 px/s, step 10. Default inferred: `scrollableHeight / (nonDirectiveLines × 4 beats / (bpm/60))`, fallback 30 | none | `lyrics-view.tsx:56-60,319-352` | present (verify formula) |
| BPM filter | all, slow, medium, fast. **Filter thresholds: slow <100, medium 100–140, fast >140.** The description text says "<90 • 90-120 • >120". Badge icon: <90 turtle, ≤120 rabbit, else zap. Badge colour: <90 muted, ≤130 activity-green, >130 rose. The web is internally inconsistent. | none | `song-list.tsx:52-60`, `song-item.tsx:131-138`, `lib/badge-colors.ts` | 90/120 buckets |
| Group by | **none**, key, artist (`bucket` exists in the type but is not exposed). Sticky group headers: uppercase xs semibold tracking-wider muted + `(count)`, groups sorted `localeCompare`. | none | `songs-client.tsx:478-504`, `song-list.tsx` | **Missing** |
| Tag filter | multi-select, AND semantics (`every`) | none | `song-list.tsx:56-58` | present |
| Song sort | **None on the web** (server order; search is server-side, debounced 300 ms) | — | `use-songs.ts` | iOS adds recent/title/artist/relevance (extra) |
| Song status filter | none on the web | — | — | iOS adds published/draft (extra) |
| Tag colours | 8 presets `#ef4444 #f97316 #eab308 #22c55e #06b6d4 #3b82f6 #8b5cf6 #ec4899`. New-tag default `#3b82f6`, fallback `#6b7280`. | `tags.color` | `tag-selector.tsx:17-26,51` | verify |
| Playlist visibility filter | **all**, public, private | none | `playlists-client.tsx:100` | verify |
| Playlist visibility | **private**, public. Guest editing only when public; turning public off also clears guest editing. | `playlists.visibility`, `allow_guest_editing` | `playlist-detail.tsx:386-392` | present |
| Playlist archive | archive / unarchive (row button + detail card) | `playlists.archived_at` | `playlist-item.tsx`, `playlist-detail.tsx` | present |
| View filter (context) | **all** (only shown when the user has teams), personal, team:<id> | cookie/DB (`features/app-context`) | `context-pill.tsx` | present (ContextPicker) |
| Creation bucket | personal / team (BucketSelector in create forms) | — | `features/app-context/components/bucket-selector.tsx` | verify |
| Section types (render) | verse, chorus, bridge, tab, grid, intro, outro, pre_chorus, comment, comment-label, repeat, extend, volta, box | — | `song-pipeline.ts`, `rendered-song.tsx` | present |
| Section flags | attention `!`, skip, forte `f` (italic), piano `p` (italic), vamp, tag, break (inline/label hidden) | — | `rendered-song.tsx:27-50` | present (`FlagBadge`) |
| Wrap-selection toolbar | Verse (sov), Pre-Chorus (sopc), Chorus (soc), Bridge (sob), Intro (soi), Outro (soo). Auto-numbers "Verse 2". | — | `utils/section-wrap.ts`, `section-wrap-toolbar.tsx` | **Missing** |
| Team roles | owner (UserLock), admin (KeyRound), member (User), viewer (UserSearch). Invite dialog offers member, admin, viewer. Owner assigns admin/member/viewer; admin assigns member/viewer. | `team_members.role` | `features/teams/constants.ts` | roles present; icons differ |
| Team icon | 80 lucide names (§2.6) | `teams.icon` | `icon-picker.tsx` | **free-text emoji field** |
| Share | (1) share lyrics: system share sheet or clipboard, text = `Title - Artist\n\n` + ChordPro stripped of `{}`. Chords-only and lyrics-only variants follow the visibility toggles. (2) Playlist public link `/shared/{shareCode}` copy and open. (3) Shared view "Share". | — | `lyrics-view.tsx:62-91,248-269` | playlist share present; lyric share variants: verify |
| Auth providers | Google (active). GitHub and email magic link shown **disabled** with a "Coming soon" chip. | — | `features/auth/components/login-form.tsx` | Google + email/password (extra) |

---

## 4. Navigation: exact web shell (complaint 3)

**There is no sidebar on the web.** `app/(app)/dashboard/layout.tsx` renders `<Navbar/>` + page + `<DraftIndicator/>` over two fixed gradient orbs: a top-right 600 px circle `oklch(0.793 0.132 56 / 12%)` and a bottom-left 500 px circle `oklch(0.749 0.160 298 / 10%)`, both radial and fading to transparent at 70%.

### 4.1 Top navbar (`components/layout/navbar.tsx`)

- `header`: sticky top-0 z-50, full width, `border-b border-border/40`, `bg-background`. At lg: `bg-background/80 backdrop-blur-sm` (8 px).
- Row: height **h-16 = 64 / 68 px**. Padding `px-4` (16), `sm:px-6` (24), `lg:px-8` (32/34).
- Left to right:
  1. Mobile drawer trigger (<md only): ghost icon button 36 px, `Menu` 20 px, `mr-2`.
  2. Logo link → `/dashboard`: `capo-text` image 80×24, `dark:invert`, `mr-6` (lg `mr-8`).
  3. Nav (md+): `gap-1`, items as `Button` with `rounded-full gap-2`, size default (h-9, px-3 with icon), text-sm font-medium, icon 16 px. **Active = `variant="secondary"`** (bg-secondary, text-secondary-foreground) + font-medium. Inactive = ghost (hover bg-accent; dark hover accent/50).
     Order: **Dashboard** (`LayoutDashboard`, icon only, `exact`, `/dashboard`; that route redirects to `/dashboard/songs` so it is never active) → **Songs** `/dashboard/songs` (`Music`) → **Playlists** `/dashboard/playlists` (`ListMusic`) → **Chords** `/dashboard/chords` (`Guitar`) → **Teams** `/dashboard/teams` (`Users`). Active match: exact path or `startsWith(href + "/")`.
  4. Right cluster `ml-auto gap-1 sm:gap-2`: **ContextPill**, then **UserProfileMenu**.
- Labels en/es: Dashboard/Panel, Songs/Canciones, Playlists/Playlists, Chords/Acordes, Teams/Equipos.
- No badges or counts in the nav.

### 4.2 Context pill (`components/layout/context-pill.tsx`)

- Trigger: ghost sm button, `h-8 rounded-full px-2.5 gap-1.5`. When filtered (not "all"): `bg-accent/60 hover:bg-accent/80`. Then `ChevronDown` 12 px muted.
- Trigger content:
  - all + has teams: AvatarGroup of 2 × 20 px (user avatar or `CircleUserRound`; first team avatar or TeamIcon) + "All".
  - all + no teams: `Layers` 14 px + "All".
  - personal: 20 px avatar + display name (truncate max-w 80 px, sm 120 px, text-xs medium).
  - team: 20 px team avatar (fallback TeamIcon 12 px on `bg-primary/20`, rounded) + team name (same truncation).
- Popover `w-64 p-2`, align end:
  - Caption "Filter view" (`text-xs font-semibold text-muted-foreground px-2 py-1`).
  - Rows: `rounded-md px-2 py-2 gap-3`, hover bg-accent, selected `bg-accent` + `Check` 16 px primary after the name.
    - **All** (only if teams exist): 32 px circle `bg-primary/10` with `Layers` 16 + title "All" + subtitle "Songs and playlists from all buckets".
    - **Personal**: 32 px avatar + name + subtitle "Your personal account".
    - **Each team**: 32 px avatar/TeamIcon + name.
  - Footer: `border-t mt-1 pt-1`, ghost sm full-width left-aligned "Manage teams" → `/dashboard/teams`.

### 4.3 Avatar menu (`user-profile-menu.tsx`, `user-profile-header.tsx`, `profile-menu-actions.tsx`, `theme-menu-item.tsx`)

- Trigger: 36 px round avatar with `ring-2 ring-background`, fallback `CircleUserRound` 20 px on `bg-primary/10`.
- Dropdown `w-72` (288/306 px), align end:
  1. Header `p-3 border-b`: 40 px avatar, name (text-sm semibold) + optional full name (xs muted) + email (xs muted).
  2. Group: **Settings** (`Settings`) → `/dashboard/settings`; **Invitations** (`Mail`) → `/dashboard/invitations`.
  3. Separator. **Theme** row: label "Theme" (muted, flex-1) + 3 × 28 px radio icons Sun/Moon/Monitor (active `bg-primary/10 text-primary`, inactive muted with hover bg-muted) + 1 px divider + **Surprise me** (`Sparkles`, `active:scale-90`).
  4. Separator. **Logout** (`LogOut`, text-destructive); shows "Loading..." while pending.

### 4.4 Mobile drawer (<768) (`mobile-nav-drawer.tsx`)

- vaul Drawer `direction="left"`, content `w-64` (256 px), overlay black/50, 250 ms.
- Header: logo 80×27.
- "Filter view" caption (`text-xs font-bold uppercase tracking-widest muted`), then compact rows `px-2 py-1.5 gap-2` with 16/20 px icons and a 14 px `Check`: All (if teams) / Personal / teams. Inline, no popover.
- `border-t`, then vertical nav `mt-2 gap-2 px-3`: same 5 items, now **with the Dashboard title**, `w-full justify-start gap-3`, icons 20 px, active = secondary.

### 4.5 Shared (public) navbar (`shared-navbar.tsx`)

Same chrome. Signed-in: drawer + Songs/Playlists/Teams only + avatar menu. Signed-out: ThemeToggle (sun/moon rotate) + LanguageSwitcher (`Languages` + locale code) + "Login" button.

### 4.6 Routes

| Route | Screen |
|---|---|
| `/` (public) | Landing (`components/landing-page.tsx`), includes the feedback form |
| `/login` | Login (`components/login-page-content.tsx` + `features/auth/components/login-form.tsx`) |
| `/dashboard` | redirect → `/dashboard/songs` |
| `/dashboard/songs` | Library split view |
| `/dashboard/songs/[id]` (`?edit=true`) | Full-page lyrics view / editor |
| `/dashboard/playlists` | Playlists split view |
| `/dashboard/chords` | Chords: Glossary / Analyzer (Beta) tabs |
| `/dashboard/teams`, `/teams/new`, `/teams/[id]` | Teams grid, create, detail |
| `/dashboard/invitations` | Pending invitations |
| `/dashboard/settings` | Settings |
| `/shared/[shareCode]` | Public playlist |
| `/teams/accept-invitation` | Accept invite |

### 4.7 Mapping to the iOS regular-width sidebar

iOS currently has Library / Setlists / Teams / Conflicts / Settings (`CapoShellUI/MainShellView.swift:352-356`). To match the web, use labels and icons **Songs (`music`), Playlists (`list-music`), Chords (`guitar`), Teams (`users`)**. Keep Conflicts as an iOS-only item. Move Settings and Invitations plus Theme / Surprise / Sign out into an avatar/user menu in the sidebar footer. Put the context pill at the top (the web pill is in the header). Active item = `secondary` fill + medium weight. The web's active colour is **not** primary; iOS uses a peach `selection` fill with a primary icon. The web has no collapsed/rail state, so the iOS 84 pt rail is an iOS addition.

---

## 5. Design system (complaint 4)

### 5.1 Fonts actually loaded (`app/layout.tsx`)

| Family | Source | Weights | CSS var |
|---|---|---|---|
| **Geist** (default UI) | local `app/fonts/GeistVF.woff2` | variable 100–900 | `--font-geist-sans` → `--font-sans` |
| **Geist Mono** | local `app/fonts/GeistMonoVF.woff2` | variable 100–900 | `--font-geist-mono` → `--font-mono` |
| Inter, DM Sans, Nunito, Outfit, Plus Jakarta Sans, Montserrat, Space Grotesk, Manrope | `next/font/google` | variable/default | `--font-<name>` |
| Roboto | google | 300 400 500 700 | `--font-roboto` |
| Poppins | google | 300 400 500 600 700 | `--font-poppins` |
| Lato | google | 300 400 700 | `--font-lato` |

- The selected UI font is applied as `html[data-font=X] { font-family: var(--font-X), ui-sans-serif, system-ui }` (`globals.css:1183-1225`). Geist is the default when there is no `data-font` rule.
- **Lyrics, chords, the ChordPro editor and `<code>` use Geist Mono.** Rendered lyrics are `<pre class="chordsheet-content">`, and Tailwind preflight sets `pre { font-family: var(--font-mono) }` (`node_modules/tailwindcss/preflight.css:109-121`). The user's UI-font choice does **not** change lyrics. The editor theme hardcodes `fontFamily: var(--font-geist-mono)` at 16 px with line-height 1.6 (`song-editor-impl.tsx`).
- iOS bundles Geist Regular/Medium/SemiBold/Bold and GeistMono Regular/Bold. It is **missing Geist Mono for lyrics** (it uses Geist-Regular) and **missing the 11 alternative UI fonts**. For iOS: use the variable TTFs or add SemiBold/Medium Mono if needed. The web uses weights 400/500/600/700 for UI and 400/700 for mono.
- `body` has `antialiased`. NextTopLoader colour `#f97316` (orange-500), no spinner.

### 5.2 Type scale (Tailwind v4 defaults; rem × 16 or 17)

| Class | Size (phone/tablet px) | Line height | Used for |
|---|---|---|---|
| `text-[9px]` | 9 | — | flag badges (bold uppercase tracking-wide), avatar fallback text |
| `text-[10px]` | 10 | — | ownership chips, archived badge, "Beta"/"Coming soon" chips, palette/font card descriptions, chord dialog subtitle (sm+) |
| `text-[11px]` | 11 | — | tag badges, active-setting chips, tag-picker text, login divider |
| `text-[12px]` | 12 | — | **section header label** (bold, uppercase, `tracking-[0.18em]`, section-accent colour), ChordPro reference |
| `text-xs` | 12 / 12.75 | 16 / 17 (1.333) | badges, metadata, captions, helper text |
| `text-sm` | 14 / 14.875 | 20 / 21.25 (1.4286) | body default in lists/forms, buttons, inputs (md+) |
| `text-base` | 16 / 17 | 1.5 | section titles in settings (semibold/bold), lyrics header song title (semibold), inputs (<md) |
| `text-lg` | 18 / 19.125 | 1.556 | detail-panel titles (bold tracking-tight), empty titles (medium), dialog title (semibold) |
| `text-xl` | 20 / 21.25 | 1.4 | page titles on phone (Songs/Playlists bold tracking-tight), login title |
| `text-2xl` | 24 / 25.5 | 1.333 | page titles at lg (Songs/Playlists), Teams title (phone), chords title, team-detail name, card title |
| `text-3xl` | 30 / 31.875 | 1.2 | Settings title, Invitations title, chord sheet title, chords title (sm+) |
| `text-4xl` | 36 / 38.25 | 1.111 | Teams title (sm+), chord dialog title |

Tracking: `tracking-tight` −0.025em (all headings), `tracking-wider` 0.05em, `tracking-widest` 0.1em (uppercase micro-headings such as "TRANSPOSE", "DETAILS", "SONGS"). Leading: `leading-none` 1, `leading-tight` 1.25, `leading-snug` 1.375, `leading-relaxed` 1.625. Weights: 400 normal, 500 medium (buttons, labels), 600 semibold, 700 bold (titles, song titles in rows).

**Lyrics typography** (`globals.css:1236-1293`, `rendered-song.tsx`):

- Font: Geist Mono. Size `16px × fontScale × autoFit`. This is px, so it is *not* affected by the 17 px root. `line-height: 1.6`, `white-space: pre-wrap`.
- Auto-fit: shrinks the scale until no chord/lyric row overflows its block, and resets on resize.
- Chords: `.chord` bold. Stacked layout (`.clp-col .chord`): colour `var(--chord)`, background `color-mix(--chord 12%)`, radius 3 px, padding 0 3 px, margin 0 1 px. Hover background 22%.
- Inside a section, chords take the **section accent** instead of `--chord`: colour accent, background accent 12%.
- Inline-flag sections render chords inline as plain bold text (no badge) followed by a space.
- Columns: `.multi-column-lyrics` uses `column-width: 400px; column-gap: 3rem; column-rule: 1px solid var(--border)`, with `columnCount` 1 or 2 set inline. At ≤768 px it is forced to a single column with no rule.

### 5.3 Spacing, radius, shadow

- Spacing unit: `--spacing: 0.25rem` → 4 px (phone) / 4.25 px (tablet). Common: gap-1 4, gap-1.5 6, gap-2 8, gap-3 12, p-3 12, p-4 16, p-6 24, p-8 32, space-y-6 24.
- Radius: `--radius: 0.65rem` (10.4 / 11.05 px). `rounded-sm` = r−4 (6.4/7.05), `rounded-md` = r−2 (8.4/9.05: buttons, inputs, menu items), `rounded-lg` = r (10.4/11.05: cards, alerts, dialogs sm+), `rounded-xl` = r+4 (14.4/15.05: song/playlist rows, settings cards, option cards), `rounded-2xl` = 1rem (16/17: settings panel, danger zones, floating control bars), `rounded-3xl` = 1.5rem (fancy dialog sm+), `rounded-full` (pills, nav items, context pill, avatars, step buttons, badges). Hard-coded: chord badge 3 px, comment/volta/box/label blocks 6 px, flag badges `rounded` 4 px.
- Shadows: `shadow-xs` `0 1px 2px rgb(0 0 0/.05)` (outline buttons, inputs, switch); `shadow-sm` `0 1px 3px rgb(0 0 0/.1), 0 1px 2px -1px rgb(0 0 0/.1)` (cards, rows); `shadow-md` `0 4px 6px -1px /.1, 0 2px 4px -2px /.1` (popover, dropdown, hovered/selected rows); `shadow-lg` `0 10px 15px -3px /.1, 0 4px 6px -4px /.1` (dialogs, floating controls, FAB, toasts); `shadow-2xl` `0 25px 50px -12px /.25` (fancy dialog, login card).
- Borders: 1 px `var(--border)` everywhere (`* { border-color: var(--border) }`). Focus ring is 3 px `ring/50`. Detail panels have a **2 px top border in the feature accent** (`border-t-2 border-accent-songs` / `border-accent-playlists`).
- Hover-lift on rows: `hover:shadow-md hover:-translate-y-px`.

### 5.4 Colour tokens

**Important:** the hex values in the CSS comments (official Catppuccin and others) are *not* what renders. Browsers paint the `oklch()` values. The tables below are the rendered sRGB values, computed with the same OKLCH→sRGB matrix as `CapoDesign/OKLCH.swift` and validated against known reference colours. Values marked `*` are inherited from the catppuccin `:root`/`.dark` because the palette does not override them (all `chart-*` tokens). Best approach for iOS: store the `oklch` triplets and convert with the existing `OKLCH` type.

Catppuccin (default) with OKLCH source, light → dark:

| Token | Light (rendered) | Dark (rendered) | iOS today (light / dark) |
|---|---|---|---|
| background | `#e3e4ea` oklch(.920 .008 281) | `#080916` oklch(.148 .028 277) | `#e6e9ef` / **`#1e1e2e`** |
| foreground | `#393c4d` (.360 .030 278) | `#c5ceec` (.855 .042 272) | `#4c4f69` / `#cdd6f4` |
| card / popover | `#ededf2` (.948 .006 287) | `#171928` (.220 .028 277) | `#eff1f5` / **`#313244`** |
| primary | `#eb5100` (.638 .205 42) | `#fca463` (.793 .132 56) | **`#fe640b`** / `#fab387` |
| primary-foreground | `#ededf2` | `#080916` | onPrimary always `#1e1e2e` (**wrong in light**) |
| secondary / accent | `#c8c9d0` (.838 .010 279) | `#2a2c3c` (.298 .030 278) | `surface #ccd0da` / `#313244` |
| muted | `#c8c9d0` | `#171928` (= card) | — |
| muted-foreground | `#5a5c6d` (.480 .027 278) | `#7983a1` (.612 .048 272) | `subtext #6c6f85` / `#9399b2` |
| destructive | `#b30037` (.465 .222 12) | `#f5789d` (.727 .158 3) | `#d20f39` / `#f38ba8` |
| border / input | `#b6b8bf` (.782 .011 276) | `#2a2c3c` (.298 .030 278) | `#bcc0cc` / `#45475a` |
| ring | = primary | = primary | — |
| chord | `#750fe3` (.495 .265 295) | `#bb95ff` (.749 .160 298) | `#8839ef` / `#cba6f7` |
| accent-songs | `#0057d8` (.495 .215 258) | `#70adff` (.742 .139 257) | `info #1e66f5` / `#89b4fa` |
| accent-playlists | `#750fe3` | `#bb95ff` | — |
| accent-activity | `#1f9240` (.580 .155 148) | `#92e9aa` (.862 .121 152) | `success #40a02b` / `#a6e3a1` |
| chart-1…5 | `#eb5100 #750fe3 #0057d8 #1f9240 #b30037` | `#fca463 #bb95ff #70adff #92e9aa #f5789d` | — |
| sidebar (unused by the web layout) | `#dadbe2` | `#04050f` | `#dce0e8` / `#181825` |

All 12 palettes, rendered:

#### Light mode (rendered sRGB hex)

| token | catppuccin | aura | nord | rose-pine | dracula | one-dark-pro | tokyo-night | gruvbox | monokai | night-owl | horizon | shades-of-purple |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `background` | #e3e4ea | #f1f2ff | #e9f0f7 | #fcecdd | #f7f7f2 | #f3f5f8 | #dfe0e7 | #fff7d3 | #f8f8f8 | #f9f9f9 | #ffece7 | #f2f0ff |
| `foreground` | #393c4d | #09071a | #132331 | #413e69 | #19172b | #232b34 | #222747 | #2c2725 | #13130f | #322f43 | #0b0b13 | #251347 |
| `card` | #ededf2 | #e8e8ff | #dee8f1 | #fff8ef | #fbfaf6 | #e9edf2 | #d4d6df | #fffbdf | #eeede7 | #eff0f3 | #fff4f1 | #eae8ff |
| `popover` | #ededf2 | #e8e8ff | #dee8f1 | #fff9ed | #fbfaf6 | #e9edf2 | #d4d6df | #fffbdf | #eeede7 | #eff0f3 | #fff4f1 | #eae8ff |
| `primary` | #eb5100 | #673ad0 | #3d75a2 | #a2507a | #7a59c3 | #0076b3 | #2d46a1 | #b01f00 | #d10073 | #266ed4 | #d32579 | #673ad0 |
| `primary-foreground` | #ededf2 | #f1f2ff | #e9f0f7 | #fff1e3 | #f7f7f2 | #f3f5f8 | #dfe0e7 | #fff7d3 | #f8f8f8 | #f9f9f9 | #fff4f1 | #f2f0ff |
| `secondary` | #c8c9d0 | #dbdbf5 | #cdd9e2 | #f4e2d6 | #dedeed | #dadee5 | #ced0da | #e9d6b3 | #e2e1db | #e3e3e9 | #f9dcd8 | #dedcf9 |
| `muted` | #c8c9d0 | #dbdbf5 | #dee8f1 | #f4e2d6 | #e6e7f2 | #e1e5ea | #cfd1da | #f2e3c1 | #e9e8e2 | #e8e9ee | #fae4e0 | #e3e1fd |
| `muted-foreground` | #5a5c6d | #59567b | #344f69 | #6a658a | #4e5d90 | #5a6472 | #595e7d | #72655b | #73624e | #8a92a0 | #5a5977 | #5c5681 |
| `accent` | #c8c9d0 | #dbdbf5 | #cdd9e2 | #f4e2d6 | #dedeed | #dadee5 | #ced0da | #e9d6b3 | #e2e1db | #e3e3e9 | #f9dcd8 | #dedcf9 |
| `destructive` | #b30037 | #b30037 | #ab4f55 | #a2507a | #d73240 | #be425f | #c13e5e | #8e0000 | #d10073 | #c02635 | #d32579 | #c60072 |
| `border` | #b6b8bf | #b8b6e9 | #cdd9e2 | #e1d2ca | #cecee3 | #cbd1d8 | #c5c7d1 | #ccbca0 | #d2d1c8 | #d2d4dd | #dfcbc9 | #cfcbf1 |
| `input` | #b6b8bf | #b8b6e9 | #cdd9e2 | #e1d2ca | #cecee3 | #cbd1d8 | #c5c7d1 | #ccbca0 | #d2d1c8 | #d2d4dd | #dfcbc9 | #cfcbf1 |
| `ring` | #eb5100 | #673ad0 | #3d75a2 | #a2507a | #7a59c3 | #0076b3 | #2d46a1 | #b01f00 | #d10073 | #266ed4 | #d32579 | #673ad0 |
| `chord` | #750fe3 | #673ad0 | #3d75a2 | #7a6ca5 | #7a59c3 | #905ec3 | #926fd3 | #297256 | #7a4ac4 | #7636b9 | #8e47c1 | #673ad0 |
| `accent-songs` | #0057d8 | #0085a0 | #3d75a2 | #3d899d | #7bdbef | #0076b3 | #2d46a1 | #64a09f | #d10073 | #266ed4 | #d32579 | #673ad0 |
| `accent-playlists` | #750fe3 | #673ad0 | #846a98 | #7a6ca5 | #d665cf | #905ec3 | #926fd3 | #7c3066 | #7a4ac4 | #7636b9 | #8e47c1 | #bd217f |
| `accent-activity` | #1f9240 | #008960 | #6e9869 | #006583 | #41ef71 | #62ae5a | #4a9c42 | #787700 | #68a700 | #1d8c9c | #008d52 | #008b89 |
| `chart-1` | #eb5100 | #eb5100* | #eb5100* | #eb5100* | #eb5100* | #eb5100* | #eb5100* | #eb5100* | #eb5100* | #eb5100* | #eb5100* | #eb5100* |
| `chart-2` | #750fe3 | #750fe3* | #750fe3* | #750fe3* | #750fe3* | #750fe3* | #750fe3* | #750fe3* | #750fe3* | #750fe3* | #750fe3* | #750fe3* |
| `chart-3` | #0057d8 | #0057d8* | #0057d8* | #0057d8* | #0057d8* | #0057d8* | #0057d8* | #0057d8* | #0057d8* | #0057d8* | #0057d8* | #0057d8* |
| `chart-4` | #1f9240 | #1f9240* | #1f9240* | #1f9240* | #1f9240* | #1f9240* | #1f9240* | #1f9240* | #1f9240* | #1f9240* | #1f9240* | #1f9240* |
| `chart-5` | #b30037 | #b30037* | #b30037* | #b30037* | #b30037* | #b30037* | #b30037* | #b30037* | #b30037* | #b30037* | #b30037* | #b30037* |
| `sidebar` | #dadbe2 | #e7e7ff | #d8e1e8 | #f7e8dd | #ececfa | #e6eaef | #d5d7e0 | #f8eccb | #f3f2ec | #f3f3f7 | #fee8e4 | #edebff |
| `sidebar-accent` | #c8c9d0 | #dbdbf5 | #cdd9e2 | #f4e2d6 | #dedeed | #dadee5 | #ced0da | #e9d6b3 | #e2e1db | #e3e3e9 | #f9dcd8 | #dedcf9 |
| `sidebar-border` | #b6b8bf | #b8b6e9 | #c5d1dc | #e1d2ca | #cecee3 | #cbd1d8 | #c5c7d1 | #ccbca0 | #d2d1c8 | #d2d4dd | #dfcbc9 | #cfcbf1 |

#### Dark mode (rendered sRGB hex)

| token | catppuccin | aura | nord | rose-pine | dracula | one-dark-pro | tokyo-night | gruvbox | monokai | night-owl | horizon | shades-of-purple |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `background` | #080916 | #09071a | #132331 | #120c22 | #19172b | #141a24 | #0b091e | #161616 | #13130f | #000b1b | #0b0b13 | #251347 |
| `foreground` | #c5ceec | #ececf2 | #e9f0f7 | #dad8ef | #f7f7f2 | #9fa7b1 | #b6bde5 | #e9d6b3 | #f6f5f1 | #cfd9e4 | #c3c5d2 | #c8ccf4 |
| `card` | #171928 | #100e23 | #1f3245 | #1a132b | #0e0c1b | #0d131a | #16172c | #110e0c | #252520 | #01162d | #12121d | #15072f |
| `popover` | #171928 | #100e23 | #1f3245 | #1a132b | #0e0c1b | #0d131a | #16172c | #110e0c | #252520 | #01162d | #12121d | #15072f |
| `primary` | #fca463 | #9d67ff | #79bccd | #e2699d | #b995ff | #25b2e8 | #729bf8 | #fd7920 | #f2009d | #9de05f | #ed428e | #ffd304 |
| `primary-foreground` | #080916 | #09071a | #132331 | #120c22 | #19172b | #141a24 | #0b091e | #161616 | #13130f | #000b1b | #0b0b13 | #251347 |
| `secondary` | #2a2c3c | #1b1931 | #2b4258 | #231b38 | #37374e | #2d353f | #1c1f34 | #423b37 | #31302b | #0b223a | #1b1b26 | #36265d |
| `muted` | #171928 | #141328 | #1f3245 | #1a132b | #27263b | #0d131a | #16172c | #2c2725 | #252520 | #01162d | #12121d | #251347 |
| `muted-foreground` | #7983a1 | #7b76a8 | #6299c0 | #847fa7 | #4e5d90 | #4d555f | #4b5075 | #8a7e75 | #73624e | #456c78 | #5a597a | #7375ac |
| `accent` | #2a2c3c | #1b1931 | #2b4258 | #231b38 | #37374e | #2d353f | #1c1f34 | #423b37 | #31302b | #0b223a | #1b1b26 | #36265d |
| `destructive` | #f5789d | #df7aff | #ca6b70 | #e2699d | #ff4e58 | #ea5979 | #f86786 | #f12a31 | #f2009d | #ff3e73 | #ed428e | #ff43a1 |
| `border` | #2a2c3c | #252043 | #2b4258 | #3a3250 | #37374e | #2d353f | #1c1f34 | #423b37 | #31302b | #0b223a | #1b1b26 | #36265d |
| `input` | #2a2c3c | #252043 | #2b4258 | #3a3250 | #37374e | #2d353f | #1c1f34 | #423b37 | #31302b | #0b223a | #1b1b26 | #36265d |
| `ring` | #fca463 | #9d67ff | #79bccd | #e2699d | #b995ff | #25b2e8 | #729bf8 | #fd7920 | #f2009d | #9de05f | #ed428e | #ffd304 |
| `chord` | #bb95ff | #00f9bd | #79bccd | #b7a1f5 | #ed6de5 | #a86ee3 | #b690ff | #67c78c | #ad83ff | #b88dff | #ab61e2 | #8e51e6 |
| `accent-songs` | #70adff | #38e7f7 | #6299c0 | #8cd3e4 | #8deeff | #25b2e8 | #729bf8 | #64a09f | #88dff3 | #63a5ff | #ed428e | #63dcc3 |
| `accent-playlists` | #bb95ff | #df7aff | #a98bbf | #b7a1f5 | #ed6de5 | #a86ee3 | #b690ff | #be7ca1 | #ad83ff | #b88dff | #ab61e2 | #8e51e6 |
| `accent-activity` | #92e9aa | #00f9bd | #8bbb85 | #ffb84a | #53ff7f | #7bcb72 | #7cd573 | #a0c224 | #a0df00 | #9de05f | #2affb3 | #ffd304 |
| `chart-1` | #fca463 | #fca463* | #fca463* | #fca463* | #fca463* | #fca463* | #fca463* | #fca463* | #fca463* | #fca463* | #fca463* | #fca463* |
| `chart-2` | #bb95ff | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* | #bb95ff* |
| `chart-3` | #70adff | #70adff* | #70adff* | #70adff* | #70adff* | #70adff* | #70adff* | #70adff* | #70adff* | #70adff* | #70adff* | #70adff* |
| `chart-4` | #92e9aa | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* | #92e9aa* |
| `chart-5` | #f5789d | #f5789d* | #f5789d* | #f5789d* | #f5789d* | #f5789d* | #f5789d* | #f5789d* | #f5789d* | #f5789d* | #f5789d* | #f5789d* |
| `sidebar` | #04050f | #050412 | #0d1925 | #0a0617 | #100f1e | #090f16 | #060515 | #100d0b | #0c0b08 | #000511 | #07070d | #180935 |
| `sidebar-accent` | #171928 | #141328 | #1f3245 | #1a132b | #27263b | #0d131a | #16172c | #2c2725 | #252520 | #01162d | #12121d | #251347 |
| `sidebar-border` | #171928 | #141328 | #1f3245 | #1a132b | #27263b | #0d131a | #16172c | #2c2725 | #252520 | #01162d | #12121d | #251347 |

Other hard-coded colours used by components:

| Use | Value |
|---|---|
| Performance note `{note:}` | italic, 0.82em, opacity .88, light `oklch(.58 .13 65)` = `#ae6700`, dark `oklch(.78 .12 65)` = `#eca760`, wrapped as `( text )` |
| Comment / label / box blocks | `--comment-color` light `#008687` (.55 .12 195), dark `#00afaf` (.68 .12 195). Block: 1 px border at 28%, background 6%, radius 6, margin 6 px 0. Label: 0.68em/700/tracking .12em uppercase, padding 3×10, background 12%, bottom border 22%. Body: 0.85em, padding 5/10/7. Inside a section, box/volta take the section accent. |
| Section block | `.section-repeat-content`: **2 px left border** in the accent, `pl-4` (16 px), padding-top 8 px, bottom 10 px, right 16 px, radius `0 r r 0`, background accent **6% (light) / 12% (dark)**. Header: dot 6 px with a 2 px card ring + 4 px accent-25% ring, gap 10 px, `mb-3`; chevron only on hover. `space-y-6` (24 px) between segments. |
| Not-found repeat/extend | opacity .5, label "`Name` (not found)" |
| Flag badges (`FLAG_CONFIG`) | attention amber-100/amber-700 (dark amber-900/40, amber-400); forte red-100/red-700 italic; piano blue-100/blue-700 italic; vamp purple-100/purple-700; tag green-100/green-700; skip/break muted. All 9 px bold uppercase, `px-1 py-0.5 rounded`. |
| Key badge | text accent-songs, background 10%, border 30%, Geist Mono `font-mono text-xs`, `Music2` 12 px (`lib/badge-colors.ts`) |
| BPM badge | <90 muted (`bg-muted border-border`), ≤130 accent-activity (10% bg / 30% border), >130 `text-rose-600 dark:text-rose-400 bg-rose-500/10 border-rose-500/30` (rose-600 `#ec003f`, rose-400 `#ff637e`, rose-500 `#ff2056`) |
| Frequency badge | recently played: `text-amber-600 dark:text-amber-400 bg-amber-500/10 border-amber-500/30` (`#e17100` / `#ffb900` / `#fe9a00`); otherwise muted |
| Tag badge | colour = tag colour, background mix 18%, border mix 30%, 11 px, prefix "#" at opacity .6 |
| Bucket colours (view = All) | personal = accent-activity; team *i* cycles `[accent-songs, accent-playlists, chart-1..5]` by team index. Chip: 10 px medium, colour, background 15%, `rounded-full px-2 py-0.5`, team icon 12 px or a 6 px dot (`features/songs/utils/bucket-colors.ts`) |
| Active-setting chips (lyrics header) | transpose `bg-blue-500/10 text-blue-600 dark:text-blue-400`, capo `violet-500/10 violet-600/violet-400`, font `amber-500/10 amber-600/amber-500`; 11 px medium `rounded-full px-2 py-0.5` + `X` 10 px |
| Preview (new song) row | `rounded-xl border-2 border-orange-500 dark:border-orange-600 bg-orange-100/50 dark:bg-orange-900/20 shadow-lg` |
| Chord diagram card | `bg-white` / dark `bg-zinc-950` (`#09090b`), `border-border/50` |
| Overlays | dialog `bg-black/80`; alert-dialog, sheet and drawer `bg-black/50` |
| Page orbs | songs: primary/5 + blue-500/5 blur 100; playlists: violet-500/5 + primary/5; teams: green-500/5 + primary/5 |

Tailwind v4 colours referenced (rendered): blue-400 `#51a2ff`, blue-500 `#2b7fff`, blue-600 `#155dfc`; violet-400 `#a684ff`, violet-500 `#8e51ff`, violet-600 `#7f22fe`; amber-400 `#ffb900`, amber-500 `#fe9a00`, amber-600 `#e17100`; green-500 `#00c950`, green-600 `#00a63e`; orange-500 `#ff6900`; pink-500 `#f6339a`; zinc-950 `#09090b`.

### 5.5 Component variants (`components/ui/*`, shadcn "new-york")

| Component | Spec |
|---|---|
| Button | base `rounded-md text-sm font-medium gap-2`, svg 16, disabled opacity .5, transition. **Variants:** default `bg-primary text-primary-foreground hover:/90`; destructive `bg-destructive text-white` (dark bg destructive/60); outline `border bg-background shadow-xs hover:bg-accent` (dark `bg-input/30 border-input`); secondary `bg-secondary hover:/80`; ghost `hover:bg-accent` (dark accent/50); link `text-primary underline-offset-4`. **Sizes:** default h-9 px-4 (icon px-3); xs h-6 px-2 text-xs svg 12; sm h-8 px-3 (icon 2.5); lg h-10 px-6; icon 36; icon-xs 24; icon-sm 32; icon-lg 40. Pills via `rounded-full`. Press feedback `active:scale-[0.98]` on many CTAs, `active:scale-90` on small round buttons. |
| Badge | `rounded-full border px-2 py-0.5 text-xs font-medium gap-1`, svg 12. default primary; secondary `bg-secondary`; destructive; outline `text-foreground`. |
| Input | h-9, `rounded-md border border-input bg-transparent px-3 py-1`, text-base (md: text-sm), shadow-xs, dark `bg-input/30`, placeholder muted, focus border-ring + 3 px ring/50. Search fields add `pl-9 bg-muted/50` with a 16 px icon at left-3. |
| Textarea | min-h-16, px-3 py-2, same styling |
| Select trigger | `rounded-md border px-3 py-2 text-sm`, h-9 (sm h-8), chevron muted. Items `rounded-sm py-1.5 pl-2 pr-8 text-sm` with a check. Key select content max-h-75. |
| Card | `rounded-lg border bg-card shadow-sm`; title text-2xl semibold tracking-tight; description text-sm muted |
| Dialog | overlay black/80. Content `max-w-lg p-6 gap-4 border bg-background shadow-lg sm:rounded-lg`, zoom 95 + fade 200 ms. Close X at top-4 right-4 (opacity .7). `fancy`: `p-0 border-none shadow-2xl sm:rounded-3xl` + primary/8 gradient + round 32 px close button. Header `space-y-1.5`, title text-lg semibold, description text-sm muted. |
| AlertDialog | overlay black/50, `max-w-[calc(100%-2rem)] sm:max-w-lg rounded-lg border p-6 shadow-lg`, title text-lg semibold, footer actions (destructive action variant) |
| Sheet | overlay black/50. Sides: bottom/top `h-auto border-t/b`; left/right `w-3/4 sm:max-w-sm`; open 500 ms, close 300 ms. Song/playlist detail on mobile = bottom sheet `h-dvh p-0 rounded-none` without a close button. Playlist lyrics = **top** sheet h-dvh. |
| Drawer (vaul) | overlay black/50, bottom: `rounded-t-lg max-h-[80vh]` + 100×8 px muted handle; left/right `w-3/4 sm:max-w-sm`; duration forced to 250 ms |
| Dropdown menu | `min-w-[8rem] rounded-md border p-1 shadow-md bg-popover`; item `rounded-sm px-2 py-1.5 text-sm gap-2`, focus bg-accent, svg 16 muted; destructive item red with 10% focus bg; separator `-mx-1 my-1 h-px bg-border`; label `px-2 py-1.5 text-sm font-medium` |
| Popover | `w-72 rounded-md border p-4 shadow-md bg-popover` (filters `w-80 max-h-125`, lyrics settings `w-auto side=top align=end`) |
| Tabs | list `bg-muted h-9 rounded-lg p-[3px]`; trigger `rounded-md px-2 py-1 text-sm font-medium`, active `bg-background shadow-sm` (dark `bg-input/30 border-input text-foreground`), inactive dark muted |
| Switch | track 32×18.4 (`w-8 h-[1.15rem]`), checked bg-primary, unchecked bg-input (dark input/80); thumb 16 px bg-background (dark unchecked foreground, checked primary-foreground) |
| Tooltip | `bg-foreground text-background rounded-md px-3 py-1.5 text-xs` + rotated 10 px arrow |
| Avatar | 32 px round default, fallback `bg-muted` (most usages `bg-primary/10`) |
| Empty | `gap-6 p-6 md:p-12 rounded-lg border-dashed text-center`; media icon tile `size-10 rounded-lg bg-muted` svg 24 (songs: `bg-blue-500/10 text-blue-500 ring-1 ring-blue-500/20`; playlists: accent-playlists 10% + ring 20%); title text-lg medium tracking-tight; description text-sm/relaxed muted |
| Skeleton | `bg-accent animate-pulse rounded-md` |
| Separator | 1 px bg-border |
| Toast (sonner) | **bottom-center**, `bg-background border-border shadow-lg`, action button primary, cancel muted; mobile insets 16 px |
| Resizable handle | 1 px `bg-border` line, grip `h-4 w-3 rounded-xs border bg-border` with GripVertical 10 px |
| Option card (settings) | `rounded-xl border px-3 py-4 text-sm font-medium flex-col gap-2`, active `border-primary/60 bg-primary/8 text-primary shadow-sm` + **4×16 px primary bar at bottom-1.5 centred**; inactive `border-border bg-muted/40 text-muted-foreground hover:bg-muted`; `active:scale-[0.97]` |
| SaveStatus | inline xs: saving (Loader2 spin, muted) / saved (Check, muted) / error (AlertCircle, destructive) |

### 5.6 Layout metrics

| Item | Value |
|---|---|
| Navbar height | 64 / 68 px (h-16), sticky |
| Content area (songs/playlists) | `h-[calc(100dvh-4rem)]`, overflow hidden |
| Split panes (md+) | list default **35%**, min 25%, max 50%; detail default **65%**, min 40%; draggable handle (`react-resizable-panels`). Below md, the detail panel is hidden and the list is 100% (`globals.css:1580-1583`). |
| List header | `p-4 lg:p-6`, border-b; title row stacked on phone (`flex-col gap-3`), row on sm+; search row `mt-4` |
| List body | songs `p-4 space-y-3`, group gap `mb-6`; playlists `p-2 space-y-2` |
| Detail header (lyrics panel) | sticky, `bg-card border-b px-4 pt-2 pb-1`: row 1 = 32 px back/close + title; row 2 = artist · key badge · BPM badge + actions (36 px icons); row 3 = tags + active-setting chips |
| Lyrics body | `px-4 py-8`, inner `max-w-5xl mx-auto`; page mode adds `container mx-auto` |
| Floating controls | `fixed bottom-6 right-4` (24/16 px) bar `rounded-2xl border bg-background px-2 py-1.5 shadow-lg`, 32 px buttons; playlist prev/next bar at bottom-6 left-4 with `n/total` |
| Draft FAB | `fixed bottom-6 right-4 sm:right-6`, h-12 rounded-full pl-3 pr-4 shadow-lg, count bubble 24 px `bg-primary-foreground/20` |
| Mobile nav drawer | 256 px |
| Settings | `max-w-4xl px-4 py-8`; nav column `w-44` (176/187 px) on sm+, horizontal pills on phone; content card `rounded-2xl border bg-card p-6 shadow-sm` |
| Teams | `max-w-7xl p-4 sm:p-6 lg:p-8 space-y-6`, grid `sm:grid-cols-2 gap-4` |
| Team detail | `max-w-4xl` |
| Invitations | `max-w-2xl` |
| Chords | `max-w-5xl px-4 py-6 sm:px-6 lg:px-8`; glossary grid 2 → 3 (sm) → 4 (lg) |
| Shared playlist | `max-w-2xl px-4 pt-8 pb-20` |
| Login card | `max-w-sm`, card `rounded-2xl border-border/50 bg-card/80 p-6 shadow-2xl backdrop-blur-sm` |

---

## 6. Screen-by-screen

### 6.1 Songs library (`features/songs/components/songs-client.tsx`, `song-list.tsx`, `song-item.tsx`)

- **Layout (md+):** split view, list | handle | detail. **Mobile:** list full width; selecting opens a full-height bottom Sheet containing the same detail (or the create form).
- **Header:** "Songs" (`text-xl lg:text-2xl bold tracking-tight`) + "· N" (text-sm muted tabular-nums). Actions: outline sm pill **CifraClub** (`Music4`, label `t.songs.cifraImport.button`), default sm pill **Add song** (`Plus`). On phone both are `flex-1`. Both are disabled while creating.
- **Search:** debounced 300 ms, server-side; clear X.
- **Filters popover** (outline sm button `Settings2` + "Filters" label on sm+, count badge 20 px round primary): header "Filters" + description + "Clear all" (ghost h-7 xs) → BPM range 4-column grid (All/Slow/Med/Fast with icons; selected = default variant, others outline) + help text → Group by 3-column (None/By Key/By Artist) → Tags (wrap of TagBadges, selected `ring-2 ring-ring ring-offset-1`).
- **Row (`SongItem`):** `rounded-xl p-3 gap-3 shadow-sm bg-card`. Hover lift. Selected `bg-accent-songs/8 ring-2 ring-accent-songs/50 shadow-md`. Disabled opacity .5.
  - Left 44 px round **cart toggle**: `bg-accent-songs/12 text-accent-songs` with `Plus`, or in cart `bg-accent-playlists text-white` with `Check`, `active:scale-90`.
  - Title text-sm bold truncate. Artist text-xs muted. Ownership chip only in "All" view.
  - Badges row (gap-1.5, wrap): key badge (mono), BPM badge, frequency badge (`n× · last played`), tags.
- **Group headers:** sticky, `bg-background py-2 mb-3`.
- **States:**
  - Loading: 8 skeleton cards (40 px circle + 2 lines + 2 chips).
  - Empty: Empty block (Music, "No songs", "Try a different search").
  - Preview row while creating: orange bordered card at the top.
- **Detail placeholder (nothing selected):** `bg-card`, huge `Music` watermark (45%, 4% opacity), bottom-left: 2 px × 32 px accent-songs bar, "Select a song" (lg bold), description (sm muted, max-w-xs).
- **Detail:** `SongLyricsPanel` = `LyricsView mode="panel" readOnly` with `SongActionsMenu` (⋮: Edit details, Edit lyrics → `/dashboard/songs/{id}?edit=true`, Transfer to team (personal + has teams), separator, Delete (red, confirm AlertDialog)). Panel mode has **no auto-scroll** (only the settings button in the floating bar). Loading = skeleton lines.
- **Create (`SongDraftForm`):** header "Create song" + subtitle; fields Title, Artist, Key (select of 38) + BPM (placeholder 120) side by side, Bucket selector, info Alert, Save/Cancel.
- **CifraClub dialog:** URL input. Errors: invalid URL, unsupported host, network, parse failed, rate limited, unknown. Modes "create" and "replace-lyrics".

### 6.2 Lyrics / performance (`lyrics-view.tsx`, `rendered-song.tsx`, page `/dashboard/songs/[id]`)

- **Header (sticky, bg-card):** see §5.6. Actions when not editing: Edit (if editable), Share, ChordPro reference (page mode only), then the actions slot. When editing: SaveStatus, Preview/Edit toggle (secondary when previewing), Parse chords (`Wand2`), CifraClub import, Reference, outline "Done" (`Check`).
- **Tag row:** TagSelector (selected tags with ×, dashed "+ Add tag" chip h-6 → popover w-64 with search/create input h-7, list max-h-48 with colour dot, check and hover trash, create section with 8 colour swatches) + active-setting chips.
- **Display settings popover** (top, end): "Display settings" + description; Font size (−, `Type` + value `1.00`, +, Reset); Transpose (−, `Music2` + `+n semitones`, +, Reset); Capo (−, `Guitar` + `None/Fret n`, +, Reset); Column layout (1 column / 2 columns); Visibility (Chords / Lyrics toggles). Separators between groups. A pinging primary 8 px dot on the trigger when anything differs from defaults or a visibility toggle is off.
- **Auto-scroll (page mode only):** `−` / Play-Pause (secondary when running) / `+` / speed number (xs muted, w-10); stops at the bottom; rAF px/s.
- **Playlist mode (top sheet):** swipe left/right ≥60 px (horizontal dominant) for next/previous; bottom-left bar ChevronUp / `n/total` / ChevronDown; slide-in 200 ms (`slide-in-from-right-4` / left).
- **Rendered song:** sections collapsible (tap the header), section header colours from §5.4, `× n` repeat count suffix, flags, comment/label/box/volta blocks, tapping a chord opens the diagram dialog. Empty lyrics: 64 px muted circle `Music2` + "No lyrics" + description. Plain fallback text uses line-height 1.4.
- **Editor:** CodeMirror (not Monaco), height 600 px, Catppuccin Latte/Mocha themes (`@catppuccin/codemirror`), no line numbers/fold/active-line/autocomplete. ChordPro language: chord atoms coloured `var(--chord)` and directive autocompletion for flags. Paste auto-converts chord-over-lyrics. Selecting text shows the **"Wrap as"** toolbar (Verse/Pre-Chorus/Chorus/Bridge/Intro/Outro chips: `rounded-md border px-2 py-0.5 text-xs`). Auto-save while editing; label above "Lyrics format info" / "Preview". Preview renders in a `rounded-lg border bg-card p-4 md:p-6` box.
- **ChordPro reference:** dialog. Categories metadata/section/comment/chord/formatting; category header 10 px bold uppercase tracking 0.2em + rule; directive code chips 12 px mono semibold (blue-600/blue-300; formatting green-700/green-400); copyable examples.
- **Not present on the web:** fullscreen/stage mode, external display, metronome. (iOS adds a stage UI; that is fine, but the stage chrome is iOS-specific.)

### 6.3 Playlists (`playlists-client.tsx`, `playlist-list.tsx`, `playlist-item.tsx`, `playlist-detail.tsx`)

- Same split/mobile-sheet pattern as Songs. Header "Playlists · N" + default pill "Create playlist". Search (client-side). Filters popover: Visibility All/Public/Private.
- **Row:** `rounded-xl p-3 gap-3 shadow-sm`. Selected `bg-accent-playlists/10 ring-2 ring-accent-playlists/40`. Archived opacity .5. 40 px rounded-xl tile (bucket colour or accent-playlists at 12–15%) with `Music3` 20 px. Name text-sm bold + Lock / Globe(+Users) icons with tooltips + "Archived" chip. Meta: Calendar date, Music3 count, ownership chip (first word of the team name). Trailing 36 px archive button.
- **Placeholder:** like Songs, with `ListMusic` and the accent-playlists bar.
- **Detail** (`border-t-2 border-accent-playlists`, `bg-muted/30`):
  - Header `bg-card p-4 lg:p-6`: inline-editable name (lg bold), close X 20 px, inline-editable multiline description ("Add description").
  - **Details:** date pill (calendar popover) + song-count pill.
  - **Privacy & sharing** card (`rounded-xl border bg-card shadow-sm p-4 max-w-md`): Public visibility switch ("Anyone with the link"), Public URL code + Copy + Open, Guest editing switch (disabled unless public, with a hint).
  - **Archive** card.
  - **Songs:** "Add songs" outline sm → AddSongsSheet. List = drag-reorderable rows (`rounded-xl bg-card shadow-sm p-3`, grip, 32 px numbered circle `bg-primary/10 text-primary text-sm bold`, title/artist, key/BPM/tag badges, 36 px remove X with destructive hover). Tapping a row opens the lyrics top sheet. Empty: Empty block + Add songs.
  - **Danger zone:** delete with confirm.
- **Create form:** header `ListMusic` + "Create playlist"; Bucket, Name + Sparkles "Suggest name" 36 px button, Description, Date picker; submit + cancel.
- **Draft cart:** toggled from the song rows. FAB bottom-right "Add to playlist" with count. Dialog (sm+) or Drawer (mobile): sortable list, select "New playlist" or an existing one, name input; Clear / "Add N" buttons. Duplicate-only add → toast "All songs are already in this playlist".
- **Public view `/shared/[code]`:** hero card `rounded-2xl border-border/50 bg-linear-to-br from-accent-playlists/10 via-accent-playlists/5 p-7`, title 2xl bold, description, chips (shared link `accent-playlists/10` + Globe/visibility), date, Share button and owner gear popover (privacy toggles). Song list: `divide-y rounded-xl border bg-card`, rows `px-4 py-4` with index (w-5 xs muted), title text-base medium, artist text-sm muted, tags, key badge (h-6) and BPM badge (sm+). Drag-reorder when guest editing is on. Tap opens the lyrics sheet.

### 6.4 Chords (`features/chords/components/*`)

- Title "Chords" (2xl/3xl bold) + subtitle. Tabs: **Glossary** (`BookOpen`) | **Analyzer** (`ScanSearch` + "Beta" chip).
- Glossary: search input (max-w-xs, clear X), key chips (h-9 min-w-44 rounded-full px-4 text-sm semibold; selected = default variant, others ghost; horizontal scroll on phone, wrap on sm+), "N chords found", grid of ChordCards (white/zinc-950 diagram tile + name text-sm semibold). Tap opens a bottom Sheet (`max-h-[90dvh] rounded-t-2xl`): title 3xl bold + play button, "Position x of y" subtitle, diagram card, variant pills. Empty: "No results" + hint.
- Analyzer: interactive fretboard → identifies chord names, reset (`RotateCcw`).

### 6.5 Teams (`features/teams/components/*`)

- **List:** header "Teams" (2xl / sm 4xl bold) + "Manage teams" subtitle. Buttons: outline "Invitations" (`Mail`) + default "Create team" (`Plus`), a 2-column grid on phone. Search (h-10, `bg-muted/50`). Grid of **TeamCards**:
  - `Card` with hover shadow-md; current team `border-2 border-primary`.
  - A **4 px role-coloured top bar** (owner = primary, admin = accent-songs, others = accent-activity).
  - 36 px rounded-lg avatar/icon with the role tint (clickable icon picker).
  - Name text-base bold (link). "Current" badge. RoleBadge (outline, icon + label, 10 px). Public/private badge.
  - Divider, `Users` + "N members", leave (`LogOut`) or delete (`Trash2`) destructive ghost button with confirm dialogs.
  - Empty: Card with the bar and "No teams found" + Create.
- **Detail:** back button "Back to teams" (`ArrowLeft`). Header: 56 px rounded-xl icon/avatar with an edit pencil badge, inline-editable name (2xl bold) and description, "Current" badge, role badge.
  - **Members** card (`rounded-2xl border bg-card p-6`): `Users` + "Members", "Add member" (`UserPlus`). Member Items: avatar, name/email, role dropdown button (`Shield` … `ChevronDown`) listing allowed roles, ⋮ menu with Remove. Pending invitations (Mail avatar, "Invited on {date}" + Clock, Copy link, Cancel). Expired invitations (Resend `RefreshCw`).
  - **Danger zone** (`rounded-2xl border-destructive/30 bg-destructive/[0.02] p-6`): Transfer ownership (select new owner), Transfer & leave, Leave, Delete.
- **Invite dialog:** email + role select (Member/Admin/Viewer) → "Send invitation".
- **Create team:** `rounded-lg border bg-card p-6` form with name, icon picker, etc.
- **Invitations page:** "Invitations · N" (3xl bold), description; cards `rounded-2xl border bg-card shadow-sm p-6` with team, inviter, role, expiry (destructive when expired), accept/decline. Loading skeletons. **Accept invitation** page: success / error / expired states (CheckCircle / XCircle / AlertCircle).

### 6.6 Settings (`app/(app)/dashboard/settings/settings-client.tsx`)

- Title "Settings" (3xl bold leading-none, mb-8). Left nav (sm+ vertical `w-44`, phone horizontal pills): **Profile** (`User`), **Appearance** (`Palette`), **Account** (`ShieldAlert`). The nav labels are **hard-coded English** (a web bug). Active `bg-primary/10 text-primary`, inactive muted with hover bg-muted; desktop items `rounded-xl px-3 py-2.5`, phone `rounded-full px-4 py-2`.
- **Profile:** 64 px avatar (initials in xl bold primary on primary/10), name bold, email, "Connected via {Provider}" chip (`KeyRound`).
- **Appearance** (single card, separators between sections):
  1. **Color Palette:** header + "Surprise me" pill (`Sparkles`). Grid of 2 columns × 12 palette cards: a 48 px split preview (light bg | 1 px divider | dark bg, each with a 14 px primary dot + two 8 px accent dots at .75 / .6 opacity), label area `bg-card px-2.5 py-2` with name (xs semibold) + description (10 px muted). Active `border-primary/60 ring-1 ring-primary/40` + bottom bar. Preview hexes are hard-coded in `palette-settings.tsx:15-70`.
  2. **Font:** grid 2 columns (sm 4) of 12 font cards: "Aa" 24 px semibold in that font, name xs medium, description 10 px.
  3. **Appearance / Theme:** 3 option cards Light/Dark/System with Sun/Moon/Monitor.
  4. **Language:** flag + name chips.
  5. **Chord diagrams:** Right hand / Left hand cards.
- **Account:** destructive card: "Danger Zone" + "Delete account" → inline confirm (Cancel / confirm, pending text).

### 6.7 Auth (`components/login-page-content.tsx`, `features/auth/components/login-form.tsx`)

- Full-screen background with blurred primary/violet orbs. Top-left "Back" link (`ArrowLeft`); top-right theme/language toggles.
- Centred `max-w-sm`: logo with glow, tagline (sm muted relaxed). Card (`rounded-2xl border-border/50 bg-card/80 p-6 shadow-2xl backdrop-blur-sm`):
  - "Welcome to Capo" (xl bold) + description.
  - Error alert (destructive/8 bg, ⚠).
  - **Continue with Google** (h-11 full-width outline, `gap-3`).
  - GitHub (disabled, opacity .5, "Coming soon" chip).
  - Divider "or continue with" (11 px uppercase tracking-wider).
  - Email + "Send magic link" (disabled, "Coming soon"). Magic-link description 11 px.
  - Feature dots row (6 icons, 12 px, coloured 10% circles).

### 6.8 Activity and Feedback

- **Activity feed** (`features/activity/components/activity-feed.tsx`) exists but is **not mounted on any route**, so there is nothing to port.
- **Feedback form** is used only on the public landing page (`components/landing-feedback-section.tsx`), not in the app.

### 6.9 Responsive summary

| Width | Navbar | Songs/Playlists | Lyrics |
|---|---|---|---|
| < 640 | hamburger + logo + pill + avatar; px-4 | list full, detail as full-height bottom sheet; header buttons flex-1; filter label hidden | 1 column forced (≤768), floating bars |
| 640–767 | same; px-6 | same | same |
| 768–1023 (iPad portrait) | full horizontal nav, 17 px root | split 35/65 resizable | columns as chosen (2 col = 400 px column-width) |
| ≥ 1024 (iPad landscape) | header blur, px-8, logo mr-8 | list header p-6, title 2xl | same |

---

## 7. Gap list against the current iOS app

Severity: **P0** is visibly wrong or broken against the web, **P1** is a missing feature or option set, **P2** is a polish difference. Only differences are listed; matches are omitted.

### 7.1 Instruments and chords

| Sev | Gap | Web evidence | iOS evidence |
|---|---|---|---|
| P0 | Ukulele exists on iOS but only as a non-persisted in-sheet toggle; there is no setting and it defaults to guitar on every open. (The web has no ukulele, so this is an iOS-only feature to finish: persisted preference + Settings UI.) | `chord-diagram.tsx` (guitar only) | `ChordDiagramView.swift:87-95`, `SongPerformanceView.swift:140` |
| P0 | No chord-hand (left/right mirror) preference; default must be `left` (low string drawn on the left) | `chord-hand-settings.tsx`, `use-chord-orientation.ts`, `chord-position-diagram.tsx:72` | none |
| P1 | No algorithmic fallback / base-chord fallback, so more "not found" results than the web | `chord-diagram.tsx:280-301` | `ChordDatabase.swift:47-54` |
| P1 | Diagram look differs (4 frets, finger numbers, barre bar, X/O, white/zinc-950 card, Verified/Generated subtitle, dots pager, Previous/Next footer) | `chord-position-diagram.tsx`, `chord-diagram.tsx:215-298` | `FretboardView`, `ChordDiagramView.swift` |
| P1 | Chords glossary + analyzer section missing | `features/chords/*`, nav item Chords | no sidebar item |
| P2 | Chord audio (guitar samples) missing | `features/chord-audio/*` | none |
| P1 | Web bug: the column toggle overwrites `profiles.preferences` and wipes chordHand/palette/uiFont/locale/theme (and any iOS key) | `user-preferences-api.ts:93-113`, `use-user-preferences.ts:41-46` | iOS preserves raw JSON (`Preferences.swift:52,68`), but the web will clobber it |

### 7.2 Icons and option sets

| Sev | Gap | Web evidence | iOS evidence |
|---|---|---|---|
| P0 | Team icon shown as text and created via a free-text field; the web stores lucide names (80 options, picker) | `components/ui/icon-picker.tsx` | `TeamsView.swift:59,83-92`, `ContextPicker.swift:23` |
| P0 | Nav icons/labels differ: Teams `person.3` (web `users`, 2 people); "Library"/"Setlists" vs web "Songs"/"Playlists"; no Chords | `navbar.tsx:692-698` | `MainShellView.swift:352-366`, compact tabs `:114-140` |
| P1 | 12 colour palettes missing | `lib/palette.ts`, `globals.css:421-1175`, `palette-settings.tsx` | `Theme.swift` (single palette) |
| P1 | 12 UI fonts missing | `lib/font.ts`, `app/layout.tsx` | Geist only |
| P1 | "Surprise me" missing | `palette-settings.tsx:229`, `profile-menu-actions.tsx` | — |
| P1 | Group by (None/Key/Artist) missing | `songs-client.tsx:478-504` | `LibraryFilters.swift` (no grouping) |
| P1 | Song row lacks: 44 px cart toggle, BPM badge with turtle/rabbit/zap tiers and colours, played-frequency badge, ownership chip with bucket colour, Geist Mono key badge in accent-songs | `song-item.tsx`, `badge-colors.ts`, `bucket-colors.ts` | `SongRow.swift` (checkmark circle, plain "N BPM" text, mauve KeyBadge) |
| P1 | BPM filter thresholds differ (web filter 100/140; iOS 90/120). Pick one deliberately; the web text and badges say 90/120. | `song-list.tsx:52-60` vs `songs.bpmDescription` | `LibraryFilters.swift:4-12` |
| P1 | Lyrics-editor extras missing: CifraClub import, Parse chords (wand), ChordPro reference, "Wrap as" section toolbar | `lyrics-view.tsx`, `section-wrap-toolbar.tsx`, `cifraclub-import-dialog.tsx` | grep: none |
| P1 | Share lyrics text variants (respecting chords/lyrics visibility) | `lyrics-view.tsx:62-91,248-269` | verify `ShareLink` usage |
| P1 | Transfer song to team | `transfer-to-team-dialog.tsx`, `song-actions-menu.tsx` | grep: none |
| P1 | Role icons (UserLock/KeyRound/User/UserSearch) and the role-coloured 4 px team card bar | `teams/constants.ts:158-163`, `team-card.tsx:11-27` | `CapoTeamsUI/*` |
| P2 | Lucide vs SF Symbol shape mismatch across the board (bundle lucide SVGs) | §2 | SF Symbols |
| P2 | iOS extras not on the web (fine to keep, but they diverge visually): song sort, status filter, stage/fullscreen, conflicts, sync footer, sidebar rail | — | `LibraryFilters.swift`, `StageComponents.swift`, `MainShellView.swift` |

### 7.3 Fonts and tokens

| Sev | Gap | Web evidence | iOS evidence |
|---|---|---|---|
| P0 | Lyrics font is Geist Mono on the web; iOS uses Geist Regular | `rendered-song.tsx` `<pre>`, Tailwind preflight `pre { font-family: mono }` | `Components.swift` `CapoFont.lyrics` → "Geist-Regular" |
| P0 | Colour hexes are taken from CSS comments, not the rendered oklch. Dark mode is far off (bg `#080916` vs `#1e1e2e`, card `#171928` vs `#313244`, border `#2a2c3c` vs `#45475a`); light primary `#eb5100` vs `#fe640b` | `globals.css:331-419` | `Theme.swift:20-36` (and `OKLCH.swift` exists but is unused for the palette) |
| P0 | Section accent colours wrong: iOS uses Catppuccin hexes (verse `#1e66f5`, bridge `#ea76cb`…); the web uses its own oklch set (verse `#005fb2`/`#45a4f6`, chorus `#624bbc`/`#a192ff`, bridge `#a13170`/`#e670ac`, comment `#008687`/`#00afaf`, repeat `#9e4800`/`#f29520`, tab/grid `#626369`/`#8e8f95`, intro `#1b7e2a`/`#67bb6b`, outro `#007982`/`#00b6be`, pre_chorus `#7d45a2`/`#bf8ae6`; Rosé Pine has its own overrides) | `globals.css:623-639,1309-1365` | `Theme.swift:39-51` |
| P0 | `onPrimary` is always `#1e1e2e`; the web primary-foreground is light `#ededf2` in light mode | `globals.css:350` | `Theme.swift:33` |
| P1 | Selection/active colours: the web uses `secondary`/`accent` fills for active nav and `bg-accent-songs/8 + ring-2 accent-songs/50` for the selected row; iOS uses a custom peach `selection` | `nav-links.tsx`, `song-item.tsx:56-58` | `Theme.swift:31` |
| P1 | Section block metrics: web background 6% light / 12% dark, 2 px left border, padding 8/16/10/16, label fixed 12 px bold tracking .18em; iOS background .1, padding 14/6/4, label `max(13, pt*0.6)` | `globals.css:1373-1388`, `rendered-song.tsx:84-92` | `Components.swift:18-20`, `RenderParts.swift:338-377` |
| P1 | Chord badge metrics: web 12% bg, 3 px radius, 0×3 px padding; iOS 14%, ~0.26 em radius, ~0.28 em padding | `globals.css:1247-1259` | `RenderParts.swift:210-219` |
| P1 | Tablet scale: the web root is 17 px at ≥768 (all UI ×1.0625, lyrics unaffected); iOS uses system-like sizes (title2 22, body 17) that don't map to the web scale (text-sm 14/14.875 body, text-xs 12/12.75 meta) | `globals.css:1566-1570` | `Components.swift:215-231` |
| P1 | Radii: the web base is 10.4 px (md 8.4, xl 14.4, 2xl 16); iOS uses 8/12/16 | `globals.css:325-332` | `Theme.swift:55-59` |
| P2 | Buttons: web h-9 (36) default, sm h-8 (32), rounded-md (8.4), primary fill with light foreground, text-sm medium. iOS min 48 pt, radius 12, semibold body 17. (Keep 44–48 pt hit areas, but match visual size/radius/weight.) | `components/ui/button.tsx` | `Theme.swift:72-117` |
| P2 | Toasts are bottom-center on the web | `components/ui/sonner.tsx:15` | `CapoDesign/Toast.swift` |

### 7.4 Screen layouts

| Sev | Gap | Web evidence | iOS evidence |
|---|---|---|---|
| P0 | Shell: no web sidebar; IA should be Songs/Playlists/Chords/Teams + avatar menu (Settings, Invitations, Theme, Surprise, Logout) + context pill (All/Personal/teams, "Manage teams") | §4 | `MainShellView.swift`, `ShellNavigation.swift` |
| P1 | Context pill content/states (avatar group for All, 80/120 px truncation, filtered tint, subtitle rows, "Manage teams" footer) | `context-pill.tsx` | `ContextPicker.swift`, sidebar `contextSwitcher` |
| P1 | Songs detail placeholder (watermark + accent bar), 35/65 split with 25–50% limits | `songs-client.tsx:422-428,585-597` | `PanelLayout.swift` (fraction .35, min 280/360 pt: close) |
| P1 | Lyrics header 3-row layout + display-settings popover (font/transpose/capo/columns/visibility with Reset, pinging dot) + active-setting chips | `lyrics-view.tsx:354-523,536-726` | `StageComponents.swift` (different stage UI) |
| P1 | Playlist detail sections (Details pills, Privacy card, Archive card, numbered draggable rows, Danger zone) and the public share page | `playlist-detail.tsx`, `playlist-share-view.tsx` | `PlaylistDetailView.swift` (menu-based) |
| P1 | Draft cart (FAB + dialog/drawer to add selected songs to a new or existing playlist) | `playlist-draft.tsx`, `draft-indicator.tsx` | multi-select "Add to setlist" exists: verify the flow |
| P1 | Settings structure: Profile / Appearance (Palette, Font, Theme cards, Language chips, Chord diagrams) / Account | `settings-client.tsx` | `SettingsView.swift` (Form sections; theme Picker; no palette/font/hand) |
| P1 | Team card visuals and team detail (icon editor, role dropdown, invitation sections, danger-zone transfer flows) | `team-card.tsx`, `team-members-section.tsx`, `team-danger-zone.tsx` | `TeamsView.swift`, `TeamDetailView.swift` |
| P2 | Empty states use the web Empty block (tinted 40 px icon tile + title + description), not `ContentUnavailableView` | `components/ui/empty.tsx`, `song-list.tsx:107-121` | `Components.swift:166-185` |
| P2 | Login: web is Google only (GitHub and magic link disabled "Coming soon"); iOS adds email/password | `login-form.tsx` | `AuthView.swift` |

### 7.5 Suggested order of work

1. Tokens from oklch via `OKLCH.swift` (catppuccin light/dark first, then the palette table), `onPrimary` fix, section accents.
2. Geist Mono for lyrics/chords; web chord badge and section block metrics.
3. Shell IA + context pill + avatar menu (after the crash fix).
4. Team icons (lucide asset set + 80-icon picker) and the lucide icon set for nav/actions.
5. Chord hand + persisted instrument (+ fix the web preference-clobber bug).
6. Palette and font pickers (+ "Surprise me"), group-by, song row badges.
7. Editor extras (wrap toolbar, parse chords, CifraClub, reference) and the Chords glossary.
