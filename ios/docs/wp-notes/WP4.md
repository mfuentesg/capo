## WP4 notes (CapoSupabase)

### Deviations from PLAN
- Rows cover 10 tables (all but `activity_log`, `feedback`), not 9: `playlist_songs`, `playlists`,
  `profiles`, `song_tag_assignments`, `song_tags`, `songs`, `team_invitations`, `team_members`,
  `teams`, `user_song_settings`.
- Drift guard asserts key-set equality (not just coverage) per table, allowlisting `songs.search_vector`.
  A second test checks every write payload only uses `Insert` columns.
- `signOut()` uses `scope: .local` so it works offline. supabase-swift drops the local session before
  calling `/logout`, so a network failure there is swallowed once the session is gone.
- `sessionStream()` yields `client.auth.currentSession` synchronously first (stored, even expired,
  no network), then auth changes; the SDK's `initialSession` event is skipped and duplicates are dropped.
- `signInWithGoogle()` maps a cancelled web sheet to `CancellationError`.
- `handleOpenURL` returns false for URLs that are not `capo://auth/callback` or when the exchange fails.
- `TeamsRemote` errors are mapped to `CapoError` (transport -> `offlineUnavailable`, 401/403/42501 ->
  `permissionDenied`, other PostgREST errors -> `server(message)`); zero-row update/delete on teams
  (RLS) -> `permissionDenied`.
- Extra permanent error codes classified as `.invalidInput`: 23502, 23503.
- `updateSong` with 0 rows: refetch; missing -> `.conflict(nil)`; server `updated_at == base` ->
  `.rejected(.permissionDenied)` (RLS-hidden write); otherwise `.conflict(server)`.
- `createPlaylist` retries a share_code collision up to 3 times; existing `playlist_songs` are fetched
  first so a replay only inserts missing entries.
- Realtime subscribes unfiltered to 9 tables under RLS; not unit-tested (no network); covered only by
  compile. Any error subscribing finishes the stream (sync keeps its other triggers).
- PostgREST renders `is.null` as `is.NULL`; equivalent server-side.

### Local E2E
`LocalE2ETests` runs only with `CAPO_LOCAL_SUPABASE=1` and `CAPO_LOCAL_SUPABASE_KEY` (publishable key)
set; targets http://127.0.0.1:54321. It was not run in this session (no key in the environment). It
leaves one throwaway auth user behind (no service role to delete it).

### supabase/config.toml
Added `"capo://auth/callback"` to `additional_redirect_urls`. The running local stack needs a restart
to pick it up (not done here).
