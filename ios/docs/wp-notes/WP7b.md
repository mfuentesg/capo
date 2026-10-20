## WP7b notes

**Delivered:** `CapoPerformanceUI`. Public signatures are unchanged from §5.8 (`SongPerformanceView`, `PerformanceNavigation`).

**Pieces:**
- `SongPerformanceModel` (`@Observable`):
  - Feeds from the `songs.song(id:)`, `settings.songSettings` and `settings.preferences` streams.
  - Resolves settings as user, then song, then defaults (`EffectiveSongSettings.resolve`).
  - Renders with `ChordProEngine.render` and localized section labels. It re-renders only when lyrics, transpose or capo change.
  - Saves transpose, capo and font through `SettingsRepository` after a 500 ms debounce, and flushes on disappear.
  - While a local save is pending, stream echoes are ignored.
  - Columns persist via `updatePreferences(lyricsColumns:)`.
  - Reset returns to the song's authored transpose and capo, at font 1.
- `PerformanceScrollView`:
  - A `UIScrollView` hosting the SwiftUI content through `UIHostingController`, sized with `.intrinsicContentSize`.
  - `AutoScrollController` uses `CADisplayLink`, with px/s × elapsed time per frame, as in use-auto-scroll.ts.
  - It stops within 2 pt of the bottom, tracks manual drags, and keeps sub-pixel position.
- Speed inference uses the web formula: non-blank, non-directive lines × 4 beats / (bpm/60), against the measured scrollable height. It is clamped to 10…300 in steps of 10, defaults to 30, and is inferred once per song.
- Key commands are set on the hosting controller with `wantsPriorityOverSystemBehavior`, per the PLAN table:
  - ↓, PageDown, Space: page 85%. PageDown at the bottom calls `onNext` (SHOULD).
  - ↑, PageUp: page up.
  - → and ←: navigation.
  - `s`: toggle auto-scroll.
  - `[` and `]`: scroll speed.
  - `+`, `=` and `−`: font size.
- Keep-awake sets `isIdleTimerDisabled` while the screen is visible.
- The edit button is hidden for the viewer role and calls `capoActions.openEditor(.edit(id))`.

**Deviation:** the header shows the transposed key (as song-detail.tsx does) plus "Play in" for capo shapes, computed as `capoKey(transposedKey, capo)`. It does not use `MusicTheory.effectiveKey`: that adds the capo to the key, which describes neither the chords on screen nor the sounding key.

**Tests (20, Swift Testing):** speed inference, rounding and clamps; settings ranges and font step; page and bottom math; key-to-action table (unique keys, every action bound); model resolution, transposed render, debounce to the last value, echo suppression, flush, reset, column persistence, speed inferred once; debouncer cancel. Command:
`xcodebuild -scheme CapoUI-Package -destination 'platform=iOS Simulator,id=0422CCC7-27CE-42D3-8074-CB152F7B846E' -only-testing:CapoPerformanceUITests test`

**TODO:**
- Pedal testing on the device (Wave 2).
- Swipe between songs belongs to WP8's paging.
- Shortcut discoverability via `UIMenuBuilder` (WP14).
