# Songs Page: Lyrics-First Flow

## Context

The Songs page currently requires two hops to read lyrics: click song → settings panel (key, BPM, transpose, capo, delete) → click "View Lyrics" → navigate to `/dashboard/songs/[id]`. This is worse than the Playlists flow, where clicking a song surfaces lyrics immediately with per-user settings inline.

The goal is to make the Songs page match the mental model already established in Playlists: click a song, see its lyrics right away. Per-user overrides (transpose, capo, font size) are personal and belong inside the lyrics view. Canonical metadata (title, artist, key, BPM) and destructive actions belong behind a "…" overflow menu in the lyrics view header.

---

## Design

### Flow change

| Trigger | Before | After |
|---|---|---|
| Click song in list | Opens `SongDetail` settings panel | Opens `LyricsView` directly |
| Transpose / capo | Full-size steppers in settings panel | Compact settings bar under header |
| "View Lyrics" button | Navigates to `/dashboard/songs/[id]` | Removed — ⤢ external link icon stays |
| Edit title / artist / key / BPM | Inline `EditableField` in settings panel | "…" menu → "Edit details" dialog |
| Delete / Transfer to team | Danger zone at bottom of settings panel | "…" overflow menu items |

### Layout (desktop split panel)

```
┌─────────────────┬──────────────────────────────────────────┐
│ Songs · 48      │ La visión          [✏] [⤢] [•••] [✕]   │
│ ─────────────── │ Para Su Gloria                            │
│ El Cordero…     │ ────────────────────────────────────────  │
│ ▶ La visión ●   │ MY SETTINGS  [− 0 st +]  [− No capo +]  │
│   Santo es…     │              [− Aa +]                     │
│   Aquí estoy    │ ────────────────────────────────────────  │
│   In Jesus…     │                                           │
│                 │  Am          F          C                 │
│                 │  La visión del Señor…                     │
│                 │                                           │
│                 │  G           Am                           │
│                 │  Es grande y poderosa…                    │
└─────────────────┴──────────────────────────────────────────┘
```

### "…" dropdown menu contents

1. **Edit details** → opens `SongEditDialog` (title, artist, canonical key, BPM)
2. **Transfer to team** (conditional: personal context + teams exist)
3. ─ separator ─
4. **Delete song** (destructive, red) → existing `AlertDialog` confirm

### Per-user settings

`LyricsView` already has a ⚙ settings popover (transpose, capo, font size) used in the same way by the Playlists flow. No new settings bar is needed — `SongLyricsPanel` passes `initialSettings` and `onSettingsChange` to `LyricsView` and the existing popover handles the rest.

These are personal overrides via `useUpsertUserSongSettings` / `useEffectiveSongSettings` — they do not affect the canonical song or other users.

---

## Architecture

### New components

**`features/songs/components/song-lyrics-panel/song-lyrics-panel.tsx`**
- Wrapper used in `songs-client.tsx` (replaces `SongDetail` in the split panel and mobile Sheet)
- Calls `useUserSongSettings(song, null)`, `useEffectiveSongSettings(song)`, `useUpsertUserSongSettings(song)`, `useUpdateSong`
- Renders `LyricsView` with `mode="panel"`, passing `initialSettings`, `onSettingsChange`, `onSaveLyrics`, `onClose`
- Passes a `SongActionsMenu` as the `actionsSlot` prop

**`features/songs/components/song-actions-menu/song-actions-menu.tsx`**
- `DropdownMenu` with Edit details / Transfer / Delete items
- Props: `song`, `onEdit`, `onDelete`, `onTransferSuccess`, `canTransfer`
- Delete triggers existing `AlertDialog` confirmation
- Transfer triggers existing `TransferToTeamDialog`

**`features/songs/components/song-edit-dialog/song-edit-dialog.tsx`**
- `Dialog` with form fields: title (text input), artist (text input), key (`KeySelect`), BPM (numeric input)
- On save: calls `onUpdate(songId, { title, artist, key, bpm })`
- Props: `song`, `open`, `onOpenChange`, `onUpdate`

### Modified components

**`features/lyrics-editor/components/lyrics-view.tsx`**
- Add optional `actionsSlot?: React.ReactNode` to `LyricsViewProps`
- Render `actionsSlot` in the header toolbar, between the existing action buttons and the close button

**`features/songs/components/songs-client.tsx`**
- Replace `SongDetailLazy` dynamic import with `SongLyricsPanelLazy`
- Remove `SongDetail`-specific callbacks that are now internal to `SongLyricsPanel`
- `handleDeleteSong` and `handleTransferSuccess` still live here, passed down to `SongLyricsPanel`

**`features/songs/components/song-detail/song-detail.tsx`**
- No longer used by the Songs page; keep file as-is (still referenced by nothing after this change — can be deleted in a follow-up once confirmed unused)

### Exports

- Export `SongLyricsPanel` from `features/songs/components/index.ts` and `features/songs/index.ts`

---

## Files to create / modify

| File | Change |
|---|---|
| `features/songs/components/song-lyrics-panel/song-lyrics-panel.tsx` | **Create** — panel wrapper |
| `features/songs/components/song-lyrics-panel/index.ts` | **Create** — barrel export |
| `features/songs/components/song-actions-menu/song-actions-menu.tsx` | **Create** — overflow menu |
| `features/songs/components/song-actions-menu/index.ts` | **Create** — barrel export |
| `features/songs/components/song-edit-dialog/song-edit-dialog.tsx` | **Create** — edit details dialog |
| `features/songs/components/song-edit-dialog/index.ts` | **Create** — barrel export |
| `features/lyrics-editor/components/lyrics-view.tsx` | **Modify** — add `actionsSlot` prop |
| `features/songs/components/songs-client.tsx` | **Modify** — swap `SongDetail` → `SongLyricsPanel` |
| `features/songs/components/index.ts` | **Modify** — add new exports |
| `features/songs/index.ts` | **Modify** — add new exports |

---

## Verification

1. `pnpm dev` — open Songs page
2. Click any song → lyrics view opens immediately in right panel (no settings panel)
3. Transpose/capo steppers visible in compact settings bar; changes persist (per-user only)
4. Click "…" → "Edit details" dialog opens with correct title/artist/key/BPM; save updates the song
5. Click "…" → "Delete song" → confirm dialog → song removed, panel closes
6. Click "…" → "Transfer to team" (only visible in personal context with teams) → works
7. ⤢ icon → navigates to `/dashboard/songs/[id]` full page
8. Mobile (< 768px): same flow, Sheet opens with lyrics view directly
9. `pnpm typecheck` passes
10. `pnpm lint` passes (zero warnings)
