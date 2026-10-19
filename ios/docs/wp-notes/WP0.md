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

### Resolved versions
- GRDB.swift 7.11.1 (FTS5 + `unicode61(diacritics: .remove)` confirmed by `FTS5SmokeTests`).
- supabase-swift 2.55.4.
