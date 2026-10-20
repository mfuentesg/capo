## WP8 notes

- Frozen signatures kept: `PlaylistsView(selection:)`, `PlaylistDetailView(playlistID:)`,
  `SetlistPerformanceView(playlistID:startIndex:onClose:)`.
- Added public `AddToPlaylistView(songIDs:onFinish:)`: the target chooser for
  `capoActions.addSongsToPlaylist`. The shell should present it in a sheet with the ids it receives
  (lists active setlists in the current context, can create a new one, then calls
  `playlists.addSongs`). Not part of the frozen §5.8 list; additive.
- `PlaylistsView`: Active / Archived segmented control (one stream with `includeArchived: true`,
  filtered client side), swipe archive / delete (confirm), pin badge turning into a green check when
  `isFullyAvailableOffline`.
- `PlaylistDetailView`: tap a song or the play button calls `capoActions.performSetlist(id, index)`.
  Reorder through the "Reorder" menu item (edit mode, optimistic local order then `reorder`),
  swipe to remove, add via `SongPickerView(excluding:)`, edit details, pin, archive, delete, share.
  Share is disabled while `SyncPhase == .offline`; the share sheet maps `.offlineUnavailable`.
- `SetlistPerformanceView`: page-style `TabView`; only current +/- 1 pages host a
  `SongPerformanceView` (others are `Color.clear`). `PerformanceNavigation` carries "3 / 12" and
  next/previous; a next-song peek bar sits at the bottom. Close button top leading.
- Everything works offline: only local repositories are used, except the share sheet.
- Strings: same approach as WP6 (`String(localized:defaultValue:)`, no `bundle:`, `// TODO(i18n)`, `ios.playlists.*`).
- Pure, unit-tested: `SetlistMath` (move, clamp, next/previous, position label, live window) and `PlaylistDate`.
- TODO: no visual check on simulators yet; SongPerformanceView is still the WP0 stub until WP7b lands.
