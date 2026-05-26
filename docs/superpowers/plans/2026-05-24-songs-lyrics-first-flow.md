# Songs Lyrics-First Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two-hop "click song → settings panel → View Lyrics" flow with a direct "click song → lyrics view" flow on the Songs page.

**Architecture:** Add an optional `actionsSlot` prop to `LyricsView` so consumers can inject a "…" overflow menu. Create `SongLyricsPanel` (wraps `LyricsView` + hooks), `SongActionsMenu` (DropdownMenu with edit/delete/transfer), and `SongEditDialog` (Dialog to edit canonical song metadata). Swap `SongDetail` for `SongLyricsPanel` in `songs-client.tsx`.

**Tech Stack:** Next.js App Router, React, `@tanstack/react-query`, `shadcn/ui` (DropdownMenu, Dialog, AlertDialog), lucide-react, existing songs hooks (`useUserSongSettings`, `useEffectiveSongSettings`, `useUpsertUserSongSettings`, `useUpdateSong`, `useDeleteSong`)

**Branch:** Create branch `feature/songs-lyrics-first-flow` before starting.

---

## File Map

| File | Action |
|---|---|
| `features/lyrics-editor/components/lyrics-view.tsx` | Modify — add `actionsSlot` prop |
| `lib/i18n/locales/en.json` | Modify — add `songs.editDetails` key |
| `lib/i18n/locales/es.json` | Modify — add `songs.editDetails` key |
| `features/songs/components/song-edit-dialog/song-edit-dialog.tsx` | Create |
| `features/songs/components/song-edit-dialog/index.ts` | Create |
| `features/songs/components/song-actions-menu/song-actions-menu.tsx` | Create |
| `features/songs/components/song-actions-menu/index.ts` | Create |
| `features/songs/components/song-lyrics-panel/song-lyrics-panel.tsx` | Create |
| `features/songs/components/song-lyrics-panel/index.ts` | Create |
| `features/songs/components/index.ts` | Modify — add new exports |
| `features/songs/index.ts` | Modify — export `useDeleteSong` |
| `features/songs/components/songs-client.tsx` | Modify — swap SongDetail → SongLyricsPanel |

---

### Task 1: Create git branch

- [ ] **Step 1: Create and checkout branch**

```bash
git checkout -b feature/songs-lyrics-first-flow
```

- [ ] **Step 2: Verify**

```bash
git branch --show-current
```
Expected: `feature/songs-lyrics-first-flow`

---

### Task 2: Add `actionsSlot` prop to `LyricsView`

**Files:**
- Modify: `features/lyrics-editor/components/lyrics-view.tsx`

- [ ] **Step 1: Add `actionsSlot` to the props interface**

In `features/lyrics-editor/components/lyrics-view.tsx`, find the `LyricsViewProps` interface (around line 87) and add one line:

```typescript
interface LyricsViewProps {
  song: Song
  mode?: "page" | "panel"
  readOnly?: boolean
  onClose?: () => void
  onSaveLyrics?: (lyrics: string) => void
  isSaving?: boolean
  initialSettings?: { capo?: number; transpose?: number; fontSize?: number }
  onSettingsChange?: (settings: { capo: number; transpose: number; fontSize: number }) => void
  initialLyricsColumns?: 1 | 2
  onPrevSong?: () => void
  onNextSong?: () => void
  hasPrevSong?: boolean
  hasNextSong?: boolean
  songPosition?: { current: number; total: number }
  slideDirection?: "next" | "prev"
  actionsSlot?: React.ReactNode
}
```

- [ ] **Step 2: Destructure `actionsSlot` in the function signature**

Find the destructuring at the top of the `LyricsView` function (around line 106) and add `actionsSlot`:

```typescript
export const LyricsView = forwardRef<LyricsViewHandle, LyricsViewProps>(function LyricsView(
  {
    song,
    mode = "page",
    readOnly = false,
    onClose,
    onSaveLyrics,
    isSaving = false,
    initialSettings,
    onSettingsChange,
    initialLyricsColumns = 1,
    onPrevSong,
    onNextSong,
    hasPrevSong = false,
    hasNextSong = false,
    songPosition,
    slideDirection,
    actionsSlot
  }: LyricsViewProps,
  ref
)
```

- [ ] **Step 3: Render `actionsSlot` in the non-editing action buttons area**

Find the non-editing branch inside the action buttons `<div>` (around line 587 — the `<>` block after the `canEdit && isEditing ?` ternary). Add `{actionsSlot}` after the reference button:

```tsx
) : (
  <>
    {canEdit && (
      <Button
        variant="ghost"
        className="h-9 gap-1.5 px-2.5"
        onClick={handleEdit}
        aria-label={t.songs.editLyrics}
      >
        <Pencil className="h-4 w-4" />
        <span className="hidden sm:inline text-sm">{t.common.edit}</span>
      </Button>
    )}
    {isPanel && (
      <Button
        variant="ghost"
        size="icon"
        className="h-9 w-9"
        asChild
        title={t.songs.viewLyrics}
      >
        <a
          href={`/dashboard/songs/${song.id}`}
          target="_blank"
          rel="noopener noreferrer"
        >
          <ExternalLink className="h-4 w-4" />
        </a>
      </Button>
    )}
    <Button
      variant="ghost"
      size="icon"
      className="h-9 w-9"
      onClick={handleShare}
      aria-label={t.songs.shareLyrics}
    >
      <Share2 className="h-4 w-4" />
    </Button>
    <Button
      variant="ghost"
      className="h-9 gap-1.5 px-2.5"
      onClick={() => setIsReferenceOpen(true)}
      aria-label={t.songs.lyrics.chordproReference}
    >
      <BookOpen className="h-4 w-4" />
      <span className="hidden sm:inline text-sm">{t.songs.lyrics.docs}</span>
    </Button>
    {actionsSlot}
  </>
)}
```

- [ ] **Step 4: Typecheck**

```bash
pnpm typecheck
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add features/lyrics-editor/components/lyrics-view.tsx
git commit -m "feat(lyrics-view): add actionsSlot prop for overflow menu injection"
```

---

### Task 3: Add `editDetails` i18n key

**Files:**
- Modify: `lib/i18n/locales/en.json`
- Modify: `lib/i18n/locales/es.json`

- [ ] **Step 1: Add to `en.json`**

In `lib/i18n/locales/en.json`, find the `songs` object (around line 120 — near `viewLyrics`). Add `"editDetails"` right after `"viewLyrics"`:

```json
"viewLyrics": "View Lyrics",
"editDetails": "Edit Details",
```

- [ ] **Step 2: Add to `es.json`**

Find the same position in `lib/i18n/locales/es.json` and add:

```json
"viewLyrics": "Ver Letra",
"editDetails": "Editar Detalles",
```

- [ ] **Step 3: Validate translations**

```bash
pnpm i18n:validate
```
Expected: passes with no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/i18n/locales/en.json lib/i18n/locales/es.json
git commit -m "feat(i18n): add songs.editDetails translation key"
```

---

### Task 4: Create `SongEditDialog`

**Files:**
- Create: `features/songs/components/song-edit-dialog/song-edit-dialog.tsx`
- Create: `features/songs/components/song-edit-dialog/index.ts`

- [ ] **Step 1: Create the component file**

Create `features/songs/components/song-edit-dialog/song-edit-dialog.tsx`:

```tsx
"use client"

import { useState, useEffect } from "react"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { KeySelect } from "@/features/songs/components/key-select"
import { useTranslation } from "@/hooks/use-translation"
import type { Song } from "@/features/songs/types"

interface SongEditDialogProps {
  song: Song
  open: boolean
  onOpenChange: (open: boolean) => void
  onUpdate: (songId: string, updates: Partial<Song>) => void
}

export function SongEditDialog({ song, open, onOpenChange, onUpdate }: SongEditDialogProps) {
  const { t } = useTranslation()
  const [title, setTitle] = useState(song.title)
  const [artist, setArtist] = useState(song.artist)
  const [key, setKey] = useState(song.key)
  const [bpmDraft, setBpmDraft] = useState(String(song.bpm ?? 0))

  useEffect(() => {
    if (open) {
      setTitle(song.title)
      setArtist(song.artist)
      setKey(song.key)
      setBpmDraft(String(song.bpm ?? 0))
    }
  }, [open, song])

  const handleSave = () => {
    const parsedBpm = Number.parseInt(bpmDraft, 10)
    const bpm = Number.isNaN(parsedBpm) ? song.bpm : Math.max(20, Math.min(parsedBpm, 500))
    onUpdate(song.id, {
      title: title.trim() || song.title,
      artist: artist.trim(),
      key,
      bpm
    })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t.songs.editDetails}</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-1.5">
            <Label htmlFor="song-edit-title">{t.songs.songTitle}</Label>
            <Input
              id="song-edit-title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder={t.songs.songTitlePlaceholder}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="song-edit-artist">{t.songs.artist}</Label>
            <Input
              id="song-edit-artist"
              value={artist}
              onChange={(e) => setArtist(e.target.value)}
              placeholder={t.songs.artistPlaceholder}
            />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <Label>{t.songs.key}</Label>
              <KeySelect
                value={key}
                onValueChange={setKey}
                className="w-full"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="song-edit-bpm">{t.songs.bpm}</Label>
              <Input
                id="song-edit-bpm"
                type="text"
                inputMode="numeric"
                pattern="[0-9]*"
                value={bpmDraft}
                onChange={(e) => {
                  if (/^\d*$/.test(e.target.value)) setBpmDraft(e.target.value)
                }}
              />
            </div>
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            {t.common.cancel}
          </Button>
          <Button onClick={handleSave}>{t.common.save}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
```

- [ ] **Step 2: Create barrel export**

Create `features/songs/components/song-edit-dialog/index.ts`:

```typescript
export { SongEditDialog } from "./song-edit-dialog"
```

- [ ] **Step 3: Typecheck**

```bash
pnpm typecheck
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add features/songs/components/song-edit-dialog/
git commit -m "feat(songs): add SongEditDialog for editing title/artist/key/BPM"
```

---

### Task 5: Create `SongActionsMenu`

**Files:**
- Create: `features/songs/components/song-actions-menu/song-actions-menu.tsx`
- Create: `features/songs/components/song-actions-menu/index.ts`

- [ ] **Step 1: Export `useDeleteSong` from the songs public API**

In `features/songs/index.ts`, add `useDeleteSong` to the use-songs export line:

```typescript
export { useSongs, useAllSongs, useUpdateSong, useTransferSongToTeam, useDeleteSong } from "./hooks/use-songs"
```

- [ ] **Step 2: Create the component**

Create `features/songs/components/song-actions-menu/song-actions-menu.tsx`:

```tsx
"use client"

import { useState } from "react"
import { MoreVertical, Pencil, ArrowRightFromLine, Trash2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle
} from "@/components/ui/alert-dialog"
import { useTranslation } from "@/hooks/use-translation"
import { useAppContext } from "@/features/app-context"
import { useTeams } from "@/features/teams"
import { useDeleteSong } from "@/features/songs"
import { SongEditDialog } from "../song-edit-dialog"
import { TransferToTeamDialog } from "../transfer-to-team-dialog"
import type { Song } from "@/features/songs/types"

interface SongActionsMenuProps {
  song: Song
  onUpdate: (songId: string, updates: Partial<Song>) => void
  onDelete: (songId: string) => void
  onTransferSuccess: () => void
}

export function SongActionsMenu({ song, onUpdate, onDelete, onTransferSuccess }: SongActionsMenuProps) {
  const { t } = useTranslation()
  const { context } = useAppContext()
  const { data: teams = [] } = useTeams()
  const deleteSongMutation = useDeleteSong()
  const canTransfer = context?.type === "personal" && teams.length > 0

  const [isEditOpen, setIsEditOpen] = useState(false)
  const [isTransferOpen, setIsTransferOpen] = useState(false)
  const [isDeleteOpen, setIsDeleteOpen] = useState(false)

  const handleConfirmDelete = () => {
    deleteSongMutation.mutate(song.id, {
      onSuccess: () => onDelete(song.id)
    })
  }

  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="ghost" size="icon" className="h-9 w-9" aria-label={t.common.more}>
            <MoreVertical className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => setIsEditOpen(true)}>
            <Pencil className="mr-2 h-4 w-4" />
            {t.songs.editDetails}
          </DropdownMenuItem>
          {canTransfer && (
            <DropdownMenuItem onClick={() => setIsTransferOpen(true)}>
              <ArrowRightFromLine className="mr-2 h-4 w-4" />
              {t.songs.transferToTeam}
            </DropdownMenuItem>
          )}
          <DropdownMenuSeparator />
          <DropdownMenuItem
            className="text-destructive focus:text-destructive"
            onClick={() => setIsDeleteOpen(true)}
          >
            <Trash2 className="mr-2 h-4 w-4" />
            {t.songs.deleteSong}
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>

      <SongEditDialog
        song={song}
        open={isEditOpen}
        onOpenChange={setIsEditOpen}
        onUpdate={onUpdate}
      />

      {canTransfer && (
        <TransferToTeamDialog
          song={song}
          open={isTransferOpen}
          onOpenChange={setIsTransferOpen}
          onSuccess={onTransferSuccess}
        />
      )}

      <AlertDialog open={isDeleteOpen} onOpenChange={setIsDeleteOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t.songs.deleteSongConfirmTitle}</AlertDialogTitle>
            <AlertDialogDescription>
              {t.songs.deleteSongConfirmDescription.replace("{title}", song.title)}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
            <AlertDialogAction variant="destructive" onClick={handleConfirmDelete}>
              {t.songs.deleteSong}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
```

- [ ] **Step 3: Check that `t.common.more` exists in en.json**

```bash
grep -n '"more"' lib/i18n/locales/en.json
```

If the key is missing (no output), add `"more": "More"` to the `common` section in both `en.json` and `es.json`, and re-run `pnpm i18n:validate`.

- [ ] **Step 4: Create barrel export**

Create `features/songs/components/song-actions-menu/index.ts`:

```typescript
export { SongActionsMenu } from "./song-actions-menu"
```

- [ ] **Step 5: Typecheck**

```bash
pnpm typecheck
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add features/songs/components/song-actions-menu/ features/songs/index.ts
git commit -m "feat(songs): add SongActionsMenu with edit/transfer/delete dropdown"
```

---

### Task 6: Create `SongLyricsPanel`

**Files:**
- Create: `features/songs/components/song-lyrics-panel/song-lyrics-panel.tsx`
- Create: `features/songs/components/song-lyrics-panel/index.ts`

- [ ] **Step 1: Create the component**

Create `features/songs/components/song-lyrics-panel/song-lyrics-panel.tsx`:

```tsx
"use client"

import { LyricsView } from "@/features/lyrics-editor"
import { useUserSongSettings, useEffectiveSongSettings, useUpsertUserSongSettings } from "../../hooks/use-user-song-settings"
import { useUpdateSong } from "../../hooks/use-songs"
import { SongActionsMenu } from "../song-actions-menu"
import type { Song } from "../../types"

interface SongLyricsPanelProps {
  song: Song
  onClose: () => void
  onDelete: (songId: string) => void
  onTransferSuccess: () => void
}

export function SongLyricsPanel({ song, onClose, onDelete, onTransferSuccess }: SongLyricsPanelProps) {
  useUserSongSettings(song, undefined)
  const effectiveSettings = useEffectiveSongSettings(song)
  const { mutate: upsertSettings } = useUpsertUserSongSettings(song)
  const { mutate: updateSong, isPending: isSaving } = useUpdateSong()

  return (
    <LyricsView
      song={song}
      mode="panel"
      onClose={onClose}
      onSaveLyrics={(lyrics) => updateSong({ songId: song.id, updates: { lyrics } })}
      isSaving={isSaving}
      initialSettings={effectiveSettings}
      onSettingsChange={upsertSettings}
      actionsSlot={
        <SongActionsMenu
          song={song}
          onUpdate={(songId, updates) => updateSong({ songId, updates })}
          onDelete={onDelete}
          onTransferSuccess={onTransferSuccess}
        />
      }
    />
  )
}
```

- [ ] **Step 2: Create barrel export**

Create `features/songs/components/song-lyrics-panel/index.ts`:

```typescript
export { SongLyricsPanel } from "./song-lyrics-panel"
```

- [ ] **Step 3: Typecheck**

```bash
pnpm typecheck
```
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add features/songs/components/song-lyrics-panel/
git commit -m "feat(songs): add SongLyricsPanel wrapping LyricsView with song actions"
```

---

### Task 7: Update exports and wire into `songs-client.tsx`

**Files:**
- Modify: `features/songs/components/index.ts`
- Modify: `features/songs/components/songs-client.tsx`

- [ ] **Step 1: Add new exports to `features/songs/components/index.ts`**

Replace the contents of `features/songs/components/index.ts`:

```typescript
export { SongsClient } from "./songs-client"
export { SongDetail } from "./song-detail"
export { SongList, SongSkeleton } from "./song-list"
export { SongItem } from "./song-item"
export { KeySelect } from "./key-select"
export { TransferToTeamDialog } from "./transfer-to-team-dialog"
export { SongLyricsPanel } from "./song-lyrics-panel"
export { SongActionsMenu } from "./song-actions-menu"
export { SongEditDialog } from "./song-edit-dialog"
```

- [ ] **Step 2: Update `songs-client.tsx` — swap `SongDetailLazy` for `SongLyricsPanelLazy`**

In `features/songs/components/songs-client.tsx`:

Replace the `SongDetailLazy` dynamic import (around line 121):

```typescript
const SongLyricsPanelLazy = dynamic(
  () => import("@/features/songs").then((mod) => mod.SongLyricsPanel),
  { ssr: false, loading: () => <SongDetailSkeleton /> }
)
```

Remove the old import:
```typescript
// DELETE this line:
const SongDetailLazy = dynamic(() => import("@/features/songs").then((mod) => mod.SongDetail), {
  ssr: false,
  loading: () => <SongDetailSkeleton />
})
```

- [ ] **Step 3: Replace all `SongDetailLazy` usages with `SongLyricsPanelLazy` in `songs-client.tsx`**

There are two usages — in the desktop split panel (around line 550) and in the mobile Sheet (around line 604). Replace both:

**Desktop panel** (replace the `selectedSong ?` branch):

```tsx
) : selectedSong ? (
  <SongLyricsPanelLazy
    song={selectedSong}
    onClose={handleCloseSongDetail}
    onDelete={handleDeleteSong}
    onTransferSuccess={handleTransferSuccess}
  />
) : (
```

**Mobile Sheet** (replace the `selectedSong ?` branch inside the Sheet):

```tsx
) : selectedSong ? (
  <SongLyricsPanelLazy
    song={selectedSong}
    onClose={handleCloseSongDetail}
    onDelete={handleDeleteSong}
    onTransferSuccess={handleTransferSuccess}
  />
) : null}
```

- [ ] **Step 4: Remove now-unused imports from `songs-client.tsx`**

Remove `useDeleteSong` from the hooks import line (it's now used internally by `SongActionsMenu`):

```typescript
// Before:
import { useSongs, useCreateSong, useUpdateSong, useDeleteSong } from "../hooks/use-songs"

// After:
import { useSongs, useCreateSong, useUpdateSong } from "../hooks/use-songs"
```

Also remove `deleteSongMutation` state and the `handleDeleteSong` callback **only if** they are now entirely unused. Check: `handleDeleteSong` is still passed to `SongLyricsPanelLazy` as `onDelete`, so keep it. But `deleteSongMutation` is used inside `handleDeleteSong` — **keep both** since `SongActionsMenu.onDelete` just signals to the parent to close the panel; the actual mutation call is inside `SongActionsMenu`. 

Wait — look at `handleDeleteSong` in `songs-client.tsx`:

```typescript
const handleDeleteSong = useCallback(
  (songId: string) => {
    deleteSongMutation.mutate(songId)
    setSelectedSong(null)
    setIsMobileDrawerOpen(false)
  },
  [deleteSongMutation]
)
```

`SongActionsMenu` already calls `deleteSongMutation` internally. So `handleDeleteSong` in `songs-client.tsx` would call the mutation a second time. Fix this: make `handleDeleteSong` only handle UI state (close panel), not call the mutation:

```typescript
const handleDeleteSong = useCallback((songId: string) => {
  setSelectedSong(null)
  setIsMobileDrawerOpen(false)
}, [])
```

And remove `deleteSongMutation` and `useDeleteSong` import entirely:

```typescript
import { useSongs, useCreateSong, useUpdateSong } from "../hooks/use-songs"
// ...
// DELETE: const deleteSongMutation = useDeleteSong()
```

- [ ] **Step 5: Typecheck and lint**

```bash
pnpm typecheck && pnpm lint
```
Expected: no errors, no warnings.

- [ ] **Step 6: Commit**

```bash
git add features/songs/components/index.ts features/songs/components/songs-client.tsx
git commit -m "feat(songs): replace SongDetail with SongLyricsPanel for lyrics-first flow"
```

---

### Task 8: Verify end-to-end

- [ ] **Step 1: Start dev server**

```bash
pnpm dev
```

- [ ] **Step 2: Check golden path**

Open http://localhost:3000, navigate to Songs page.
1. Click any song → lyrics view opens immediately (no settings panel)
2. Verify ⚙ settings popover (bottom-right float) controls transpose/capo/font — changes are per-user
3. Click "…" (MoreVertical icon in header) → dropdown shows: Edit Details, optionally Transfer to team, separator, Delete Song
4. Click "Edit Details" → dialog opens pre-filled with song title/artist/key/BPM; save → song updates in list
5. Click "…" → "Delete Song" → confirm dialog → song removed, panel closes
6. Click edit (pencil icon) → lyrics editor opens; save → works
7. Click ⤢ (ExternalLink icon) → opens `/dashboard/songs/[id]` in new tab

- [ ] **Step 3: Check mobile (resize browser to < 768px)**

Click a song → Sheet slides up with lyrics view directly (no settings panel).

- [ ] **Step 4: Run tests**

```bash
pnpm test
```
Expected: all pass.

- [ ] **Step 5: Final typecheck + lint**

```bash
pnpm typecheck && pnpm lint
```
Expected: clean.

- [ ] **Step 6: Push and open PR**

```bash
git push -u origin feature/songs-lyrics-first-flow
gh pr create \
  --title "feat: songs page lyrics-first flow" \
  --body "$(cat <<'EOF'
## Summary
- Clicking a song now opens the lyrics view directly (removes 2-hop settings panel → View Lyrics)
- Song metadata editing (title/artist/key/BPM) and destructive actions (delete, transfer) moved to a "…" overflow menu in the lyrics view header
- Per-user settings (transpose, capo, font size) accessible via existing ⚙ popover in LyricsView, same as Playlists flow
- `LyricsView` extended with optional `actionsSlot` prop for injecting overflow menus

## Test plan
- [ ] Click song → lyrics view opens immediately (no intermediate settings panel)
- [ ] ⚙ settings popover controls personal overrides; changes don't affect other users
- [ ] "…" → Edit Details → saves canonical metadata changes
- [ ] "…" → Delete Song → confirm → song removed
- [ ] "…" → Transfer to team (only visible in personal context with teams)
- [ ] Mobile < 768px: Sheet shows lyrics directly
- [ ] `pnpm typecheck && pnpm lint` pass clean

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review Notes

**Spec coverage check:**
- ✅ Click song → lyrics directly: Task 7 (SongLyricsPanel replaces SongDetail)
- ✅ actionsSlot prop on LyricsView: Task 2
- ✅ "…" menu with Edit Details / Transfer / Delete: Task 5 (SongActionsMenu)
- ✅ SongEditDialog (title/artist/key/BPM): Task 4
- ✅ Per-user settings via existing LyricsView ⚙ popover: Task 6 (SongLyricsPanel passes initialSettings/onSettingsChange)
- ✅ Mobile Sheet: Task 7 (both panel usages swapped)
- ✅ "View Lyrics" button removed (SongDetail no longer shown; LyricsView already has ExternalLink icon)
- ✅ Branch + PR: Tasks 1 and 8
- ✅ i18n key: Task 3
- ✅ exports: Task 7 step 1

**Double-mutation fix:** `handleDeleteSong` in `songs-client.tsx` must NOT call `deleteSongMutation` directly — `SongActionsMenu` already does. Task 7 Step 4 covers this.
