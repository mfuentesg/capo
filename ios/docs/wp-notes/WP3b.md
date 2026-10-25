## WP3b notes

### Deviations from PLAN
- `SyncEngine.init` gained two trailing defaulted parameters, `realtimeDebounce` (1 s) and
  `outboxDebounce` (0.5 s), so tests can shorten the debounces. Call sites using the frozen
  signature are unaffected.
- `syncNow` callers that arrive during a run suspend until the single follow-up run finishes
  (rather than returning immediately), so `await syncNow` always means "a sync that started after
  my call has completed".
- `NWReachabilityMonitor` starts at `false` and emits the first real path; the engine treats the
  false -> true edge as `.reachability`. The engine assumes online until its reachability stream
  says otherwise, so `syncNow` works without `start()`.

### Behaviour worth knowing
- Push loops over `nextPendingOperations` until empty. After a transient error or a conflict, later
  ops on the same `entityKey` are skipped for the rest of the run (FIFO per entity). Rejected ops do
  not block the entity.
- Backoff: `min(2^attempts, 300)` seconds, `attempts` being the count before this try.
- A push failure does not abort the pull; the first error of the run is surfaced as
  `.error(message)` and stored in `SyncMetadata.lastError`.
- Pull relies on `PullBatch.skipEntityKeys` (= `pendingEntityKeys()`) to protect rows with pending
  ops, including deletes of never-pushed creates. Scope change (team removal) needs no special
  case: team songs vanish from `songVersions` and are deleted, and `teams`/`memberships` are
  full-replace sets.
- Realtime is subscribed at `start()` with the empty-team scope and re-subscribed whenever a pull
  discovers a different team set.
- The outbox trigger fires only when the pending count grows.
