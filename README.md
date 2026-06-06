# Capo

<p align="center">
    <img src="./public/img/capo.svg" height="120" alt="Capo logo" />
</p>
<br />

A modern song library and collaboration platform for musicians, featuring chords and lyrics for your favorite songs. Built with [`Next.js`](https://nextjs.org/) and powered by the [`ChordPro`](https://www.chordpro.org/) file format for chord notation.

## Why Capo?

A `Capo` is a small device that clamps onto the neck of a guitar and shortens the length of the strings. The main
advantage of using a capo is that it lets a guitarist play a song in different keys while still using first-position
open-string chord forms.

## Motivation

During past months my son has been learning to play guitar. I decided to build him a tool to make his learning process easier. As a passionate musician and software engineer, I want to create something more powerful by combining my knowledge of music and programming.

Beyond helping beginners learn, this app serves musicians of all levels by providing an organized song library with easy access to chords and lyrics for practice and performance.

Apart from that, it sounds fascinating and fun 🤓.

## Features

### Song Library

Browse and manage your personal collection of songs. Filter by musical key, BPM range, and status (active/archived). Full-text search across titles and artists. Songs are stored in [ChordPro](https://www.chordpro.org/) format and support rich metadata including BPM, key, capo position, and transposition.

### Per-User Song Settings

Each user can save personal overrides for any song: capo position, transposition semitones, and display font size. These settings are stored per user and do not affect how other users see the same song.

### Lyrics & Chords Editor

View and edit songs with a split-pane interface: a [CodeMirror](https://codemirror.net/)-powered ChordPro editor on one side and a live-rendered lyrics/chord view on the other. Supports per-section chord colors, multi-column layout preferences, auto-scroll for hands-free performance, and automatic conversion of pasted "chords-over-words" text into ChordPro format.

### Playlists

Create and manage playlists of songs. Reorder songs via drag-and-drop. Archive playlists to hide them from active view without deleting — unarchive at any time. Each playlist can be shared publicly with a unique share code, with optional guest edit access.

### Playlist Draft (Quick Add)

A cart-like interface for quickly building playlists. Add songs to a draft from anywhere in the library, then save the draft as a new or existing playlist.

### Playlist Sharing

Share any playlist publicly via a unique share code. Recipients can view the full playlist and individual song sheets without needing an account. Real-time updates keep shared playlists in sync when the owner reorders songs.

### Song Creation & Editing

Create new songs or edit existing ones using the ChordPro format. The song editor includes syntax highlighting, live preview, and metadata fields (title, artist, key, BPM, capo, transpose).

### Chord Glossary & Analyzer

Browse a built-in chord glossary organized by key, search chords by name, and identify chords from guitar fingering positions. Supports both left-hand and right-hand chord diagram orientations.

### Chord Audio Playback

Play any chord as audio directly from the chord glossary, chord analyzer, or the lyrics editor chord diagram dialog. Powered by [Tone.js](https://tonejs.github.io/) with a singleton MIDI sampler for low-latency playback.

### Teams & Collaboration

Create teams and invite other users by email. Team members share a common song library and playlists. Role-based access control (owner, admin, member, viewer). Manage pending invitations, transfer ownership, and switch between personal and team contexts. Real-time updates for team membership changes.

### Dashboard

An overview page showing library stats (total songs, playlists, teams) and recently added songs for quick access.

### Activity Tracking

Tracks user engagement across the app in real time to surface relevant content and support future personalization.

### Settings

- **Theme**: Switch between light and dark mode.
- **Language**: Change the UI language (i18n support).
- **Chord Hand**: Choose between left-hand and right-hand chord diagram orientation.
- **Account**: Delete your account and all associated data.

### Authentication

Sign in with Google OAuth. Sessions are managed via Supabase Auth.

## Stack

- **[Next.js 16](https://nextjs.org/)** (App Router) + **[React 19](https://react.dev/)** + **[TypeScript 5](https://www.typescriptlang.org/)**
- **[TailwindCSS 4](https://tailwindcss.com/)** + **[shadcn/ui](https://ui.shadcn.com/)** + **[Radix UI](https://www.radix-ui.com/)**
- **[Supabase](https://supabase.com/)** (PostgreSQL + Auth + Realtime)
- **[React Query](https://tanstack.com/query)** for server state management
- **[CodeMirror](https://codemirror.net/)** for the ChordPro lyrics editor
- **[ChordPro](https://www.chordpro.org/)** / **[chordsheetjs](https://github.com/martijnversluis/ChordSheetJS)** for song format parsing
- **[Tone.js](https://tonejs.github.io/)** for chord audio playback
- **[react-hook-form](https://react-hook-form.com/)** + **[Zod](https://zod.dev/)** for form validation
- **[@dnd-kit](https://dndkit.com/)** + **[@hello-pangea/dnd](https://github.com/hello-pangea/dnd)** for drag-and-drop
- **[Resend](https://resend.com/)** for transactional email (team invitations)

## Architecture

This project uses **Feature-Based Architecture (FBA)** for better code organization and scalability.

### Features

| Feature | Purpose |
|---|---|
| `activity` | Real-time activity tracking across the app |
| `app-context` | Global context for team/bucket switching and view filters |
| `auth` | Google OAuth authentication via Supabase Auth |
| `chord-audio` | Chord audio playback via Tone.js MIDI sampler |
| `chords` | Chord glossary, search, and guitar chord analyzer |
| `dashboard` | Overview stats (songs, playlists, teams) and recent songs |
| `feedback` | In-app feedback and newsletter opt-in form |
| `lyrics-editor` | CodeMirror ChordPro editor with live preview and auto-scroll |
| `playlist-draft` | Quick-add-to-playlist cart for building setlists on the fly |
| `playlist-sharing` | Public playlist sharing via unique share codes |
| `playlists` | Create, manage, reorder, share, and archive playlists |
| `settings` | Theme (light/dark), language, chord hand, account management |
| `song-draft` | Create and edit songs in ChordPro format |
| `songs` | Song library management with search, filtering, and editing |
| `teams` | Team creation, role-based access, and email invitations |

### 📚 Documentation

- **[FBA Guide](./features/docs/FBA_GUIDE.md)** - Complete developer guide for Feature-Based Architecture
  - Quick start rules
  - Adding components, hooks, types
  - Cross-feature dependencies
  - Testing patterns
  - Deployment checklist


## Getting started

### Prerequisites

- [Docker](https://docs.docker.com/engine/install/) - For running Supabase services locally
- [fnm](https://github.com/Schniz/fnm) - Node version manager

### Installation

Install fnm, Node, and pnpm:

```bash
# Install fnm as node version manager
curl -fsSL https://fnm.vercel.app/install | bash

# fnm automatically uses the Node version from .node-version
fnm use

# Install pnpm globally
npm install -g pnpm

# Install project dependencies
pnpm install
```

### Development

#### 1. Start Supabase Services Locally

```bash
# Start Supabase services locally
pnpm supabase start
```

See [Supabase Local Development Guide](https://supabase.com/docs/guides/resources/supabase-cli/local-development) for more details.

#### 2. Configure Google Provider for Local Login

To enable Google OAuth for local development:

1. Go to your Supabase project dashboard
2. Navigate to **Authentication > Providers**
3. Enable the Google provider
4. Add your OAuth credentials:
   - **Client ID**: Get from [Google Cloud Console](https://console.cloud.google.com/)
   - **Client Secret**: Get from [Google Cloud Console](https://console.cloud.google.com/)
5. Add redirect URI: `http://localhost:3000/auth/callback`

For local testing with Google Auth, create OAuth credentials with:

- **Authorized redirect URIs**: `http://localhost:3000/auth/callback`

#### 3. Start Development Server

```bash
pnpm dev
```

This starts the Next.js development server at [`http://localhost:3000`](http://localhost:3000).

> **Note**: Ensure Supabase services are running before starting the dev server.

## Help me keep making awesome stuff

Contribute with me, supporting this project through

<a href="https://www.buymeacoffee.com/mfuentesg" target="_blank">
   <img height="41" src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" />
</a>

Happy Coding!
