## WP3a notes (CapoStore)

### Behaviour decisions
- UUIDs are stored as lowercase TEXT (never GRDB's blob encoding); always pass `.dbString`.
- Local-only timestamps (`outbox.created_at/next_attempt_at`, `conflicts.detected_at`, `offline_pins.pinned_at`)
  are REAL epoch seconds; server timestamps are raw TEXT.
- `user_song_settings.id` is kept in the schema but never populated (`UserSongSettings` has no id).
- `hasPendingChanges` is derived from the outbox (pending/inflight/conflict ops for `song:<id>`).
- `outboxChanges()` emits the pending+inflight count, de-duplicated (no re-emit when the count is unchanged).
- Opening a database resets leftover `inflight` ops to `pending` (crash recovery).
- `nextPendingOperations` returns only the head of each entity queue, and only if it is `pending` and due;
  an inflight, conflicted or backed-off head blocks everything behind it. `failed` ops do not block.
- Coalescing: unsent `updateSong` merges (base kept); `upsertSongSettings`, `setSongTags`, `reorderPlaylist`,
  `setPlaylistArchived` keep only the latest; `updatePreferences` keeps one op with merged patches (so edits to
  different keys are not lost); `updatePlaylist` merges. Add-then-remove of a playlist song before push cancels out.
  Delete of a never-pushed song/playlist/tag drops its ops; deletes also prune references in unsent playlist/tag ops.
- `complete(.applied(serverSong:))` copies only `updated_at`/`created_at` onto the local row (so later local edits are
  not clobbered) and rebases later pending `updateSong` bases.
- Conflicts: `keepMine` re-queues the op with the server `updated_at` as base and a full-song patch (or `createSong`
  if the server row is gone); `keepTheirs` adopts the server row and discards unsent edits; `keepBothAsCopy` saves my
  version as a new song titled "<title> (copy)" (not localized in the store) with the same tags, then adopts the server row.
- Team online ops map offline `URLError`s to `.offlineUnavailable`; `onRemoteMutation()` runs after each success.
- `LocalRepositories.init` preconditions `database.userID == userID`.

### Open issues
- `isFullyAvailableOffline` uses "lyrics non-NULL" per plan; songs that legitimately have NULL lyrics on the server
  are never "available offline".
- "(copy)" suffix is English-only; UI may want to rename after resolution.
- Playlist ordering is `date DESC, created_at DESC`; confirm against web if it matters.
