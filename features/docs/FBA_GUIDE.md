# Feature-Based Architecture (FBA) Guide

**Last Updated:** May 24, 2026
**Status:** ✅ Production Ready

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Architecture Overview](#architecture-overview)
3. [Developer Patterns](#developer-patterns)
4. [Cross-Feature Dependencies](#cross-feature-dependencies)
5. [Testing](#testing)
6. [Deployment](#deployment)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### The Three Rules

1. **Organize by Feature**: Code belongs in `features/[feature-name]/`
2. **Use Public APIs**: Always import from `@/features/[name]`
3. **Export from index.ts**: Each feature's public API is in `features/[name]/index.ts`

### Quick Reference

```typescript
// ✅ CORRECT - import via public API
import { SongsClient } from "@/features/songs"
import { PlaylistsClient } from "@/features/playlists"
import { usePlaylistDraft } from "@/features/playlist-draft"

// ❌ WRONG - never import from internal paths
import { SongsClient } from "@/features/songs/components/songs-client"
import { PlaylistsClient } from "@/features/playlists/components/playlists-client"
import { usePlaylistDraft } from "@/features/playlist-draft/contexts/draft.context"
```

---

## Architecture Overview

### What is FBA?

Feature-Based Architecture organizes code by business domain (feature) rather than technical layer. Each feature is self-contained with its own components, hooks, types, and utilities.

### Project Structure

```
features/
├── songs/                    # Feature: Song library management
│   ├── components/          # UI components for songs
│   ├── hooks/               # Custom hooks (useSongs, etc.)
│   ├── types/               # TypeScript interfaces
│   ├── utils/               # Utility functions
│   ├── __tests__/           # Tests and fixtures
│   └── index.ts             # PUBLIC API ⚠️
│
├── playlists/               # Feature: Playlist management
│   ├── components/
│   ├── contexts/            # React Context for state
│   ├── hooks/
│   ├── types/
│   ├── utils/
│   ├── __tests__/
│   └── index.ts             # PUBLIC API ⚠️
│
├── activity/                # Feature: Real-time activity tracking
├── app-context/             # Feature: Global app context (team/bucket switching)
├── auth/                    # Feature: Authentication (Google OAuth)
├── chord-audio/             # Feature: Chord audio playback via Tone.js
├── chords/                  # Feature: Chord glossary and analyzer
├── dashboard/               # Feature: Dashboard stats and recent songs
├── feedback/                # Feature: In-app feedback and newsletter opt-in
├── lyrics-editor/           # Feature: ChordPro editor and live preview
├── playlist-draft/          # Feature: Quick add-to-playlist cart
├── playlist-sharing/        # Feature: Public playlist sharing via share codes
├── settings/                # Feature: Theme, language, chord hand, account
├── song-draft/              # Feature: Song creation and editing
├── songs/                   # Feature: Song library management
├── teams/                   # Feature: Team management and invitations
│
└── docs/                    # Documentation
    └── FBA_GUIDE.md         # This file
```

### Core Features

| Feature              | Purpose                                                          | Status      |
| -------------------- | ---------------------------------------------------------------- | ----------- |
| **activity**         | Real-time activity tracking across the app                       | ✅ Complete |
| **app-context**      | Global context for team/bucket switching and view filters        | ✅ Complete |
| **auth**             | Google OAuth authentication via Supabase Auth                    | ✅ Complete |
| **chord-audio**      | Chord audio playback via Tone.js singleton MIDI sampler          | ✅ Complete |
| **chords**           | Chord glossary, search, and guitar chord analyzer                | ✅ Complete |
| **dashboard**        | Overview stats (songs, playlists, teams) and recent songs        | ✅ Complete |
| **feedback**         | In-app feedback and newsletter opt-in form                       | ✅ Complete |
| **lyrics-editor**    | CodeMirror ChordPro editor with live preview and auto-scroll     | ✅ Complete |
| **playlist-draft**   | Quick-add-to-playlist cart for building setlists on the fly      | ✅ Complete |
| **playlist-sharing** | Share playlists publicly via unique share codes (real-time sync) | ✅ Complete |
| **playlists**        | Create, manage, reorder, and share playlists                     | ✅ Complete |
| **settings**         | Theme (light/dark), language, chord hand, and account management | ✅ Complete |
| **song-draft**       | Create and edit songs in ChordPro format                         | ✅ Complete |
| **songs**            | Song library with full-text search, filtering, and editing       | ✅ Complete |
| **teams**            | Team creation, role-based access, and email invitations          | ✅ Complete |

---

## Developer Patterns

### Adding a New Component

```
features/songs/components/my-component/
├── index.ts
├── my-component.tsx
└── __tests__/
    └── my-component.test.tsx
```

**Implementation:**

```typescript
// features/songs/components/my-component/my-component.tsx
import { ReactNode } from 'react'

export interface MyComponentProps {
  title: string
  children?: ReactNode
}

export function MyComponent({ title, children }: MyComponentProps) {
  return <div>{title}</div>
}
```

```typescript
// features/songs/components/my-component/index.ts
export { MyComponent } from "./my-component"
export type { MyComponentProps } from "./my-component"
```

```typescript
// features/songs/index.ts
export { MyComponent } from "./components/my-component"
export type { MyComponentProps } from "./components/my-component"
```

### Adding a New Hook

```typescript
// features/songs/hooks/use-my-hook.ts
import { useState } from "react"

export function useMyHook() {
  const [state, setState] = useState(false)
  return { state, setState }
}
```

```typescript
// features/songs/hooks/index.ts
export { useMyHook } from "./use-my-hook"
```

```typescript
// features/songs/index.ts
export { useMyHook } from "./hooks"
```

### Adding Types

```typescript
// features/songs/types/my-types.ts
export interface MyInterface {
  id: string
  name: string
}

export type MyType = "active" | "inactive"
```

```typescript
// features/songs/types/index.ts
export type { MyInterface } from "./my-types"
export type { MyType } from "./my-types"
```

```typescript
// features/songs/index.ts
export type { MyInterface, MyType } from "./types"
```

### Adding Utilities

```typescript
// features/songs/utils/my-utils.ts
export function myUtilFunction(input: string): string {
  return input.toUpperCase()
}

export function anotherUtility(num: number): number {
  return num * 2
}
```

```typescript
// features/songs/utils/index.ts
export { myUtilFunction, anotherUtility } from "./my-utils"
```

```typescript
// features/songs/index.ts
export { myUtilFunction, anotherUtility } from "./utils"
```

### Adding Context/State Management

```typescript
// features/playlists/contexts/playlists.context.tsx
'use client'

import { ReactNode, createContext, useContext, useState } from 'react'
import type { Playlist } from '../types'

interface PlaylistsContextType {
  playlists: Playlist[]
  addPlaylist: (playlist: Playlist) => void
}

const PlaylistsContext = createContext<PlaylistsContextType | undefined>(undefined)

export function PlaylistsProvider({ children }: { children: ReactNode }) {
  const [playlists, setPlaylists] = useState<Playlist[]>([])

  const addPlaylist = (playlist: Playlist) => {
    setPlaylists([...playlists, playlist])
  }

  return (
    <PlaylistsContext.Provider value={{ playlists, addPlaylist }}>
      {children}
    </PlaylistsContext.Provider>
  )
}

export function usePlaylists() {
  const context = useContext(PlaylistsContext)
  if (!context) {
    throw new Error('usePlaylists must be used within PlaylistsProvider')
  }
  return context
}
```

```typescript
// features/playlists/index.ts
export { PlaylistsProvider, usePlaylists } from "./contexts/playlists.context"
```

---

## Cross-Feature Dependencies

### ✅ DO: Use Public APIs

```typescript
// features/songs/components/song-detail/song-detail.tsx
import { usePlaylistDraft } from '@/features/playlist-draft'
import type { Playlist } from '@/features/playlists'

export function SongDetail({ song }: { song: Song }) {
  const { toggleSongInDraft } = usePlaylistDraft()

  return (
    <div>
      <h1>{song.title}</h1>
      <button onClick={() => toggleSongInDraft(song.id)}>
        Add to Playlist
      </button>
    </div>
  )
}
```

### ❌ DON'T: Import from Internal Paths

```typescript
// ❌ WRONG - Internal path
import { usePlaylistDraft } from "@/features/playlist-draft/contexts/draft.context"

// ❌ WRONG - Direct component import bypassing public API
import { SongDetail } from "@/features/songs/components/song-detail"
```

### Managing Dependencies

When adding cross-feature dependencies:

1. **Document them** in feature's README or comments
2. **Use interfaces** for type-safe contracts
3. **Keep them minimal** to reduce coupling
4. **Always use public APIs** (via index.ts)

**Example: Documenting Dependencies**

```typescript
// features/songs/components/song-detail/song-detail.tsx
/**
 * SongDetail Component
 *
 * Dependencies:
 * - @/features/playlist-draft: usePlaylistDraft
 * - @/features/playlists: Playlist type
 */
```

---

## Testing

### Test Structure

```
features/songs/__tests__/
├── fixtures/          # Mock data
│   └── songs.fixtures.ts
├── hooks/
│   └── use-songs.test.ts
└── components/
    └── song-detail.test.ts
```

### Creating Test Fixtures

```typescript
// features/songs/__tests__/fixtures/songs.fixtures.ts
import type { Song } from "../../types"

export const mockSongs: Song[] = [
  {
    id: "1",
    title: "Amazing Grace",
    artist: "John Newton",
    content: "[C]Amazing grace [Am]how sweet the sound",
    bpm: 80
  },
  {
    id: "2",
    title: "Wonderwall",
    artist: "Oasis",
    content: "[Em7]Today is gonna be the day [Dsus2]that they throw it back to you",
    bpm: 160
  }
]

export function createMockSong(overrides?: Partial<Song>): Song {
  return {
    ...mockSongs[0],
    ...overrides
  }
}
```

### Writing Component Tests

```typescript
// features/songs/__tests__/components/song-detail.test.ts
import { render, screen } from '@testing-library/react'
import { SongDetail } from '../../components/song-detail'
import { createMockSong } from '../fixtures/songs.fixtures'

describe('SongDetail', () => {
  it('renders song title and artist', () => {
    const song = createMockSong()
    render(<SongDetail song={song} />)

    expect(screen.getByText(song.title)).toBeInTheDocument()
    expect(screen.getByText(song.artist)).toBeInTheDocument()
  })
})
```

### Writing Hook Tests

```typescript
// features/songs/__tests__/hooks/use-songs.test.ts
import { renderHook, act } from "@testing-library/react"
import { useSongs } from "../../hooks/use-songs"
import { mockSongs } from "../fixtures/songs.fixtures"

describe("useSongs", () => {
  it("initializes with default songs", () => {
    const { result } = renderHook(() => useSongs())
    expect(result.current.songs).toEqual(mockSongs)
  })

  it("adds a new song", () => {
    const { result } = renderHook(() => useSongs())
    const newSong = mockSongs[0]

    act(() => {
      result.current.addSong(newSong)
    })

    expect(result.current.songs).toContainEqual(newSong)
  })
})
```

---

## Deployment

### Pre-Deployment Checklist

- [ ] All tests passing: `pnpm run test`
- [ ] TypeScript compiles: `pnpm run typecheck`
- [ ] Linting passes: `pnpm run lint`
- [ ] Build successful: `pnpm run build`
- [ ] No console errors in browser dev tools
- [ ] No broken imports in feature index files
- [ ] Documentation updated in features/docs/

### Deployment Steps

```bash
# 1. Create feature branch
git checkout -b feature/fba-migration

# 2. Review changes
git status
git diff --name-status

# 3. Run verification
pnpm run typecheck
pnpm run lint
pnpm run build

# 4. Stage and commit
git add -A
git commit -m "refactor: migrate to Feature-Based Architecture

- Reorganized components into features/
- Created public APIs via index.ts
- Updated all imports
- Added comprehensive documentation"

# 5. Push and create PR
git push origin feature/fba-migration

# 6. After merge, verify in production
# - Test all features in production
# - Monitor error tracking
# - Verify performance metrics
```

### Rollback Plan

If issues arise in production:

```bash
# Immediate rollback
git revert <commit-hash>
git push origin main

# Investigate in separate branch
git checkout -b debug/fba-issues
# ... fix issues ...
git commit -am "fix: resolve FBA migration issues"
git push origin debug/fba-issues
# Create new PR with fixes
```

---

## Troubleshooting

### Issue: Import Error "Module not found"

**Cause:** Importing from internal path instead of public API

**Solution:**

```typescript
// ❌ WRONG
import { SongsClient } from "@/features/songs/components/songs-client"

// ✅ CORRECT
import { SongsClient } from "@/features/songs"
```

### Issue: TypeScript Error "Property not exported"

**Cause:** Type or component not exported from feature's index.ts

**Solution:**

```typescript
// features/songs/index.ts
export { MyComponent } from "./components/my-component"
export type { MyComponentProps } from "./components/my-component"
```

### Issue: Context not available "... must be used within ..."

**Cause:** Provider not wrapping component, or imported from wrong path

**Solution:**

```typescript
// app/layout.tsx
import { PlaylistsProvider } from '@/features/playlists'

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html>
      <body>
        <PlaylistsProvider>
          {children}
        </PlaylistsProvider>
      </body>
    </html>
  )
}
```

### Issue: Circular dependency warning

**Cause:** Two features importing from each other

**Solution:**

- Create shared types in `@/lib/types` or `@/types`
- Use dependency injection or lifting state up
- Consider if the features should be split differently

```typescript
// ✅ GOOD: Use shared types
import type { Song } from "@/types"
import { usePlaylists } from "@/features/playlists"

// ❌ BAD: Features importing from each other
import { SongsClient } from "@/features/songs" // in playlists
import { PlaylistsClient } from "@/features/playlists" // in songs
```

### Issue: Stale types after changes

**Solution:** Rebuild TypeScript cache

```bash
# Clear and rebuild
rm -rf .next
pnpm run typecheck
pnpm run build
```

---

## Best Practices

### 1. Keep Features Small and Focused

Each feature should have a single, clear responsibility.

```
✅ Good: songs, playlists, settings
❌ Bad: songs-playlists-settings-utilities
```

### 2. Use Descriptive File Names

```
✅ Good:
- use-songs.ts
- playlist-item.tsx
- song.types.ts

❌ Bad:
- hook.ts
- item.tsx
- types.ts
```

### 3. Export Everything from index.ts

```typescript
// features/songs/index.ts
export { SongsClient, SongDetail, SongList } from "./components"
export { useSongs } from "./hooks"
export type { Song, GroupBy } from "./types"
```

### 4. Document Public APIs

```typescript
/**
 * SongsClient
 *
 * Main container for song library management.
 * Displays songs in resizable panels with search/filter capabilities.
 *
 * @example
 * import { SongsClient } from '@/features/songs'
 *
 * export default function Page() {
 *   return <SongsClient />
 * }
 */
export function SongsClient() { ... }
```

### 5. Keep Dependencies Minimal

Document all external dependencies:

```typescript
// features/songs/README.md
## Dependencies

- @/features/playlist-draft: For adding songs to playlists
- @/features/lyrics-editor: For displaying song lyrics
- @/lib: For shared utilities
```

### 6. Version Your Public APIs

```typescript
// features/songs/index.ts
// API v1.0.0
export { SongsClient } from "./components/songs-client"
export { useSongs } from "./hooks/use-songs"
export type { Song } from "./types/song.types"
```

---

## Quick Links

- **Route Files**: `app/dashboard/songs`, `app/dashboard/playlists`
- **Shared Library**: `lib/` (constants, utilities, types)
- **Global Types**: `types/` (extended.d.ts, index.d.ts)
- **Documentation**: `features/docs/` (this directory)

---

## Support

For questions or issues with FBA:

1. Check [Troubleshooting](#troubleshooting) section
2. Review similar feature in codebase
3. Check TypeScript errors: `pnpm run typecheck`
4. Review test examples in `features/[feature]/__tests__/`

---

**Last Updated:** May 24, 2026
**Maintained By:** Development Team
**Status:** ✅ Production Ready
