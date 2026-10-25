## WP6 notes

- `LibraryView(selection:)`, `SongPickerView(excluding:onPick:)` keep the frozen §5.8 signatures.
- Pure `LibraryFilters` (search, any-of tags, statuses, BPM bucket, sort) maps to `SongQuery`; unit tested.
  Sort is automatic (relevance while searching, else recent); relevance falls back to recent without a term.
  Status set can never become empty. BPM buckets: slow 0...89, medium 90...120, fast 121+ (single choice).
- Search debounce: `.task(id: searchInput)` + `LibraryModel.commitSearchAfterDebounce` (150 ms; cancel skips commit).
- Deviation: strings use `String(localized:defaultValue:)` WITHOUT `bundle: .module` (CapoLibraryUI has no
  resources, so no `Bundle.module`; Package.swift is frozen). All in `LibraryStrings.swift`, `// TODO(i18n)`, keys `ios.library.*`.
- Add-to-setlist (swipe/context menu) calls `capoActions.addSongsToPlaylist([id])`; the shell decides the target playlist.
- Tag management / assign-tags / new song / edit are hidden for `currentTeamRole == .viewer`.
- Assign-tags saves on every toggle through `songs.setTags`.
- TODO: snapshot/visual check on iPhone and iPad simulators not done (disk-constrained); logic is unit tested.
