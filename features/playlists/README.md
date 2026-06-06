# Playlists Feature

## Overview

The playlists feature manages playlists, allowing users to create, edit, organize, and share playlists of songs. Playlists support drag-and-drop reordering, public sharing via unique share codes, optional guest edit access, and real-time sync for shared views.

## Public API

### Components

- `PlaylistsClient` - Main container component for playlist management
- `PlaylistDetail` - Displays detailed information about a single playlist
- `PlaylistList` - Renders a list of playlists
- `PlaylistItem` - Individual playlist item component
- `PlaylistSongItem` - Component for songs within a playlist

### Contexts & Hooks

- `PlaylistsProvider` - Provider for playlists context
- `usePlaylists` - Hook to access and manage playlists
- `useArchivePlaylist` - Hook to archive a playlist (sets `archivedAt`, optimistic update)
- `useUnarchivePlaylist` - Hook to restore an archived playlist (clears `archivedAt`, optimistic update)

### Utils

- `DraggablePlaylist` - Component for drag-and-drop playlist reordering

### Types

- `Playlist` - Playlist type definition (includes `share_code`, `allow_guest_edit`, `archivedAt`)
- `PlaylistWithSongs` - Playlist with songs populated
- `PlaylistDetailProps` - Props for PlaylistDetail component
- `PlaylistListProps` - Props for PlaylistList component

## Sharing

Each playlist has a `share_code` (unique, URL-safe). Sharing is opt-in — the code is generated on demand. The `allow_guest_edit` flag controls whether unauthenticated viewers can reorder songs in the shared view.

Shared playlists are accessible at `/shared/[shareCode]` and stay in sync via Supabase Realtime — song reorders by the owner are reflected immediately for all viewers.

## Archive

Playlists can be archived without deleting them. Archived playlists remain in the list but are dimmed with an "Archived" badge. Archive/unarchive from the playlist detail panel — no confirmation required, fully reversible.

**DB:** `archived_at TIMESTAMPTZ NULL` on `playlists`. `NULL` = active, timestamp = archived.

## Usage

```typescript
import {
  PlaylistsClient,
  PlaylistDetail,
  usePlaylists,
  PlaylistsProvider
} from "@/features/playlists"

// Wrap your app with the provider
<PlaylistsProvider>
  <PlaylistsClient />
</PlaylistsProvider>

// Using the hook
function MyComponent() {
  const { playlists, addPlaylist, updatePlaylist } = usePlaylists()
  // ...
}
```

## Dependencies

- `@/features/songs` - For song data and types
- `@/features/playlist-draft` - For adding songs to playlists
- `@/features/playlist-sharing` - For sharing functionality
- `@/features/settings` - For locale settings

## Internal Structure

```
features/playlists/
├── components/       # UI components
├── contexts/         # React contexts
├── hooks/            # Custom hooks
├── types/            # TypeScript types
├── utils/            # Utility functions (draggable playlist)
├── api/              # Server actions
└── __tests__/        # Tests
```
