## WP0 notes

### Deviations from PLAN §5 (all additive; no frozen signature changed)
- Every public struct got an explicit `public init` with all stored properties (Swift does not
  synthesize public memberwise inits). Optional/defaulted fields default to `nil` / the §5 default
  in `SongDraft`, `SongPatch`, `PlaylistDraft`, `PlaylistPatch`, `PreferencesPatch`, `SongQuery`,
  `SyncStatus`, `SyncMetadata`, `PullBatch`.
- Small public helpers: `SongTag.defaultColor` (`#6b7280`), `JSONValue.stringValue`,
  `AppConfig.defaultAuthCallbackURL`, `OutboxOperation.key(_:_:)`, `ValueSubject.update(_:)`.
- `OutboxOperation.entityKey` uses **lowercased** UUID strings (`song:3f2a…`), matching Postgres.
- `AppConfig.load(from:)` requires `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `CAPO_WEB_URL`;
  `CAPO_ENV_NAME` defaults to `production` when absent.
- `UserPreferences.palette` / `uiFont` accept any string (web validates against its palette/font
  lists; iOS does not use them yet).
- `ValueSubject` uses `OSAllocatedUnfairLock` (iOS 16 / macOS 13), streams buffer newest 1.
- `CapoChordPro/Engine/StubEngine.swift` stubs all four entry points (`ChordProEngine`,
  `LegacyHTMLSerializer`, `ChordTransposer`, `MusicTheory`) so consumers compile; WP1 replaces it.
- The placeholder `Localizable.xcstrings` landed in step (a) because `.process("Resources")`
  needs the folder to exist.
- `SupabaseClientFactory` passes `emitLocalSessionAsInitialSession: true` (available in
  supabase-swift 2.55.4) and uses the Darwin default (Keychain) auth storage.

### Step (c)
- `CapoDesign` re-exports `CapoCore` (in Environment.swift) and `CapoChordPro` (in Components.swift)
  with `@_exported import`, so UI targets only need `import CapoDesign`.
- `CapoActions` and `SongRenderStyle` are declared `nonisolated` (the UI targets default to
  MainActor isolation, and environment defaults must be nonisolated). `CapoActions` also has a
  defaulted `init` (every closure a no-op); `noop` uses it.
- Environment values use `@Entry`.
- Extra CapoDesign helper: `StubScreen(_:)`, the placeholder used by every WP0 entry stub.
  Owners may stop using it; WP5 may delete it once no target references it.
- CapoFakes beyond §3: `BackendState` (the whole in-memory data set), `FakeSeed.demo(userID:)`,
  `UserServices.fake(backend:sync:)`, `FakeTeamsRemote`, `FakeRealtimeNotifier.emit(_:)`,
  `FakeError`. `FakeRemoteSyncSource` serves a `BackendState`, filters by scope like the real
  remote, records `calls` / `requestedSongIDs`, and `failNext(_:with:)` queues per-method errors.
  `FakeRemoteWriter` consumes `enqueue(_:)` / `enqueueFailure(_:)` FIFO, else echoes
  (`createSong` → `.applied(song)`, everything else `.applied(nil)`).
- Demo seed: the 4 original corpus files are embedded in `CapoFakes/CorpusLyrics.swift`
  (copied by hand; the fakes cannot read repo files on device). 8 personal + 4 team songs.
- `FakeAuthService` starts signed in as the demo user, so demo mode opens straight into Main.
- `L10n.swift` / `Localizable.xcstrings` are still WP0 placeholders at the time of (c); WP12 overwrites.

### Step (d)
- `CapoComposition.make(config:)` reads the `-CapoDemoMode YES` launch argument through
  `UserDefaults.standard` (the argument domain). The live path logs and returns `.demo` until WP-INT.
- `Config/Info.plist` puts `UIApplicationSupportsMultipleScenes` inside `UIApplicationSceneManifest`,
  where iOS reads it. The external-display `UISceneConfigurations` entry (WP14) is **not** added
  yet: it needs a scene delegate class, and WP14 is Wave 3.
- The shared scheme includes a disabled `-CapoDemoMode YES` launch argument for Xcode runs.
- Scripts: `build-sim.sh [dd]`, `test-packages.sh [dd]`, `install-device.sh [iphone|ipad|id]`.

### Resolved versions
- GRDB.swift 7.11.1 (FTS5 + `unicode61(diacritics: .remove)` confirmed by `FTS5SmokeTests`).
- supabase-swift 2.55.4.

### INT-1 (live composition)
- `CapoComposition.makeLive` builds one Supabase client and its remotes per app run; per session it opens
  `ApplicationSupport/Capo/<userID>.sqlite`, `LocalRepositories` and a `SyncEngine`. The shell (WP5) already
  calls `sync.start()`, `syncNow(.appLaunch)` and `syncNow(.foreground)` on scenePhase, so the composition does not.
- `tearDown(erase:)` stops the engine and calls `CapoDatabase.erase()` (drops the data and recreates the
  schema). The `.sqlite` file itself stays because the DatabasePool is still open at that point.
- Sharing is a thin `RemoteSharingService` over `SupabaseTeamsRemote.ensureShareCode`.
- `ios/scripts/use-supabase.sh local [--device] | production | demo` writes or removes the git-ignored
  `Secrets.plist`. It uses the `supabase` CLI directly (`pnpm supabase` runs an install first in this repo).
