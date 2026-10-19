# Capo native iOS/iPadOS app: executable work breakdown (v1)

Worktree: `/Users/mfuentesg/code/capo/.claude/worktrees/ios-p0` (branch `feat/ios-p0-golden-fixtures`). All paths below are relative to it.

## 0. Overview

A universal SwiftUI app for iOS 17+. It talks directly to Supabase (PostgREST + Auth + Realtime) under the existing RLS. Every read comes from a per-user local SQLite database (GRDB + FTS5). Pull uses snapshot+diff. Writes go through an outbox of intent operations: client UUIDs, optimistic concurrency on `songs.updated_at`, last-writer-wins (LWW) for settings and preferences. ChordPro rendering is a faithful Swift port of `features/lyrics-editor/utils/song-pipeline.ts` (including chordsheetjs v12.3.1 transpose quirks). It is proven byte-exact against `ios/Fixtures/golden`. No server changes are needed for the MVP.

### Facts from the repo that the plan depends on
- **Rendering**
  - chordsheetjs transposition is stepwise and keeps the original accidental: `Key.transpose` ends in `useModifier(originalModifier)`. Real golden outputs include `F#m -6 → B#m`, `Bb -6 → Fb`, `G -1 → Gb`, `Am +1@capo5 → E#m`. Source: `node_modules/chordsheetjs/lib/module.js`, Key ≈ lines 1919–2420, `ChordLyricsPair.transpose` ≈ line 871, `Chord.normalize` ≈ 3470, `Song.transpose` ≈ 6727.
  - Transpose and capo are two separate passes: `transpose(t)` then `transpose(-capo)`.
  - A `{key:}` directive inside a processed chunk switches on enharmonic normalization, but only for that chunk.
  - Directive lines (`{title:}` etc.) render as empty lines. Chord text and lyric text are not HTML-escaped; comment, label and note text are.
- **Data model**
  - `songs`, `playlists` and `profiles` have `updated_at` triggers. `user_song_settings.updated_at` is set by the client.
  - `playlist_songs`, `song_tags`, `song_tag_assignments` and `team_members` have no usable `updated_at`, so they are fetched whole.
  - `user_song_settings` is constrained to transpose −6…6, capo 0…12, font_size 0.5…3.0, and is unique on (user_id, song_id).
- **RLS and limits**
  - The songs SELECT policy also returns songs that sit in other users' public playlists, and public teams and playlists are readable by everyone. So sync must always filter explicitly: `or=(user_id.eq.<me>,team_id.in.(<myTeamIds>))`. Teams come via `team_members.user_id = me`.
  - `max_rows = 1000`, so every version query must page with `Range`.
- **Timestamps:** timestamptz has microsecond precision. Keep the raw string (`ServerTimestamp`) for equality checks. Never round-trip through `Date`.
- **Preferences:** `merge_user_preference` stores values as text, which breaks numeric `lyricsColumns`. Preferences use read-modify-write of the whole `profiles.preferences` JSON instead, keeping unknown keys.
- **Web behaviour to mirror:**
  - Auto-scroll: speed is in px/s, min 10, max 300, step 10, default 30. With bpm > 0, inferred speed = scrollableHeight / (nonDirectiveLines·4 / (bpm/60)), clamped.
  - Font size: 0.5…3.0, step 0.25, base 16pt.
  - Search weights: title A, artist B, notes C, lyrics D.
  - Tag colour is a CSS hex string, default `#6b7280`.
- **Env:** web uses `NEXT_PUBLIC_SUPABASE_URL` / `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. The local stack is `localhost:54321`. `supabase/config.toml` `additional_redirect_urls = ["http://localhost:3000"]`.
- **Toolchain:** Xcode 27.1, Swift 6.4. Booted simulators exist. Neither xcbeautify nor actionlint is installed.

## 1. Tech decisions

| Topic | Decision |
|---|---|
| Packages | 5 **local** SwiftPM packages under `ios/Packages`. The app target links exactly **one** product, `CapoAppKit`. pbxproj gets one `XCLocalSwiftPackageReference` plus one product dependency, added once by WP0. External deps (GRDB, supabase-swift) are declared only in package manifests. |
| Manifests | `// swift-tools-version: 6.2`, `swiftLanguageModes: [.v6]`. UI targets add `swiftSettings: [.defaultIsolation(MainActor.self)]`. Package.swift files are written once by WP0 and frozen; only WP0 may edit them. |
| Deps | `GRDB.swift from: "7.0.0"` (FTS5 is enabled in its manifest; WP0 smoke-tests it). `supabase-swift from: "2.0.0"`, product `Supabase`. `Package.resolved` is committed (WP0). |
| Platforms | CapoCore, CapoData and CapoSupabase support iOS 17 and macOS 14, so `swift test` runs on the host. CapoUI and CapoAppKit are iOS 17 only (tested with xcodebuild on a simulator). |
| Breakage isolation | Each owner gets its own SwiftPM **target**, so a half-written file only breaks that target's dependents. ChordPro is its own target (`CapoChordPro`). UI is 10 targets. Data is split into `CapoStore` and `CapoSync`. |
| Config / secrets | Git-ignored `ios/Capo/Capo/Secrets.plist` with keys `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `CAPO_WEB_URL`, `CAPO_ENV_NAME`. It sits inside the synchronized folder, so it is bundled automatically with no pbxproj change. The committed example is `ios/Capo/Secrets.example.plist` (outside the synced folder). A missing plist puts the app into **Demo mode** (fakes). `ios/scripts/use-supabase.sh local\|production` writes the plist. |
| Info.plist | `ios/Capo/Config/Info.plist` (outside the synced folder), set via `INFOPLIST_FILE` and merged with generated keys. It holds: `CFBundleURLTypes` scheme `capo`; `CFBundleLocalizations` [en, es]; `NSAppTransportSecurity.NSAllowsLocalNetworking=YES`; `NSLocalNetworkUsageDescription`; `UIApplicationSupportsMultipleScenes=YES`. |
| Auth | supabase-swift `signInWithOAuth(provider: .google, redirectTo: capo://auth/callback)`, which uses ASWebAuthenticationSession and PKCE. Email/password sign-in is the dev fallback; sign-up is shown only when `CAPO_ENV_NAME != production`. The session lives in the default Keychain storage. **Offline cold start must restore the stored session without the network.** Sign in with Apple is deferred (human). |
| Local DB | One file per user: `ApplicationSupport/Capo/<userID>.sqlite`, opened with DatabasePool (WAL). GRDB `DatabaseMigrator`. FTS5 external-content table synced to `songs`, tokenizer `unicode61 remove_diacritics 2`. |
| Sync | Order is push (outbox FIFO per entity) then pull (versions diff for songs, playlists and user_song_settings; whole fetch for the rest). Triggers: launch, foreground, manual, outbox enqueue, reachability regained, realtime events (debounced 1 s; any change event triggers a pull). |
| Concurrency | Song update is `PATCH … ?id=eq.X&updated_at=eq.<raw base>` with `Prefer: return=representation`. Zero rows returned means fetch the server row and record a conflict (or treat as deleted). Settings and preferences are LWW. |
| Rendering | `CapoChordPro` produces a structured model (`RenderedSong`). The test-only-in-spirit `LegacyHTMLSerializer` reproduces the web HTML **byte-exactly**, and the golden test compares every case and segment field. There is **no** web-side structured-model generator: the HTML is an exact, total encoding of the model, so a second golden format would only add drift. WP2 adds more corpus files plus chord and music-theory goldens. |
| i18n | `ios/scripts/gen-i18n.mjs` (Node, no deps) reads `lib/i18n/locales/{en,es}.json` plus `ios/i18n/ios.{en,es}.json`. It writes `Localizable.xcstrings` (keys are dotted paths, `{name}` becomes `%@` or positional `%1$@`, `extractionState: manual`) and a typed `L10n.swift` (nested enums; placeholders become funcs with String params). `--check` mode exits 1 when the output is stale. |
| Tests | Swift Testing (`import Testing`). Fixtures are found via `#filePath` relative paths, which works for both `swift test` and simulator test. |
| Shared-worktree hygiene | Separate derived-data folder per agent: `-derivedDataPath ios/build/dd-<WP>`. Each UI agent gets its own simulator ID (table in §6). Only WP0 or the integrator installs to physical devices. |

## 2. Directory layout (owner in brackets)

```
ios/
  .gitignore                                  [WP0] build/, Packages/*/.build, Packages/*/.swiftpm, Capo/Capo/Secrets.plist, Capo/Secrets.*.plist (!example), *.xcresult
  README.md, HUMAN_TODO.md                    [WP13]
  i18n/ios.en.json, ios.es.json               [WP12]  iOS-only strings, namespace "ios.*"
  scripts/
    build-sim.sh, test-packages.sh, install-device.sh   [WP0]
    use-supabase.sh                                      [WP13]
    gen-i18n.mjs                                         [WP12]
  Fixtures/corpus/*.cho, golden/*.json        [WP2]  (existing 4 files must stay byte-identical)
  Capo/
    Capo.xcodeproj/**                         [WP0 only, ever]
    Capo/CapoApp.swift, Assets.xcassets       [WP0]  (ContentView.swift deleted)
    Config/Info.plist                         [WP0]
    Secrets.example.plist                     [WP0]
  Packages/
    CapoCore/   Package.swift [WP0]
      Sources/CapoCore/{Models,Contracts,Util}/**        [WP0, frozen after W0; changes only via WP0]
      Sources/CapoChordPro/RenderModel.swift             [WP0 creates → WP1 owns; public shape frozen]
      Sources/CapoChordPro/{Engine,Parser,Transpose,MusicTheory,Legacy}/**  [WP1] (WP0 leaves Engine/StubEngine.swift for WP1 to replace)
      Sources/CapoFakes/**                               [WP0]
      Tests/CapoCoreTests/**                             [WP0]
      Tests/CapoChordProTests/**                         [WP1]
    CapoData/   Package.swift [WP0]
      Sources/CapoStore/Contracts/LocalSyncStore.swift   [WP0, frozen]
      Sources/CapoStore/** (rest)                        [WP3a]
      Sources/CapoSync/**                                [WP3b]
      Tests/CapoStoreTests/** [WP3a]   Tests/CapoSyncTests/** [WP3b]
    CapoSupabase/ Package.swift [WP0]
      Sources/CapoSupabase/Client/SupabaseClientFactory.swift [WP0]
      Sources/CapoSupabase/{Auth,Rows,Remote,Realtime,Teams}/**  [WP4]
      Tests/CapoSupabaseTests/**                         [WP4]
    CapoUI/     Package.swift [WP0]
      Sources/CapoDesign/Environment.swift               [WP0, frozen]
      Sources/CapoDesign/Resources/Localizable.xcstrings [WP12] (WP0 placeholder)
      Sources/CapoDesign/Generated/L10n.swift            [WP12] (WP0 placeholder)
      Sources/CapoDesign/** (rest: theme, components)    [WP5] (WP0 stubs)
      Sources/CapoRendering/**                           [WP7a]
      Sources/CapoAuthUI/**                              [WP5]
      Sources/CapoLibraryUI/**                           [WP6]
      Sources/CapoPerformanceUI/**                       [WP7b]
      Sources/CapoPlaylistsUI/**                         [WP8]
      Sources/CapoEditorUI/**                            [WP9]
      Sources/CapoTeamsUI/**                             [WP10]
      Sources/CapoSettingsUI/**                          [WP11]
      Sources/CapoShellUI/**                             [WP5]
      Tests/<Target>Tests/**                             [owner of the matching target]
    CapoAppKit/ Package.swift + Sources/CapoAppKit/**    [WP0 / integrator]
features/lyrics-editor/utils/__tests__/chord-transpose-golden.test.ts   [WP2]
lib/__tests__/music-theory-golden.test.ts                               [WP2]
supabase/config.toml (additional_redirect_urls only)                     [WP4]
.github/workflows/ci.yml, package.json "scripts" (ios:* keys only)       [WP13]
```
Every WP0 stub file listed under another WP's directory becomes that WP's file once Wave 0 ends. The owner may change the body but **must keep the public signature** defined in §5.

### Package manifests (WP0 writes exactly these targets)
- **CapoCore**
  - Products: CapoCore, CapoChordPro, CapoFakes.
  - Targets: `CapoCore` (no deps); `CapoChordPro` (no deps); `CapoFakes` [CapoCore, CapoChordPro].
  - Tests: `CapoCoreTests` [CapoCore, CapoFakes]; `CapoChordProTests` [CapoChordPro].
- **CapoData**
  - Deps: `../CapoCore`, GRDB.
  - Targets: `CapoStore` [CapoCore, GRDB]; `CapoSync` [CapoStore, CapoCore].
  - Tests: `CapoStoreTests` [CapoStore, CapoFakes]; `CapoSyncTests` [CapoSync, CapoStore, CapoFakes].
- **CapoSupabase**
  - Deps: `../CapoCore`, supabase-swift.
  - Targets: `CapoSupabase` [CapoCore, Supabase].
  - Tests: `CapoSupabaseTests` [CapoSupabase], with `resources: [.copy("Fixtures")]`.
- **CapoUI**
  - `defaultLocalization: "en"`, iOS 17 only.
  - Targets:
    - `CapoDesign` [CapoCore, CapoChordPro, CapoFakes], `resources: [.process("Resources")]`
    - `CapoRendering` [CapoDesign, CapoChordPro]
    - `CapoAuthUI` [CapoDesign]
    - `CapoLibraryUI` [CapoDesign]
    - `CapoPerformanceUI` [CapoDesign, CapoRendering]
    - `CapoPlaylistsUI` [CapoDesign, CapoPerformanceUI, CapoLibraryUI]
    - `CapoEditorUI` [CapoDesign, CapoRendering]
    - `CapoTeamsUI` [CapoDesign]
    - `CapoSettingsUI` [CapoDesign]
    - `CapoShellUI` [all of the above]
  - Tests: `CapoRenderingTests`, `CapoLibraryUITests`, `CapoPerformanceUITests`, `CapoPlaylistsUITests`, `CapoEditorUITests`, each with one placeholder `@Test`.
- **CapoAppKit**
  - Deps: the 4 local packages.
  - Target: `CapoAppKit` [CapoShellUI, CapoStore, CapoSync, CapoSupabase, CapoFakes, CapoCore].

### pbxproj edit (WP0 only; IDs continue the `A1…` scheme)
- Add `A10000000000000000000010 /* XCLocalSwiftPackageReference "../Packages/CapoAppKit" */ = {isa = XCLocalSwiftPackageReference; relativePath = ../Packages/CapoAppKit; };`
- Add `A10000000000000000000011 /* CapoAppKit */ = {isa = XCSwiftPackageProductDependency; productName = CapoAppKit; };`
- Add `A10000000000000000000012 /* CapoAppKit in Frameworks */ = {isa = PBXBuildFile; productRef = A10000000000000000000011; };`
- Wire them up:
  - Frameworks phase `files = (A…12)`.
  - Target `packageProductDependencies = (A…11)`.
  - PBXProject `packageReferences = (A…10)`.
- Target build settings: `INFOPLIST_FILE = Config/Info.plist`; keep `GENERATE_INFOPLIST_FILE = YES`.
- Add a shared scheme `Capo.xcodeproj/xcshareddata/xcschemes/Capo.xcscheme`.
- Validate with `plutil -lint ios/Capo/Capo.xcodeproj/project.pbxproj` and `xcodebuild -list -project ios/Capo/Capo.xcodeproj`.
- `CapoApp.swift` becomes `import SwiftUI; import CapoAppKit; @main struct CapoApp: App { var body: some Scene { CapoAppScene() } }` and never changes again.

## 3. Work packages

Every WP's DoD includes four items:
1. Its verify commands (§6) pass.
2. Commits touch only owned paths.
3. No new warnings in owned files.
4. A short `## WPn notes` section is appended to the WP's own doc file `ios/docs/wp-notes/WPn.md` (owned by that WP), covering deviations and TODOs.

### WP0: Foundation and integration owner (Wave 0, then integrator in Waves 1–3)
- **Goal:** skeleton, contracts, fakes and wiring so that 7 agents can fan out. Target: about one session.
- **Steps, each a separate commit:**
  - **(a) Packages compile.** `ios/.gitignore`; the 5 Package.swift files; empty target sources; resolve and commit `Package.resolved`; a GRDB FTS5 smoke test in `CapoCoreTests`? No: put it in a throwaway `CapoStoreTests/FTS5SmokeTests.swift`, which then belongs to WP3a.
  - **(b) Contracts.** `CapoCore` Models, Contracts and Util exactly as §5. `CapoChordPro/RenderModel.swift` plus `Engine/StubEngine.swift` (naive: each line becomes `.text`). `CapoStore/Contracts/LocalSyncStore.swift`.
    - **Wave 1 unblock gate:** WP3a, WP3b and WP4 start here.
  - **(c) Fakes and UI stubs.**
    - `CapoFakes`:
      - `InMemoryBackend` actor with seed data: 12 songs, using the 4 corpus files plus Spanish titles; 2 playlists; 1 team; 4 tags.
      - Fakes for every protocol.
      - `FakeRemoteSyncSource` and `FakeRemoteWriter` with a scriptable result queue.
      - `FakeReachability`.
      - `AppDependencies.demo` and `UserServices.preview`.
    - `CapoDesign/Environment.swift`, plus CapoDesign component stubs (§5.7).
    - Entry-view stubs for every UI target with the §5.8 signatures, each rendering placeholder text.
    - Placeholder `Localizable.xcstrings` (`{"sourceLanguage":"en","strings":{},"version":"1.0"}`) and `L10n.swift` (`public enum L10n {}`).
    - **UI unblock gate:** WP5, WP6 and WP7a start here.
  - **(d) App wiring.**
    - pbxproj edit, Info.plist, Secrets example, scripts.
    - `CapoAppKit`:
      - `CapoAppScene: Scene` holds `WindowGroup { CapoRootView(...) }`, `.onOpenURL` goes to `auth.handleOpenURL`, plus `CapoComposition.make(config:)`.
      - Demo mode if `AppConfig.load(from: .main)` is nil or the launch arg `-CapoDemoMode YES` is set.
      - The real composition is left as a `fatalError("Wave 2")`-free stub: it falls back to demo and logs.
- **Wave 2 integration duties (WP-INT):**
  - Real composition: `SupabaseClientFactory`, then `SupabaseAuthService`, then on session `CapoDatabase.open`, then `LocalRepositories` plus `SyncEngine(remote: SupabaseRemoteSyncSource, writer: SupabaseRemoteWriter, realtime: SupabaseRealtimeNotifier, reachability: NWReachabilityMonitor)`.
  - Lifecycle: `scenePhase` drives `syncNow(.foreground)`.
  - Sign-out cleanup.
  - Device installs and the §9 checklist.
- **Acceptance:**
  - `swift build` succeeds in CapoCore, CapoData and CapoSupabase.
  - `xcodebuild -scheme CapoUI-Package build` succeeds for the simulator.
  - The app builds for the simulator, launches in demo mode, and shows the stub root.
  - `CapoCoreTests`: Codable round-trip of every model and every `OutboxOperation` case; `ServerTimestamp` parses `2026-03-01T15:01:10.123456+00:00` and keeps `raw` intact.
- **DoD:** gates (b), (c) and (d) committed in order; §6 verify commands pass.

### WP1: CapoChordPro engine, transposer and music theory (Wave 0 start → Wave 1)
- **Goal:** byte-exact port of song-pipeline.ts on top of a minimal chordsheetjs-compatible line parser and Key/Chord transposer.
- **Owns:** `CapoChordPro/**` except that the public types in RenderModel.swift are frozen (internal helpers may be added); `CapoChordProTests/**`.
- **Must port:**
  - `buildSectionMap` and `buildSegments`.
  - `processChordProContent`: comment, note and section tokens; end-marker stripping; stacked vs inline lines; auto-inline when content items are mixed with chords; `\s{2,}` collapse.
  - `splitAndProcessVolta` and `splitAndProcessBox`, including `trimEnd`/`trimStart` and empty-part semantics, with the `"\n"` joins that are visible in the golden output as blank lines.
  - `parseSectionValue`: name quotes, count, flags, `label:`.
  - chordsheetjs: `ChordProParser` line items (ChordLyricsPair, Tag, Comment); `Chord.parse` (root, suffix, bass); `Key.transpose`, `transposeUp`, `transposeDown`, `normalize`, `normalizeEnharmonics` (the enharmonic table is used when a `{key:}` tag appears in the chunk); `Song.transpose` two-pass.
  - `lib/music-theory.ts`: `transposeKey`, `calculateCapoKey`, `calculateEffectiveKey`.
  - Unparseable chords stay unchanged.
- **Inputs:** `node_modules/chordsheetjs/lib/module.js` (reference only), the goldens, and WP2's new goldens when they land. Start with the existing 4.
- **Acceptance tests:**
  - `GoldenPipelineTests`: for every `ios/Fixtures/golden/*.json` and every case, render with that case's transpose and capo plus the golden's `sectionLabels` and `commentLabel`, then map each segment to a `GoldenSegment: Codable, Equatable` (type, name, sectionType, html, count, flags, inline, found, displayLabel; nil fields omitted). Require **exact equality**.
  - `ChordGoldenTests` against `chords.json`, `MusicTheoryGoldenTests` against `music-theory.json`.
  - Plus unit tests per directive.
  - No normalization is allowed. If parity on some input is provably impossible, list it in `ios/Fixtures/known-divergences.md` and get the integrator's sign-off.
- **DoD:** all goldens pass; `ChordProEngine.render` on a 300-line song takes under 5 ms in release (`swift test -c release --filter Perf`).

### WP2: Web-side fixture expansion (Wave 0, ~1 h; same agent then does WP12)
- **Owns:** new `ios/Fixtures/corpus/*.cho`, the generated `ios/Fixtures/golden/*.json` for them, `chords.json`, `music-theory.json`, and the two new jest test files.
- **New corpus files:**
  - `key-directive.cho`: `{title}`, `{artist}`, `{key: G}`, then chords, then a section.
  - `edge-lines.cho`: `#` comment line; blank lines; `[N.C.]`; `[x2]`; `<b>&"` in lyrics; ñ and á; `[C/G] [Bbsus4] [F#m7b5] [Cadd9] [*Coda]`; trailing spaces; `Bass: [Gm][Bb] x2` outside an inline section; `{comment_box:}`; `{comment_italic:}`; bare `{c}`; `{c: X, label}`.
  - `sections-advanced.cho`: unnamed `{soc}`, `{sov}`, `{sopc}`, `{sot}`; `{sov: Verse, 2, forte, label: Custom}`; unclosed final section; `{repeat: Missing}`; `{repeat: Verse 1, 3, inline}`; `{start_of_extend: Missing, label: "Ext"}`; `{soex: Chorus, 2}` with no end; a repeat of a `{c: Intro}` comment-defined section.
  - `nested-box-volta.cho`: a box containing voltas; a box with no close; `{sbox: Hidden, label}`; unlabeled `{sovt}`.
  - Every file must render without throwing in chordsheetjs.
- **`chord-transpose-golden.test.ts`:** about 70 symbols (all roots including Cb, Fb, E#, B#; suffixes m, 7, maj7, m7, m7b5, sus2, sus4, add9, dim, aug, 6, 9, 11, 13; slashes C/E, D/F#, G/B, Am/G, Bb/D; non-chords N.C., x2, H).
  - Record `Chord.parse(s)?.transpose(d).toString() ?? s` for d in −12…12.
  - Record the two-pass pipeline (t in −6…6, capo in {0,1,2,3,5,7}).
  - Record `.normalize(key)` for keys {G, F, D, Bb, Em}.
  - Writes `ios/Fixtures/golden/chords.json` under `UPDATE_GOLDEN=1`.
- **`music-theory-golden.test.ts`:** `transposeKey` for 17 roots × {"", m, 7} × −11…11; `calculateCapoKey` for capo 0…12; `calculateEffectiveKey` over a grid. Writes `music-theory.json`.
- **Acceptance:** `pnpm test -- --testPathPattern='golden'` passes; `git diff --exit-code ios/Fixtures/golden/{basic-verse-chorus,flags-and-inline,repeat-and-extend,volta-box-comment}.json`; `pnpm lint`; `pnpm typecheck`.

### WP3a: CapoStore, local DB and repositories (Wave 1)
- **Owns:** `CapoStore/**` except `Contracts/LocalSyncStore.swift`; `CapoStoreTests/**`.
- **Public API:**
  ```swift
  public final class CapoDatabase: Sendable {
    public static func open(userID: UserID, directory: URL) throws -> CapoDatabase
    public static func inMemory(userID: UserID) throws -> CapoDatabase
    public func erase() throws
  }
  public struct LocalRepositories: Sendable {
    public let songs: any SongRepository; public let tags: any TagRepository
    public let playlists: any PlaylistRepository; public let settings: any SettingsRepository
    public let teams: any TeamRepository; public let conflicts: any ConflictRepository
    public let syncStore: any LocalSyncStore
    public init(database: CapoDatabase, userID: UserID, teamsRemote: (any TeamsRemote)?,
                onRemoteMutation: @escaping @Sendable () async -> Void)
  }
  ```
- **Schema v1:** text UUIDs; timestamps stored as raw TEXT; booleans as INT.
  - `songs`: id PK, title, artist, key, bpm, lyrics, notes, search_lyrics, transpose, capo, status, user_id, team_id, created_by, created_at, updated_at (last server version), local_modified_at.
  - `songs_fts` FTS5 with content=songs over (title, artist, notes, search_lyrics), using GRDB `synchronize(withTable:)`. `search_lyrics` = lyrics with `\[[^\]]*\]` removed and `\{[^}]*\}` replaced by a space.
  - `song_tags`: id, name, color, user_id, team_id, created_at.
  - `song_tag_assignments`: song_id, tag_id, PK(song_id, tag_id).
  - `playlists`: all columns.
  - `playlist_songs`: id, playlist_id, song_id, position.
  - `teams`; `team_members`.
  - `user_song_settings`: song_id PK, id, transpose, capo, font_size REAL, updated_at.
  - `profile`: id PK, email, full_name, avatar_url, preferences_json, updated_at.
  - `offline_pins`: playlist_id PK, pinned_at.
  - `outbox`: id INTEGER PK AUTOINCREMENT, op_id, entity_key, kind, payload_json, state (pending, inflight, conflict, failed), attempts, next_attempt_at, last_error, created_at.
  - `conflicts`: id (= op_id), song_id, local_json, server_json, detected_at.
  - `sync_meta`: key PK, value.
- **Semantics:**
  - Context filtering mirrors `applyContextFilter`: personal means `user_id=me AND team_id IS NULL`; team means `team_id=X AND user_id IS NULL`.
  - Search uses `FTS5Pattern(matchingAllPrefixesIn:)` with `bm25(songs_fts,10,5,2,1)` for `.relevance`.
  - The tag filter is any-of (OR).
  - Every write applies locally and enqueues the outbox op in **one transaction**.
  - Coalescing:
    - A pending (not inflight) `updateSong` for the same id merges its patch and keeps its base.
    - `upsertSongSettings` and `updatePreferences` keep only the latest op.
    - Delete-after-create of a never-pushed song drops both.
  - Online-only team ops call `teamsRemote` and then `onRemoteMutation()`. When offline or `teamsRemote` is nil they throw `.offlineUnavailable`.
  - `LocalSyncStore.apply(_:)` is idempotent, runs in one transaction, and skips any entity in `skipEntityKeys`. Full-replace sets are replaced only when non-nil.
  - On an applied update or create, the store sets `songs.updated_at` from the server and rebases the `base` of later pending `updateSong` ops for that id.
  - Pins are local only. `isFullyAvailableOffline` means every playlist song exists locally with non-nil lyrics.
- **Tests (real in-memory GRDB):** context isolation; FTS prefix and diacritics (`"cancion"` finds `"Canción"`); tag filter; outbox enqueue and coalesce; apply with skipped keys; deletion of rows absent from the diff; rebase-on-apply; stream emission on change. Perf: 2,000 songs, search under 50 ms.

### WP3b: CapoSync, sync engine and outbox processor (Wave 1)
- **Owns:** `CapoSync/**`, `CapoSyncTests/**`.
- **Public API:**
  ```swift
  public actor SyncEngine: SyncService {
    public init(userID: UserID, store: any LocalSyncStore, remote: any RemoteSyncSource,
                writer: any RemoteWriter, realtime: (any RealtimeNotifier)?, reachability: any ReachabilityMonitor,
                clock: @escaping @Sendable () -> Date = Date.init)
  }
  public final class NWReachabilityMonitor: ReachabilityMonitor { public init() }
  ```
- **Algorithm (`syncNow`, serialized; concurrent calls coalesce into one follow-up run):**
  1. If offline: phase `.offline`, return.
  2. **Push:** take `nextPendingOperations`. Ops are FIFO per `entityKey`, and an entity with a `.conflict` op is blocked. Map each result:
     - `.applied` → mark applied.
     - `.conflict` → record a conflict.
     - `.rejected` → mark failed and surface it.
     - A thrown error → retry with backoff of 2^attempts seconds, capped at 5 min.
  3. **Pull:**
     - memberships(me) give teamIDs and the scope.
     - Teams are fetched whole.
     - For songs and playlists: diff `*Versions(scope)` against `localVersions`, fetch the changed ids in chunks of 100, delete the missing ones.
     - Fetch whole: `playlistEntries(playlistIDs: all scope playlists)`, `tags(scope)`, `tagAssignments()`, `userSongSettings(me)`, `profile(me)`.
     - Apply everything as **one** `PullBatch`, with `skipEntityKeys` = `pendingEntityKeys()`.
  4. Save metadata and emit status.
- **Lifecycle:** `start()` subscribes to reachability (false→true runs `syncNow(.reachability)`), to realtime (debounced 1 s), and to `store.outboxChanges()` (debounced 0.5 s).
- **Tests (CapoFakes remote plus a real CapoStore in-memory DB once WP3a lands; a protocol fake before that):** first full pull; incremental pull fetches only changed ids; remote delete; pending local create survives a pull; conflict flow, and its resolutions keepMine, keepTheirs and keepBothAsCopy (resolution is implemented in WP3a's ConflictRepository, verified here end to end); retry and backoff; rejected op; scope change when removed from a team; offline no-op.

### WP4: CapoSupabase (Wave 1; Wave 2 for local-Supabase E2E)
- **Owns:** `CapoSupabase/{Auth,Rows,Remote,Realtime,Teams}/**`, `CapoSupabaseTests/**`, `supabase/config.toml` (add `"capo://auth/callback"` to `additional_redirect_urls` only).
- **Public API:**
  ```swift
  public final class SupabaseAuthService: AuthService { public init(client: SupabaseClient, callbackURL: URL) }
  public final class SupabaseRemoteSyncSource: RemoteSyncSource { public init(client: SupabaseClient) }
  public final class SupabaseRemoteWriter: RemoteWriter { public init(client: SupabaseClient) }
  public final class SupabaseTeamsRemote: TeamsRemote { public init(client: SupabaseClient, webBaseURL: URL) }
  public final class SupabaseRealtimeNotifier: RealtimeNotifier { public init(client: SupabaseClient) }
  ```
- **Rows:** hand-mirrored `Codable` DTOs with explicit `CodingKeys` (snake_case) for the 9 tables plus RPC results, mapped to and from CapoCore models.
  - Drift guard test: read `lib/supabase/database.types.ts` via `#filePath`, regex out each table's `Row` keys, and assert that each DTO's `CodingKeys: CaseIterable` covers them (allowlist `search_vector`).
- **Remote rules:**
  - Version queries select only `id,updated_at` and page with `.range(from, from+999)` until fewer than 1000 rows come back.
  - `in` filters are chunked to 100 ids.
  - `createSong` and `createPlaylist` insert with the client id. Error 23505 counts as applied (refetch the row).
  - `createPlaylist` generates a 12-character `[A-Z0-9]` share_code (as web) and inserts entries at positions 0…n.
  - `addSongToPlaylist` uses `rpc("add_song_to_playlist")`; a unique violation counts as applied.
  - `reorderPlaylist` uses two phases with OFFSET 10000 (as web).
  - `setSongTags` is delete then insert.
  - `upsertSongSettings` upserts `onConflict: "user_id,song_id"` with the client `updated_at`.
  - `updatePreferences` selects preferences, merges the patch while keeping unknown keys, then updates.
  - `setPlaylistArchived` sets `archived_at`.
  - Error classes:
    - 401, 403, 42501 and PGRST301 → `.rejected(.permissionDenied)`.
    - 23514 (check) and 22P02 → `.rejected(.invalidInput)`.
    - URLError and 5xx → throw (retry).
- **Auth:**
  - Client options: `flowType: .pkce`, `redirectToURL: callbackURL`, and (if available in the resolved version) `emitLocalSessionAsInitialSession: true`.
  - `sessionStream` yields the stored session immediately, even if it is expired and the device is offline.
  - `handleOpenURL` calls `client.auth.session(from:)`.
  - Use context7 or the installed sources for the exact API of the resolved version.
- **Tests (no network):** inject `URLSession` with a stub `URLProtocol` through `SupabaseClientOptions.GlobalOptions(session:)`. Assert request paths and queries, the pagination stop condition, the conflict path (empty PATCH result, then GET, then `.conflict`), duplicate create, error classification, and DTO decoding from `Tests/CapoSupabaseTests/Fixtures/*.json`.
- **Wave 2:** `CAPO_LOCAL_SUPABASE=1 swift test --filter LocalE2E`. It runs only against `http://127.0.0.1:54321` and only if it is already running (`pnpm supabase status`). It signs up a throwaway local user `ios-e2e+<uuid>@example.test`, never resets or stops the DB, and cleans up its own rows.

### WP5: Design system, Shell and Auth UI (Wave 1; WP11 follows)
- **Owns:** `CapoDesign/**` except Environment.swift, Resources and Generated; `CapoShellUI/**`; `CapoAuthUI/**`.
- **Shell:**
  - `CapoRootView` reads `AppDependencies`. It shows a ConfigurationMissing screen with a "Use demo" option, then AuthView when signed out, then Main.
  - An `@Observable SessionStore` runs `makeUserServices` on session and sign-out cleanup (asks "Erase offline data?" and warns about pending outbox ops).
  - Context switcher (Personal plus teams from `teams.teams()`), with the selection persisted in UserDefaults per user. It injects `\.appContext`, `\.currentTeamRole` and `\.capoActions`.
  - Layout: regular width uses a 3-column `NavigationSplitView` (sidebar: context, Library, Setlists, Teams, Conflicts badge, Settings). Compact width uses a `TabView` (Library, Setlists, Settings) with NavigationStacks.
  - Presents SongEditorView as a sheet and SetlistPerformanceView as a fullScreenCover.
  - Shows a sync status badge.
- **Design:**
  - Section accent per sectionType, default palette taken from `app/globals.css` (`--section-accent` rules), light and dark.
  - FlagBadge mapping (`FLAG_CONFIG` in rendered-song.tsx).
  - Tag chip using the hex colour.
  - Fonts.
- **Auth:** Google button; email/password form; sign-up only when non-production; error toasts.
- **Acceptance:** demo-mode screenshots on the iPhone and iPad simulators (saved to the agent's scratchpad); `CapoShellUI` builds; switching context re-scopes the library stream (fakes).

### WP6: Library (Wave 1)
- **Owns:** `CapoLibraryUI/**`, `CapoLibraryUITests/**`.
- **Scope:**
  - `LibraryView(selection:)`.
  - `.searchable` with 150 ms debounce, which builds a `SongQuery`.
  - Tag filter chips (any-of); status filter; BPM ranges (slow < 90, medium 90…120, fast > 120); sort (recent, title, artist, relevance when searching).
  - Rows show title, artist, key badge, bpm, tags, and a pending-changes dot.
  - Pull-to-refresh calls `syncNow(.manual)`.
  - Empty states.
  - Tag management sheet (create with a colour, delete) and an assign-tags sheet.
  - Swipe actions: add to setlist, which calls `capoActions.addSongsToPlaylist`.
  - `SongPickerView(onPick:)`, multi-select, used by WP8.
  - An `@Observable LibraryModel` restarts streams with `.task(id: query)`.
- **Tests:** query building from UI state (pure struct); debounce.

### WP7a: CapoRendering (Wave 1)
- **Owns:** `CapoRendering/**`, `CapoRenderingTests/**`.
- **Scope:** `ChordProContentView(rendered:style:onChordTap:)`, non-scrolling.
  - `.chordLyrics`: a custom `ChordLyricsLineLayout: Layout` that places each pair as chord over lyric fragment. Column width = max(chord width + 0.5 em gap, fragment width), measured with the real font. Lines wrap at pair boundaries when they exceed the proposed width. This intentionally diverges from the web's auto-shrink; the web-style "fit to width" is a COULD.
  - `.inline`: the text has chords tinted.
  - Comment, label, note, section label, volta card and box card styles mirror the web CSS class names.
  - Segment headers show "Name × N" and flags. Repeat and extend show the not-found state. Headers collapse on tap when `style.collapsible`.
  - `BalancedColumnsLayout`: for columns == 2, segments stay atomic and the break goes at the segment boundary nearest half the total height.
  - `showChords` and `showLyrics` toggles. Dynamic Type is ignored: font = 16pt × fontScale, as on the web.
- **Tests:** layout math (column balance, wrap points) with fixed sizes; snapshot-free.

### WP7b: Performance screen (Wave 1, started by A1 after WP1; finished in Wave 2)
- **Owns:** `CapoPerformanceUI/**`, `CapoPerformanceUITests/**`.
- **Scope:**
  - `SongPerformanceView(songID:navigation:)` loads from `songs.song(id:)` and `settings.songSettings`, then renders with `ChordProEngine.render` using L10n section labels.
  - Header: title, artist, key → effective key (`MusicTheory.calculateEffectiveKey`), capo shape key.
  - Controls: transpose −6…6, capo 0…12, font 0.5…3 step 0.25, columns 1/2 (persisted via `updatePreferences(lyricsColumns:)`), show chords. Settings are saved after a 500 ms debounce through `SettingsRepository`. Reset.
  - `PerformanceScrollView` is UIKit-backed (`UIScrollView` hosting the SwiftUI content). `AutoScrollController` drives it with `CADisplayLink` in px/s, using the web inference formula and limits; it stops at the bottom.
  - Keep-awake: `isIdleTimerDisabled` while visible.
  - Key commands via `UIKeyCommand` on the hosting controller:

    | Key | Action |
    |---|---|
    | ↓ / PageDown / Space | page down (85% viewport) |
    | ↑ / PageUp | page up |
    | → / ← | `navigation.onNext` / `navigation.onPrevious` |
    | `s` | toggle auto-scroll |
    | `[` `]` | speed |
    | `+` `−` | font |

    PageDown at the bottom calls `onNext` (SHOULD).
  - Edit button calls `capoActions.openEditor(.edit(id))` when the role is not viewer.
- **Tests:** speed inference; clamps; key-to-action mapping table; settings debounce.

### WP8: Playlists, setlist performance and pin (Wave 2; can start in Wave 1 on fakes)
- **Owns:** `CapoPlaylistsUI/**`, `CapoPlaylistsUITests/**`.
- **Scope:**
  - `PlaylistsView(selection:)`: active and archived; date; song count; pin badge plus offline-ready check.
  - `PlaylistDetailView(playlistID:onPerform:)`: ordered songs; drag reorder; add via `SongPickerView`; remove; edit name, description and date; archive; delete; pin toggle; share button (WP10 provides `SharingService` usage; button wired here, online only).
  - `SetlistPerformanceView(playlistID:startIndex:)`: horizontal paging of `SongPerformanceView` with `PerformanceNavigation` ("3 / 12", next and previous via pedals), next-song peek, close.
  - Works fully offline.
- **Tests:** reorder index math; navigation bounds.

### WP9: Editor and conflicts (Wave 2)
- **Owns:** `CapoEditorUI/**`, `CapoEditorUITests/**`.
- **Scope:**
  - `SongEditorView(request:onFinish:)`: metadata form (title required; artist; key picker; bpm; authored transpose and capo; notes).
  - Lyrics editor: `UITextView` wrapper with ChordPro highlighting (chords and directives), a `{` and `[` accessory bar (directive inserts from `features/lyrics-editor/data/chordpro-directives.ts`), and a live preview toggle using CapoRendering.
  - Saves through the repository (outbox). Delete with confirmation.
  - `ConflictsView`: side-by-side local vs server lyrics and metadata; keepMine, keepTheirs, keepBothAsCopy.
- **Tests:** highlighter tokenization; draft validation.

### WP10: Teams, invitations and sharing (Wave 2)
- **Owns:** `CapoTeamsUI/**`.
- **Scope:**
  - `TeamsView`: list with role; create (name, icon); member list (online); invite by email and role; revoke; change role; remove; transfer ownership; leave; delete (owner). Admin actions are gated by role.
  - `PendingInvitationsView`: accept and decline.
  - Online-only actions show an offline state.
  - Share sheet for a playlist: `sharing.ensureShareCode` then `shareURL` (`CAPO_WEB_URL/playlists/<code>`).

### WP11: Settings (Wave 2, WP5 agent)
- **Owns:** `CapoSettingsUI/**`.
- **Scope:**
  - Account (email, avatar, sign out).
  - Default lyrics columns; theme (system, light, dark), saved to preferences and applied through `preferredColorScheme`.
  - Language: shows the current one and links to iOS per-app language settings.
  - Sync (status, last sync, pending ops, "Sync now", conflicts link).
  - Environment name and server URL (read-only).
  - Erase local data. "Delete account" calls the `delete_user_account` RPC (SHOULD; confirm twice; hidden in production builds until the human approves).

### WP12: i18n generation (Wave 0, after WP2, same agent A2)
- **Owns:** `ios/scripts/gen-i18n.mjs`, `ios/i18n/**`, `CapoDesign/Resources/Localizable.xcstrings`, `CapoDesign/Generated/L10n.swift`.
- **API:** `L10n.Songs.title: String`, and `L10n.Songs.deleteSongConfirmDescription(title:) -> String`. Values come from `String(localized: "songs.deleteSongConfirmDescription", bundle: .module)` plus `String(format:)`.
- **Pre-seeded `ios.*` keys:** sync status words, offline and pinned texts, demo mode, server environment, performance shortcuts, setlist position, conflict actions, erase data.
- **Rule for other agents:** use `L10n` only. A missing key is written as `String(localized: "ios.<area>.<key>", defaultValue: "English", bundle: .module)` with `// TODO(i18n)`. WP12 harvests these in Wave 3.
- **Acceptance:** `node ios/scripts/gen-i18n.mjs && node ios/scripts/gen-i18n.mjs --check`; `python3 -m json.tool` on the xcstrings file; the CapoDesign build succeeds; output is deterministic (sorted keys).

### WP13: CI, scripts and docs (Wave 1, A0)
- **Owns:** `.github/workflows/ci.yml` (add the `changes` and `ios` jobs only), root `package.json` `scripts` (`ios:i18n`, `ios:i18n:check`, `ios:test`, `ios:build`), `ios/scripts/use-supabase.sh`, `ios/README.md`, `ios/HUMAN_TODO.md`.
- **CI:**
  - Job `changes`: `dorny/paths-filter@v3`, with `permissions: pull-requests: read`. Filter: `ios/**`, `lib/i18n/locales/**`, `features/lyrics-editor/utils/**`, `lib/music-theory.ts`.
  - Job `ios`: `needs: changes`, runs only when `ios == 'true'`. Runner: `macos-26` (or the newest macOS image with Xcode ≥ 26). Steps: checkout; `sudo xcode-select -s` to the latest Xcode; `node ios/scripts/gen-i18n.mjs --check`; `ios/scripts/test-packages.sh`; `ios/scripts/build-sim.sh` (`CODE_SIGNING_ALLOWED=NO`); timeout 45 min.
  - Not pushed or run by agents.
- **`use-supabase.sh`:**
  - `local [--device]` parses `pnpm supabase status -o env` (read-only) for the API URL and publishable or anon key. With `--device` it substitutes the LAN IP from `ipconfig getifaddr en0`. It writes the plist with `plutil`.
  - `production` copies `ios/Capo/Secrets.production.plist` (git-ignored, created by the human).

### WP14: Polish (Wave 3, COULD/SHOULD)
- External display scene. The Info.plist `UISceneConfigurations` entry for `UIWindowSceneSessionRoleExternalDisplayNonInteractive` is added by WP0. The display mirrors the current song in large font, with no controls.
- Chord diagrams: port `chord-diagram.tsx` and its chord db into a new `CapoRendering/Diagrams` folder (WP7a's agent).
- iPad keyboard shortcut discoverability (`UIMenuBuilder`), Stage Manager sizes, accessibility labels, `PrivacyInfo.xcprivacy` (WP0), launch performance.

## 4. Wave schedule

| Wave | Agents (peak) | WPs |
|---|---|---|
| **0** | 3 | **A0** WP0 (a→d). **A1** WP1: reads chordsheetjs and writes code immediately, verifying once WP0(a) lands. **A2** WP2 then WP12. |
| **1** (starts at WP0(b); UI agents at WP0(c)) | 8 | A0 WP13 plus integrator (keeps `build-sim.sh` green, reviews contracts). A1 WP1 → WP7b. A2 WP3a. A3 WP3b. A4 WP4. A5 WP5. A6 WP6 → WP8 (on fakes). A7 WP7a. |
| **2** (gate G1: CapoStore, CapoSync and CapoSupabase tests green; all UI targets build) | 7 | A0 WP-INT: real composition, then local-Supabase E2E, then device install. A1 WP7b finish plus pedal testing. A2+A3 data hardening and E2E with integration fixes (A3 drops to WP9 if idle). A4 WP4 Wave 2 (local E2E, realtime). A5 WP11 then WP9. A6 WP8. A7 WP10. |
| **3** | 4–5 | A0 final integration plus the §9 device checklist. A2 i18n harvest (WP12) plus accessibility. A7 WP14. A5/A6 bug bash and performance (2k-song library, 50-song setlist). |

**Integration order:**
1. WP0 contracts.
2. WP1, WP2, WP12.
3. WP3a, WP3b, WP4.
4. INT-1: real auth plus pull-only, read-only library.
5. WP5, WP6, WP7a, WP7b on real data.
6. INT-2: outbox push, settings LWW.
7. WP8, INT-3 (setlists offline).
8. WP9 (editing and conflicts).
9. WP10, WP11.
10. Wave 3.

**Merge and conflict rules (shared branch, shared worktree):**
- Stage and commit only owned paths: `git add <owned paths> && git commit -m "feat(ios/<wp>): …" -- <owned paths>`. Committing with a pathspec avoids sweeping in other agents' staged files.
- Never `git add -A` / `.`, `stash`, `reset --hard`, `checkout -- <others' files>`, `rebase`, `push`, force anything, or `--no-verify`.
- If `.git/index.lock` exists, wait and retry. Never delete it.
- Commit small, compiling increments (at least every ~30–60 min). Write whole files in a single write so other builds rarely see half-edited files.
- If your build fails in a path you do not own: wait about 3 minutes and retry. If it persists past 15 minutes, report it to A0. Never edit the file.
- A contract change (§5, Package.swift, pbxproj) is requested from A0, who makes it in one commit and updates CapoFakes in the same commit.
- Commit messages follow repo style and end with: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No network side effects:
  - No `supabase db push`, `link` or remote changes. No PRs.
  - Package resolution (reads) is OK.
  - `-allowProvisioningUpdates` device builds only by A0.
  - Local Supabase only if already running; no `db reset` or `stop`.

## 5. Shared interface definitions (WP0 writes these verbatim; frozen)

### 5.1 CapoCore/Models
```swift
public typealias UserID = UUID; public typealias SongID = UUID; public typealias PlaylistID = UUID
public typealias TagID = UUID;  public typealias TeamID = UUID

public struct ServerTimestamp: Hashable, Comparable, Sendable, Codable {
  public let raw: String                       // exact PostgREST string; used for eq filters
  public init(_ raw: String)
  public var date: Date? { get }               // parses 0–6 fractional digits, Z or ±hh:mm
  public static func now() -> ServerTimestamp  // ISO8601 with ms, UTC (client-authored LWW values)
  public static func < (l: Self, r: Self) -> Bool   // by date, then raw
  public init(from decoder: Decoder) throws; public func encode(to encoder: Encoder) throws  // single string
}
public enum AppContext: Hashable, Sendable, Codable {
  case personal(userID: UserID), team(teamID: TeamID)
  public var teamID: TeamID? { get }
}
public enum SongStatus: String, Codable, Sendable, CaseIterable { case draft, published, archived }
public enum TeamRole: String, Codable, Sendable, CaseIterable { case owner, admin, member, viewer
  public var canEditContent: Bool { get }  // != .viewer
  public var canManageMembers: Bool { get } // owner/admin
}
public struct Song: Identifiable, Hashable, Sendable, Codable {
  public var id: SongID; public var title: String; public var artist: String?; public var key: String?
  public var bpm: Int?; public var lyrics: String?; public var notes: String?
  public var transpose: Int; public var capo: Int; public var status: SongStatus
  public var userID: UserID?; public var teamID: TeamID?; public var createdBy: UserID
  public var createdAt: ServerTimestamp; public var updatedAt: ServerTimestamp
  public init(/* all fields, memberwise */)
}
public struct SongTag: Identifiable, Hashable, Sendable, Codable {
  public var id: TagID; public var name: String; public var color: String?  // CSS hex; UI default #6b7280
  public var userID: UserID?; public var teamID: TeamID?; public var createdAt: ServerTimestamp
}
public struct TagAssignment: Hashable, Sendable, Codable { public var songID: SongID; public var tagID: TagID }
public struct SongListItem: Identifiable, Hashable, Sendable {
  public var id: SongID; public var title: String; public var artist: String?; public var key: String?
  public var bpm: Int?; public var status: SongStatus; public var teamID: TeamID?; public var hasLyrics: Bool
  public var tags: [SongTag]; public var hasPendingChanges: Bool; public var createdAt: ServerTimestamp
}
public struct SongDraft: Hashable, Sendable {
  public var title: String; public var artist: String?; public var key: String?; public var bpm: Int?
  public var lyrics: String?; public var notes: String?; public var transpose: Int = 0; public var capo: Int = 0
  public var status: SongStatus = .published
}
/// nil = unchanged. Empty string / 0 bpm = clear (NULL), mirroring web mapFrontendUpdatesToDB.
public struct SongPatch: Hashable, Sendable, Codable {
  public var title: String?; public var artist: String?; public var key: String?; public var bpm: Int?
  public var lyrics: String?; public var notes: String?; public var transpose: Int?; public var capo: Int?
  public var status: SongStatus?
  public func merged(with newer: SongPatch) -> SongPatch
}
public struct Playlist: Identifiable, Hashable, Sendable, Codable {
  public var id: PlaylistID; public var name: String; public var description: String?
  public var date: String?  /* yyyy-MM-dd */; public var isPublic: Bool; public var allowGuestEditing: Bool
  public var shareCode: String?; public var shareExpiresAt: ServerTimestamp?; public var archivedAt: ServerTimestamp?
  public var userID: UserID?; public var teamID: TeamID?; public var createdBy: UserID
  public var createdAt: ServerTimestamp; public var updatedAt: ServerTimestamp
}
public struct PlaylistEntry: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID; public var playlistID: PlaylistID; public var songID: SongID; public var position: Int
}
public struct PlaylistSummary: Identifiable, Hashable, Sendable {
  public var playlist: Playlist; public var songCount: Int; public var isPinned: Bool
  public var isFullyAvailableOffline: Bool; public var id: PlaylistID { playlist.id }
}
public struct PlaylistDetail: Hashable, Sendable {
  public var playlist: Playlist; public var songs: [SongListItem] /* ordered by position */; public var isPinned: Bool
}
public struct PlaylistDraft: Hashable, Sendable {
  public var name: String; public var description: String?; public var date: String?; public var songIDs: [SongID] = []
}
public struct PlaylistPatch: Hashable, Sendable, Codable {
  public var name: String?; public var description: String?; public var date: String?
  public var isPublic: Bool?; public var allowGuestEditing: Bool?
}
public struct Team: Identifiable, Hashable, Sendable, Codable {
  public var id: TeamID; public var name: String; public var icon: String?; public var avatarURL: String?
  public var isPublic: Bool; public var createdBy: UserID; public var createdAt: ServerTimestamp; public var updatedAt: ServerTimestamp
}
public struct TeamMembership: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID; public var teamID: TeamID; public var userID: UserID; public var role: TeamRole; public var joinedAt: ServerTimestamp
}
public struct TeamWithRole: Identifiable, Hashable, Sendable { public var team: Team; public var role: TeamRole; public var id: TeamID { team.id } }
public struct ProfileSummary: Hashable, Sendable, Codable { public var id: UserID; public var email: String?; public var fullName: String?; public var avatarURL: String? }
public struct TeamMember: Identifiable, Hashable, Sendable { public var membership: TeamMembership; public var profile: ProfileSummary?; public var id: UUID { membership.id } }
public struct TeamInvitation: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID; public var teamID: TeamID; public var email: String; public var role: TeamRole
  public var invitedBy: UserID; public var token: String; public var expiresAt: ServerTimestamp
  public var acceptedAt: ServerTimestamp?; public var createdAt: ServerTimestamp
}
public struct PendingInvitation: Identifiable, Hashable, Sendable {
  public var invitation: TeamInvitation; public var teamName: String; public var inviterName: String?; public var id: UUID { invitation.id }
}
public enum JSONValue: Hashable, Sendable, Codable { case string(String), number(Double), bool(Bool), null, array([JSONValue]), object([String: JSONValue]) }
public enum AppTheme: String, Codable, Sendable, CaseIterable { case light, dark, system }
public struct UserPreferences: Hashable, Sendable, Codable {
  public var lyricsColumns: Int        // 1|2; default 2 (web mapJsonToPreferences)
  public var locale: String?; public var theme: AppTheme?; public var chordHand: String?
  public var palette: String?; public var uiFont: String?
  public var raw: [String: JSONValue]  // full JSON, preserved on write
  public init(json: [String: JSONValue]); public func json(applying patch: PreferencesPatch) -> [String: JSONValue]
  public static let `default`: UserPreferences
}
public struct PreferencesPatch: Hashable, Sendable, Codable { public var lyricsColumns: Int?; public var locale: String?; public var theme: AppTheme? }
public struct Profile: Hashable, Sendable, Codable {
  public var id: UserID; public var email: String?; public var fullName: String?; public var avatarURL: String?
  public var preferences: UserPreferences; public var updatedAt: ServerTimestamp
}
public struct UserSongSettings: Hashable, Sendable, Codable {
  public var songID: SongID; public var transpose: Int; public var capo: Int; public var fontSize: Double?; public var updatedAt: ServerTimestamp?
}
public struct EffectiveSongSettings: Hashable, Sendable {
  public var transpose: Int; public var capo: Int; public var fontSize: Double
  public static func resolve(song: Song, user: UserSongSettings?) -> EffectiveSongSettings  // user ?? song ?? defaults (font 1)
  public static let transposeRange = -6...6, capoRange = 0...12, fontSizeRange = 0.5...3.0
  public static let fontSizeStep = 0.25
}
public struct AppConfig: Hashable, Sendable {
  public var supabaseURL: URL; public var supabaseKey: String; public var webBaseURL: URL
  public var environmentName: String; public var authCallbackURL: URL   // capo://auth/callback
  public static func load(from bundle: Bundle) -> AppConfig?          // Secrets.plist
}
public struct AuthSession: Hashable, Sendable {
  public var userID: UserID; public var email: String?; public var fullName: String?; public var avatarURL: URL?; public var provider: String?
}
public enum CapoError: Error, Hashable, Sendable {
  case notAuthenticated, offlineUnavailable, permissionDenied, notFound, conflict
  case invalidInput(String), server(String), configurationMissing
}
public struct SongConflict: Identifiable, Hashable, Sendable { public var id: UUID /* op id */; public var local: Song; public var server: Song?; public var detectedAt: Date }
public enum ConflictResolution: Hashable, Sendable { case keepMine, keepTheirs, keepBothAsCopy }
public enum SyncPhase: Hashable, Sendable { case idle, pushing, pulling, offline, error(String) }
public struct SyncStatus: Hashable, Sendable { public var phase: SyncPhase; public var lastSuccessAt: Date?; public var pendingOperations: Int; public var conflicts: Int; public var failedOperations: Int }
public enum SyncReason: Hashable, Sendable { case appLaunch, foreground, manual, realtime, reachability, outboxEnqueued }
public struct SyncScope: Hashable, Sendable { public var userID: UserID; public var teamIDs: [TeamID] }
public struct RowVersion: Hashable, Sendable { public var id: UUID; public var updatedAt: ServerTimestamp }
public struct RealtimeChange: Hashable, Sendable { public var table: String }
```

### 5.2 CapoCore/Contracts: local (consumed by UI; implemented by CapoStore and CapoFakes)
```swift
public enum SongSort: String, Sendable, CaseIterable { case recent, title, artist, relevance }
public struct SongQuery: Hashable, Sendable {
  public var context: AppContext; public var searchText: String = ""; public var tagIDs: Set<TagID> = []
  public var statuses: Set<SongStatus> = [.published, .draft]; public var bpmRange: ClosedRange<Int>? = nil
  public var sort: SongSort = .recent
}
public protocol SongRepository: Sendable {
  func songs(_ query: SongQuery) -> AsyncStream<[SongListItem]>
  func song(id: SongID) -> AsyncStream<Song?>
  func fetchSong(id: SongID) async throws -> Song?
  func create(_ draft: SongDraft, in context: AppContext) async throws -> Song
  func update(id: SongID, _ patch: SongPatch) async throws
  func delete(id: SongID) async throws
  func setTags(songID: SongID, tagIDs: [TagID]) async throws
  func tags(forSong id: SongID) -> AsyncStream<[SongTag]>
}
public protocol TagRepository: Sendable {
  func tags(in context: AppContext) -> AsyncStream<[SongTag]>
  func create(name: String, color: String?, in context: AppContext) async throws -> SongTag
  func delete(id: TagID) async throws
}
public protocol PlaylistRepository: Sendable {
  func playlists(in context: AppContext, includeArchived: Bool) -> AsyncStream<[PlaylistSummary]>
  func playlist(id: PlaylistID) -> AsyncStream<PlaylistDetail?>
  func create(_ draft: PlaylistDraft, in context: AppContext) async throws -> Playlist
  func update(id: PlaylistID, _ patch: PlaylistPatch) async throws
  func delete(id: PlaylistID) async throws
  func setArchived(id: PlaylistID, _ archived: Bool) async throws
  func addSongs(_ songIDs: [SongID], to playlistID: PlaylistID) async throws
  func removeSong(_ songID: SongID, from playlistID: PlaylistID) async throws
  func reorder(playlistID: PlaylistID, songIDs: [SongID]) async throws
  func setPinned(_ pinned: Bool, playlistID: PlaylistID) async throws
}
public protocol SettingsRepository: Sendable {
  func songSettings(songID: SongID) -> AsyncStream<UserSongSettings?>
  func saveSongSettings(_ settings: UserSongSettings) async throws
  func preferences() -> AsyncStream<UserPreferences>
  func updatePreferences(_ patch: PreferencesPatch) async throws
}
public protocol TeamRepository: Sendable {
  func teams() -> AsyncStream<[TeamWithRole]>                         // local
  func members(teamID: TeamID) async throws -> [TeamMember]            // online-only below
  func invitations(teamID: TeamID) async throws -> [TeamInvitation]
  func pendingInvitationsForMe() async throws -> [PendingInvitation]
  func createTeam(name: String, icon: String?, isPublic: Bool) async throws -> Team
  func updateTeam(id: TeamID, name: String, icon: String?) async throws
  func deleteTeam(id: TeamID) async throws
  func leaveTeam(id: TeamID) async throws
  func invite(email: String, role: TeamRole, teamID: TeamID) async throws -> TeamInvitation
  func revokeInvitation(id: UUID) async throws
  func acceptInvitation(token: String) async throws -> TeamID
  func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws
  func removeMember(userID: UserID, teamID: TeamID) async throws
  func transferOwnership(teamID: TeamID, to userID: UserID) async throws
}
public protocol SharingService: Sendable {
  func ensureShareCode(playlistID: PlaylistID) async throws -> String   // online, rpc ensure_share_code
  func shareURL(forCode code: String) -> URL                            // webBaseURL/playlists/<code>
}
public protocol ConflictRepository: Sendable {
  func conflicts() -> AsyncStream<[SongConflict]>
  func resolve(_ conflictID: UUID, with resolution: ConflictResolution) async throws
}
public protocol SyncService: Sendable {
  func status() -> AsyncStream<SyncStatus>
  func syncNow(reason: SyncReason) async
  func start() async
  func stop() async
}
public protocol AuthService: Sendable {
  func sessionStream() -> AsyncStream<AuthSession?>   // first element = restored local session (offline-safe)
  func currentSession() async -> AuthSession?
  func signInWithGoogle() async throws
  func signIn(email: String, password: String) async throws
  func signUp(email: String, password: String) async throws
  func signOut() async throws
  func handleOpenURL(_ url: URL) async -> Bool
}
public struct UserServices: Sendable {
  public var userID: UserID
  public var songs: any SongRepository; public var tags: any TagRepository; public var playlists: any PlaylistRepository
  public var settings: any SettingsRepository; public var teams: any TeamRepository; public var sharing: any SharingService
  public var conflicts: any ConflictRepository; public var sync: any SyncService
  public var tearDown: @Sendable (_ eraseLocalData: Bool) async -> Void
  public init(/* memberwise */)
}
public struct AppDependencies: Sendable {
  public var config: AppConfig?; public var isDemo: Bool; public var auth: any AuthService
  public var makeUserServices: @Sendable (AuthSession) async throws -> UserServices
  public init(/* memberwise */)
}
```

### 5.3 CapoCore/Contracts: remote (implemented by CapoSupabase and CapoFakes; consumed by CapoSync and CapoStore)
```swift
public protocol RemoteSyncSource: Sendable {
  func memberships(userID: UserID) async throws -> [TeamMembership]
  func teams(ids: [TeamID]) async throws -> [Team]
  func songVersions(scope: SyncScope) async throws -> [RowVersion]
  func songs(ids: [SongID]) async throws -> [Song]
  func playlistVersions(scope: SyncScope) async throws -> [RowVersion]
  func playlists(ids: [PlaylistID]) async throws -> [Playlist]
  func playlistEntries(playlistIDs: [PlaylistID]) async throws -> [PlaylistEntry]
  func tags(scope: SyncScope) async throws -> [SongTag]
  func tagAssignments() async throws -> [TagAssignment]          // RLS-scoped to own/team songs
  func userSongSettings(userID: UserID) async throws -> [UserSongSettings]
  func profile(userID: UserID) async throws -> Profile
}
public enum OutboxOperation: Hashable, Sendable, Codable {
  case createSong(Song)
  case updateSong(id: SongID, patch: SongPatch, base: ServerTimestamp)
  case deleteSong(id: SongID)
  case setSongTags(songID: SongID, tagIDs: [TagID])
  case createTag(SongTag)
  case deleteTag(id: TagID)
  case upsertSongSettings(UserSongSettings, userID: UserID)
  case updatePreferences(PreferencesPatch, userID: UserID)
  case createPlaylist(Playlist, songIDs: [SongID])
  case updatePlaylist(id: PlaylistID, patch: PlaylistPatch)
  case deletePlaylist(id: PlaylistID)
  case setPlaylistArchived(id: PlaylistID, archivedAt: ServerTimestamp?)
  case addSongToPlaylist(playlistID: PlaylistID, songID: SongID)
  case removeSongFromPlaylist(playlistID: PlaylistID, songID: SongID)
  case reorderPlaylist(playlistID: PlaylistID, songIDs: [SongID])
  public var entityKey: String { get }   // "song:<id>", "playlist:<id>", "tag:<id>", "settings:<songID>", "prefs"
}
public enum RemoteApplyResult: Hashable, Sendable {
  case applied(serverSong: Song?)        // createSong/updateSong return the server row
  case conflict(server: Song?)           // updateSong base mismatch (nil = deleted remotely)
  case rejected(CapoError)               // permanent; drop & surface
}
public protocol RemoteWriter: Sendable { func apply(_ op: OutboxOperation) async throws -> RemoteApplyResult } // throw = transient
public protocol TeamsRemote: Sendable {
  func members(teamID: TeamID) async throws -> [TeamMember]
  func invitations(teamID: TeamID) async throws -> [TeamInvitation]
  func pendingInvitations(email: String) async throws -> [PendingInvitation]
  func createTeam(name: String, icon: String?, isPublic: Bool) async throws -> Team
  func updateTeam(id: TeamID, name: String, icon: String?) async throws
  func deleteTeam(id: TeamID) async throws
  func leaveTeam(id: TeamID) async throws
  func invite(email: String, role: TeamRole, teamID: TeamID) async throws -> TeamInvitation
  func revokeInvitation(id: UUID) async throws
  func acceptInvitation(token: String) async throws -> TeamID
  func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws
  func removeMember(userID: UserID, teamID: TeamID) async throws
  func transferOwnership(teamID: TeamID, to userID: UserID) async throws
  func ensureShareCode(playlistID: PlaylistID) async throws -> String
}
public protocol RealtimeNotifier: Sendable { func changes(scope: SyncScope) -> AsyncStream<RealtimeChange> }
public protocol ReachabilityMonitor: Sendable { func isOnline() -> AsyncStream<Bool> }
```
CapoCore/Util: `public final class ValueSubject<Value: Sendable>: Sendable`, with `send(_:)`, `value`, and `stream() -> AsyncStream<Value>` (multicast; replays the current value).

### 5.4 CapoStore/Contracts/LocalSyncStore.swift
```swift
public enum SyncedTable: String, Sendable, CaseIterable { case songs, playlists }
public struct PullBatch: Sendable {
  public var teams: [Team]?; public var memberships: [TeamMembership]?
  public var upsertSongs: [Song] = []; public var deleteSongIDs: [SongID] = []
  public var upsertPlaylists: [Playlist] = []; public var deletePlaylistIDs: [PlaylistID] = []
  public var playlistEntries: [PlaylistEntry]?; public var tags: [SongTag]?; public var tagAssignments: [TagAssignment]?
  public var userSongSettings: [UserSongSettings]?; public var profile: Profile?
  public var skipEntityKeys: Set<String> = []
}
public struct OutboxRecord: Identifiable, Sendable { public var id: Int64; public var opID: UUID; public var operation: OutboxOperation; public var attempts: Int; public var createdAt: Date; public var lastError: String? }
public enum OutboxOutcome: Sendable { case applied(serverSong: Song?), retryLater(error: String, nextAttemptAt: Date), rejected(CapoError), conflict(server: Song?) }
public struct SyncMetadata: Codable, Hashable, Sendable { public var lastPullAt: Date?; public var lastPushAt: Date?; public var lastError: String? }
public protocol LocalSyncStore: Sendable {
  func localVersions(of table: SyncedTable) async throws -> [UUID: ServerTimestamp]
  func localPlaylistIDs() async throws -> [PlaylistID]
  func apply(_ batch: PullBatch) async throws
  func nextPendingOperations(limit: Int, now: Date) async throws -> [OutboxRecord]   // FIFO/entity, skips blocked
  func markInflight(_ id: Int64) async throws
  func complete(_ id: Int64, outcome: OutboxOutcome) async throws
  func pendingEntityKeys() async throws -> Set<String>
  func outboxChanges() -> AsyncStream<Int>                                           // pending count
  func syncMetadata() async throws -> SyncMetadata
  func saveSyncMetadata(_ metadata: SyncMetadata) async throws
  func statusCounts() async throws -> (pending: Int, conflicts: Int, failed: Int)
}
```

### 5.5 CapoChordPro/RenderModel.swift (public, frozen) and engine entry points
```swift
public enum SectionFlag: String, CaseIterable, Sendable, Codable { case attention, skip, forte, piano, vamp, tag, `break`, inline, label }
public struct ChordProRenderOptions: Hashable, Sendable {
  public var transpose: Int; public var capo: Int
  public var sectionLabels: [String: String]   // chorus, verse, bridge, tab, grid, intro, outro, pre_chorus
  public var commentLabel: String
  public init(transpose: Int, capo: Int, sectionLabels: [String: String], commentLabel: String)
}
public struct ChordLyricPair: Hashable, Sendable { public var chord: String /* "" = none */; public var lyrics: String }
public enum InlinePart: Hashable, Sendable { case text(String), chord(String) }
public indirect enum BodyLine: Hashable, Sendable {
  case chordLyrics([ChordLyricPair])            // web: clp-pair (min-width = max(chord.count, lyrics.count) ch)
  case inline([InlinePart])                     // already whitespace-collapsed & trimmed
  case text(String)                             // plain line, may be "" (directive lines, blanks)
  case comment(String), label(String), performanceNote(String)
  case sectionLabel(type: String, label: String)
  case volta(label: String, body: SongBody)     // label "" = none
  case box(label: String, body: SongBody)
}
public struct SongBody: Hashable, Sendable { public var lines: [BodyLine] }   // legacy HTML = lines joined by "\n"
public enum LyricsSegment: Hashable, Sendable {
  case normal(SongBody)
  case section(name: String, sectionType: String, body: SongBody, count: Int, flags: [SectionFlag], inline: Bool)
  case repeatRef(name: String, displayLabel: String?, count: Int, body: SongBody, found: Bool, sectionType: String, flags: [SectionFlag])
  case extend(name: String, displayLabel: String?, count: Int, body: SongBody, found: Bool, sectionType: String, flags: [SectionFlag])
}
public struct RenderedSong: Hashable, Sendable { public var segments: [LyricsSegment]; public var hasComplexSegments: Bool { get } }
public enum ChordProEngine { public static func render(_ lyrics: String, options: ChordProRenderOptions) -> RenderedSong }
public enum LegacyHTMLSerializer { public static func html(_ body: SongBody, commentLabel: String) -> String }
public enum ChordTransposer {
  public static func transpose(_ chord: String, by delta: Int) -> String
  public static func normalize(_ chord: String, toKey key: String) -> String
}
public enum MusicTheory {
  public static func transposeKey(_ key: String, semitones: Int) -> String
  public static func capoKey(_ key: String, capo: Int) -> String
  public static func effectiveKey(_ key: String, transpose: Int, capo: Int) -> String
}
```

### 5.6 CapoSupabase client factory (WP0)
```swift
public enum SupabaseClientFactory { public static func make(config: AppConfig, session: URLSession = .shared) -> SupabaseClient }
```

### 5.7 CapoDesign: Environment.swift (WP0, frozen) and component stubs (WP0 creates, WP5 owns)
```swift
public enum SongEditorRequest: Hashable, Sendable { case create, edit(SongID) }
public struct CapoActions {
  public var openSong: @MainActor (SongID) -> Void
  public var openEditor: @MainActor (SongEditorRequest) -> Void
  public var performSetlist: @MainActor (PlaylistID, Int) -> Void
  public var addSongsToPlaylist: @MainActor ([SongID]) -> Void
  public var showConflicts: @MainActor () -> Void
  public static let noop: CapoActions
}
extension EnvironmentValues {
  public var userServices: UserServices { get set }     // default UserServices.preview (CapoFakes)
  public var appContext: AppContext { get set }         // default .personal(userID: FakeIDs.user)
  public var currentTeamRole: TeamRole? { get set }     // nil = personal (full rights)
  public var capoActions: CapoActions { get set }
}
// stubs:
public enum SectionAccent { public static func color(for sectionType: String) -> Color }
public struct FlagBadge: View { public init(_ flag: SectionFlag) }
public struct TagChip: View { public init(name: String, colorHex: String?, isSelected: Bool = false) }
public struct SyncStatusBadge: View { public init(status: SyncStatus) }
public struct EmptyStateView: View { public init(title: String, message: String?, systemImage: String) }
public enum CapoFont { public static let baseLyricsPointSize: CGFloat; public static func lyrics(scale: Double) -> Font; public static func chord(scale: Double) -> Font }
```

### 5.8 UI entry points (WP0 stubs; owners keep the signatures)
```swift
// CapoRendering
public struct SongRenderStyle: Hashable, Sendable { public var fontScale = 1.0, columns = 1, showChords = true, showLyrics = true, collapsible = true; public init() }
public struct ChordProContentView: View { public init(rendered: RenderedSong, style: SongRenderStyle, onChordTap: ((String) -> Void)? = nil) }
// CapoAuthUI
public struct AuthView: View { public init() }
// CapoLibraryUI
public struct LibraryView: View { public init(selection: Binding<SongID?>) }
public struct SongPickerView: View { public init(excluding: Set<SongID> = [], onPick: @escaping ([SongID]) -> Void) }
// CapoPerformanceUI
public struct PerformanceNavigation { public var positionLabel: String?; public var onNext: (@MainActor () -> Void)?; public var onPrevious: (@MainActor () -> Void)?
  public init(positionLabel: String? = nil, onNext: (@MainActor () -> Void)? = nil, onPrevious: (@MainActor () -> Void)? = nil); public static let standalone: PerformanceNavigation }
public struct SongPerformanceView: View { public init(songID: SongID, navigation: PerformanceNavigation = .standalone) }
// CapoPlaylistsUI
public struct PlaylistsView: View { public init(selection: Binding<PlaylistID?>) }
public struct PlaylistDetailView: View { public init(playlistID: PlaylistID) }   // perform via capoActions.performSetlist
public struct SetlistPerformanceView: View { public init(playlistID: PlaylistID, startIndex: Int = 0, onClose: @escaping () -> Void) }
// CapoEditorUI
public struct SongEditorView: View { public init(request: SongEditorRequest, onFinish: @escaping (SongID?) -> Void) }
public struct ConflictsView: View { public init() }
// CapoTeamsUI
public struct TeamsView: View { public init() }
public struct PendingInvitationsView: View { public init() }
// CapoSettingsUI
public struct SettingsView: View { public init() }
// CapoShellUI
public struct CapoRootView: View { public init(dependencies: AppDependencies) }
// CapoAppKit
public struct CapoAppScene: Scene { public init() }
```
UI convention: each screen has an `@Observable @MainActor` model fed by `.task(id:) { for await v in stream { model.x = v } }`. Views never import CapoStore or CapoSupabase.

## 6. Verification commands

Every agent passes `-derivedDataPath ios/build/dd-<WP>`.

**Simulator assignment (tests and smoke runs):**

| Agent / WP | Simulator | ID |
|---|---|---|
| WP5 | iPhone 15 Pro | `3303ED5C-D8CE-4E2A-AAED-C04973985FB3` |
| WP6 | iPhone 15 | `81B1891C-0684-4CD3-B046-A49C35F661D6` |
| WP7a | iPad Pro 13 M4 | `32F8D7D2-9EFC-4B41-98C6-D17267D35BD6` |
| WP7b | iPad Pro 11 M4 | `0422CCC7-27CE-42D3-8074-CB152F7B846E` |
| WP8 | iPhone 15 Pro Max | `83AFDDBB-E5D7-4109-9E7D-A6B884C9E5DF` |
| WP9 | iPad Air 11 M2 | `0938D679-E6B5-47F0-A11D-C71FFA3F9C7F` |
| WP10 / WP11 | iPhone 15 Plus | `ACBC216B-A715-48BC-AAAE-AACABC032DE2` |
| A0 | iPhone SE | `CF3DB103-E0A2-44B0-BE8D-2EDCD74C0E9F` |

**Packages that run on the host:**
```bash
cd ios/Packages/CapoCore && swift test                          # WP0, WP1 (WP1: --filter CapoChordProTests)
cd ios/Packages/CapoData && swift test --filter CapoStoreTests  # WP3a   (CapoSyncTests for WP3b)
cd ios/Packages/CapoSupabase && swift test                      # WP4
```

**UI package:**
```bash
cd ios/Packages/CapoUI
xcodebuild -scheme <OwnTarget> -destination 'generic/platform=iOS Simulator' -derivedDataPath ../../build/dd-<WP> build
xcodebuild -scheme CapoUI-Package -destination 'platform=iOS Simulator,id=<assigned>' -derivedDataPath ../../build/dd-<WP> -only-testing:<OwnTarget>Tests test
```
Confirm scheme names first with `xcodebuild -list`.

**App build (everyone, before each commit touching Swift):**
```bash
xcodebuild -project ios/Capo/Capo.xcodeproj -scheme Capo -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/build/dd-<WP> CODE_SIGNING_ALLOWED=NO build
```

**Simulator smoke test (demo mode):**
```bash
xcrun simctl boot <id> 2>/dev/null; xcrun simctl install <id> ios/build/dd-<WP>/Build/Products/Debug-iphonesimulator/Capo.app
xcrun simctl launch <id> com.mfuentesg.capo -CapoDemoMode YES
xcrun simctl io <id> screenshot <agent scratchpad>/wp-<n>.png
```

**Device (A0 only):**
```bash
xcodebuild -project ios/Capo/Capo.xcodeproj -scheme Capo -configuration Debug -destination 'id=00008110-00141CE43AC2401E' \
  -derivedDataPath ios/build/dd-device -allowProvisioningUpdates build
xcrun devicectl device install app --device 00008110-00141CE43AC2401E ios/build/dd-device/Build/Products/Debug-iphoneos/Capo.app
xcrun devicectl device process launch --device 00008110-00141CE43AC2401E com.mfuentesg.capo
```
For the iPad, use id `00008112-00111110215A201E`.

**Web side and tooling:**
```bash
pnpm test -- --testPathPattern='golden'; pnpm lint; pnpm typecheck; pnpm i18n:validate
node ios/scripts/gen-i18n.mjs --check
plutil -lint ios/Capo/Capo.xcodeproj/project.pbxproj ios/Capo/Config/Info.plist
```

**Scripts:**
- `ios/scripts/test-packages.sh` runs all three `swift test` commands plus the CapoUI-Package test on the first available iPhone simulator.
- `ios/scripts/build-sim.sh` is the app build above.

## 7. Scope labels

**MUST (MVP = P1–P3):**
- Google and email auth with offline session restore.
- Personal/team context switcher.
- Full pull sync to SQLite.
- Library with FTS search, tag, status and BPM filters, and sort.
- ChordPro parity, proven by goldens.
- Performance view: transpose, capo, font, 1–2 columns, show chords, BPM auto-scroll, keep-awake, pedal and keyboard keys.
- Per-user song settings (LWW, via outbox).
- Playlists list and detail (read), setlist performance mode, everything usable offline, pin badge and offline-ready indicator.
- en/es i18n; iPad split view plus iPhone tabs; settings basics (sign out, columns, theme, sync status).
- Demo mode.

**SHOULD:**
- Song create, edit and delete with outbox and conflict UI (P4).
- Tag management.
- Playlist editing (create, reorder, add, remove, archive).
- Realtime-triggered sync.
- Teams list plus accepting invitations; share link.
- Collapsible sections; PageDown-at-end moves to the next song.
- Account deletion (required before the App Store).

**COULD:**
- Team administration (invite, roles, transfer, delete).
- External display, chord diagrams, fit-to-width font shrink.
- "All libraries" context, GitHub OAuth, universal links for invitations and shares.
- Spotlight indexing, metronome.
- Sign in with Apple (human-gated).

## 8. HUMAN_TODO (WP13 writes `ios/HUMAN_TODO.md`)
1. Production Supabase → Auth → URL Configuration: add `capo://auth/callback` to Redirect URLs. Locally, after WP4's `config.toml` change, run `pnpm supabase stop && pnpm supabase start`.
2. Local Google OAuth needs `SUPABASE_AUTH_EXTERNAL_GOOGLE_CLIENT_ID` and `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET` in your shell env. Otherwise use email/password locally.
3. Choose a backend: run `ios/scripts/use-supabase.sh local [--device]`, or create `ios/Capo/Secrets.production.plist` and run `… production`. Physical device plus local stack: the Mac and device must share a LAN, allow incoming connections in the macOS firewall, and accept the iOS Local Network prompt.
4. Sign in with Apple, a release blocker under App Store guideline 4.8 because Google login is offered: create a Services ID and key in the Apple Developer portal, enable the Apple provider in Supabase, and add the Sign in with Apple capability to App ID `com.mfuentesg.capo`. The integrator then adds the entitlement.
5. Account deletion: approve exposing `delete_user_account` in production builds.
6. CI: confirm a macOS runner image with Xcode ≥ 26 and the extra Actions minutes, then push and open the PR yourself. Agents don't push.
7. Optional: universal links (AASA on the web domain plus Associated Domains entitlement) for invitation and share links.
8. App Store Connect app record, privacy nutrition labels; review `PrivacyInfo.xcprivacy`.
9. Make sure Developer Mode is still enabled on both devices and the signing team account is logged into Xcode.

## 9. Final integration and on-device checklist (A0, Wave 3)
1. All §6 commands pass. `git status` is clean, and there are no secrets in history: `git log -p -- ios | grep -i 'eyJ'` returns nothing.
2. Install on the iPhone 13 Pro and the iPad Pro 11. Sign in (Google against production, chosen by the human; email against local).
3. The library count per context matches the web. Search for "cancion" finds "Canción". Tag filter works.
4. For three real songs at transpose ±2 and capo 3, chords match the web side by side.
5. Airplane mode, force quit, cold start: the session is restored, and library, search, song view and a 20-song setlist all work, including pedal next/previous.
6. Auto-scroll at BPM 70 and 140 stops at the bottom. The screen doesn't lock for 5 minutes.
7. Change transpose offline, go back online: the web shows the user setting. Edit lyrics offline while the web edits the same song: conflict UI, then each of the 3 resolutions.
8. iPad: rotation, 2 columns, Stage Manager resize, hardware keyboard shortcuts, split-view navigation.
9. Spanish device language shows Spanish strings with no raw keys.
10. Sign out with "erase" deletes the database file, and a different account sees no previous data.

## 10. Risks and mitigations
- **chordsheetjs parity** (parser item types, transpose quirks, `{key}` normalization per chunk, whitespace and trim semantics): WP2 expands the corpus, goldens are byte-exact, and divergences need the integrator's sign-off. CRLF input is untested; normalize `\r\n` to `\n` before render on both sides is **not** allowed (it would diverge), so add a CRLF fixture in Wave 3 if real data contains it.
- **Hand-written pbxproj:** single owner, one product link, `plutil -lint` plus `xcodebuild -list` after every edit.
- **Shared worktree build breakage:** per-owner targets, whole-file writes, separate derived data, retry rules.
- **Swift 6 strict concurrency friction:** Sendable contracts, AsyncStream at the boundaries, `defaultIsolation(MainActor)` for UI. Agents may use `@preconcurrency import` for third-party modules.
- **supabase-swift API drift:** pin via `Package.resolved`, and WP4 checks the installed sources or context7. Offline session restore is a MUST test.
- **PostgREST limits** (1000 rows, URL length): range paging, chunks of 100 ids.
- **Timestamp precision breaking optimistic concurrency:** raw `ServerTimestamp` only.
- **Public-playlist RLS leaking foreign songs into sync:** explicit scope filter in every query, plus a unit test.
- **Clock skew in LWW settings:** acceptable for a single user; document it.
- **Two-column layout and wrap performance on long songs:** WP7a perf test with 300 lines at under 16 ms layout on the iPad simulator.
- **xcodebuild package scheme building sibling targets during `-only-testing`:** tolerate it (retry rule); targeted product schemes for build verification.
- **Scope:** if Wave 2 slips, ship MUST only. WP9, WP10 and WP14 are cuttable without touching contracts.
- **Server changes:** none required. No migration drafts are planned. A future transactional `set_song_tags` or `reorder_playlist` RPC would be drafted with `pnpm supabase migration new` and never applied.

### Critical Files for Implementation
- /Users/mfuentesg/code/capo/.claude/worktrees/ios-p0/features/lyrics-editor/utils/song-pipeline.ts
- /Users/mfuentesg/code/capo/.claude/worktrees/ios-p0/node_modules/chordsheetjs/lib/module.js (Key, Chord and Song transpose, ≈ lines 860–900, 1919–2420, 3470–3520, 6700–6800)
- /Users/mfuentesg/code/capo/.claude/worktrees/ios-p0/ios/Capo/Capo.xcodeproj/project.pbxproj
- /Users/mfuentesg/code/capo/.claude/worktrees/ios-p0/lib/supabase/database.types.ts
- /Users/mfuentesg/code/capo/.claude/worktrees/ios-p0/features/songs/api/songsApi.ts (plus `playlists/api/playlistsApi.ts`, `songs/api/user-preferences-api.ts`, `teams/api/teamsApi.ts`)
