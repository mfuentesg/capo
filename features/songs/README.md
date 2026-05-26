# Songs Feature

## Overview

The songs feature manages the song library, providing components, hooks, and utilities for displaying, searching, filtering, and managing songs. Supports full-text search, per-user song settings (capo, transpose, font size), and real-time updates.

## Public API

### Components

- `SongsClient` - Main container component for song library management
- `SongDetail` - Displays detailed information about a single song
- `SongList` - Renders a list of songs with filtering and search
- `SongItem` - Individual song item component
- `KeySelect` - Dropdown for selecting musical keys

### Hooks

- `useSongs` - Hook for managing song state and operations

### Contexts

- `NewSongsProvider` - Provider for new songs context
- `useNewSongs` - Hook to access new songs context

### Data

- `getSongById(songId: string)` - Get a single song by ID
- `getSongsByIds(songIds: string[])` - Get multiple songs by their IDs
- `getAllSongs()` - Get all songs

### Types

- `Song` - Song type definition (includes `capo`, `transpose`, `status`, `team_id`)
- `GroupBy` - Grouping options type
- `SongDetailProps` - Props for SongDetail component
- `SongListProps` - Props for SongList component
- `SongsClientProps` - Props for SongsClient component
- `BPMRange` - BPM range type
- `MusicalKey` - Musical key type

## Song Metadata

Songs store the following metadata:

| Field | Type | Description |
|---|---|---|
| `title` | string | Song title |
| `artist` | string | Artist name |
| `key` | string | Musical key (e.g. `C`, `Am`) |
| `bpm` | number | Beats per minute |
| `capo` | number | Capo fret position (global default) |
| `transpose` | number | Transposition in semitones (global default) |
| `status` | enum | `draft`, `published`, or `archived` |
| `lyrics` | string | Song body in ChordPro format |

## Per-User Song Settings

The `user_song_settings` table stores per-user overrides for any song without affecting other users:

| Field | Description |
|---|---|
| `capo` | Personal capo override |
| `transpose` | Personal transposition override |
| `font_size` | Personal display font size |

## Usage

```typescript
import { SongsClient, useSongs } from "@/features/songs"

// In a page
export default function SongsPage() {
  return <SongsClient initialSongs={initialSongs} />
}

// Using the hook
function MyComponent() {
  const { songs, addSong, updateSong } = useSongs()
  // ...
}
```

## Dependencies

- `@/features/lyrics-editor` - For displaying song lyrics
- `@/features/playlist-draft` - For adding songs to playlists
- `@/lib` - For shared utilities (music theory, constants)

## Internal Structure

```
features/songs/
├── components/       # UI components
├── hooks/            # Custom hooks
├── contexts/         # React contexts
├── types/            # TypeScript types
├── utils/            # Utility functions
├── api/              # Server actions
└── __tests__/        # Tests and fixtures
```
