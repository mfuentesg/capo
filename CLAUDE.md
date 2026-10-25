# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
pnpm dev              # Start dev server with webpack (http://localhost:3000) — Turbopack is disabled because it causes Monaco Editor to emit spurious "ERR Canceled: Canceled" errors in development
pnpm build            # Production build
pnpm typecheck        # TypeScript type checking
pnpm lint             # ESLint (zero warnings tolerance)
pnpm lint:fix         # ESLint auto-fix
pnpm test             # Run Jest tests
pnpm test:watch       # Jest watch mode
pnpm test:coverage    # Jest with coverage report
pnpm types:generate   # Regenerate lib/supabase/database.types.ts from local Supabase schema
pnpm i18n:validate    # Validate translation files
```

**Run a single test file:**
```bash
pnpm test -- --testPathPattern=features/songs/__tests__/hooks/use-songs.test.ts
```

**Local Supabase (required for development):**
```bash
pnpm supabase start   # Start local Supabase (Docker required)
pnpm supabase stop    # Stop local Supabase
```

## Architecture

### Feature-Based Architecture (FBA)

All business logic lives in `features/[feature-name]/`. The three rules:

1. **Organize by Feature** — code belongs in `features/[feature-name]/`
2. **Use Public APIs** — always import from `@/features/[name]` (never from internal paths)
3. **Export from index.ts** — each feature's contract is its `features/[name]/index.ts`

```
features/
├── songs/           # Song library management
├── playlists/       # Playlist management
├── playlist-draft/  # Quick-add-to-playlist cart
├── lyrics-editor/   # Song lyrics display/formatting
├── playlist-sharing/# Share playlists via share codes
├── song-draft/      # Song creation and editing
├── settings/        # Theme, language, user preferences
├── auth/            # Authentication
├── dashboard/       # Dashboard UI
├── activity/        # Activity tracking
├── teams/           # Team management and invitations
├── app-context/     # Global app context
├── feedback/        # In-app feedback submission
└── docs/            # FBA_GUIDE.md
```

Each feature follows this internal structure:
```
features/[name]/
├── components/      # UI components
├── hooks/           # Custom React hooks
├── types/           # TypeScript interfaces
├── utils/           # Utility functions
├── contexts/        # React Context state (if needed)
├── api/             # Server actions
├── data/            # Data fetching utilities
├── __tests__/       # Tests and fixtures
└── index.ts         # PUBLIC API — the only import point
```

Cross-feature imports must always go through the public API:
```typescript
// ✅ CORRECT
import { usePlaylistDraft } from "@/features/playlist-draft"

// ❌ WRONG — never import from internal paths
import { usePlaylistDraft } from "@/features/playlist-draft/contexts/playlist-draft.context"
```

### App Router

Routes live in `app/`. Protected routes are under `app/dashboard/`. Public routes include `app/(app)/shared/[shareCode]/` and `app/teams/accept-invitation/`.

### Data Layer

- `lib/supabase/client.ts` — browser-side Supabase client
- `lib/supabase/server.ts` — server-side Supabase client (Next.js server components / actions)
- `lib/supabase/database.types.ts` — auto-generated types from schema (do not edit manually)
- `lib/supabase/apply-context-filter.ts` — shared query filter logic
- Server actions live in `features/[name]/api/actions.ts`

### State Management

- **React Query** (`@tanstack/react-query`) for server state
- **React Context** for global/shared client state within a feature
- Query keys are defined in `features/[name]/hooks/query-keys.ts`

#### Avoiding SSR Hydration Mismatches with React Query

**Do not use `HydrationBoundary` + `prefetchQuery` for page-level data.** React Query's `browserQueryClient` is a module-level singleton that persists across soft navigations. When it already holds cached data, `HydrationBoundary` defers hydration to a `useEffect` (which doesn't run during SSR), causing the server to render an empty/loading state while the client renders stale cache data — a hydration mismatch.

**Preferred pattern:** Fetch data directly in the server component and pass it as a prop to the client component. Use it as a default value when React Query's `data` is undefined:

```tsx
// ✅ Server component (page)
const initialPlaylists = await api.getPlaylists(context).catch(() => [])
return <PlaylistsClient initialPlaylists={initialPlaylists} />

// ✅ Client component
export function PlaylistsClient({ initialPlaylists = [] }: { initialPlaylists?: Playlist[] }) {
  const { data: playlists = initialPlaylists } = usePlaylists()
  // ...
}
```

This guarantees server and client render the same initial HTML. React Query still manages cache, mutations, and background refetches normally after hydration.

## Code Style

Enforced by Prettier (`.prettierrc`):
- No semicolons
- Double quotes (`"`)
- Print width: 100
- No trailing commas
- 2-space indentation

ESLint is strict: `--max-warnings 0` means any warning fails the check. `@typescript-eslint/no-explicit-any` is enforced.

## Testing

- Tests use Jest + `@testing-library/react` with jsdom
- Test files live in `features/[name]/__tests__/` and `lib/__tests__/`
- Fixtures (mock data) go in `__tests__/fixtures/`
- Coverage threshold: 80% branches/functions/lines/statements
- Coverage is only collected from specific paths (see `jest.config.js` `collectCoverageFrom`)

## Database

Migrations are in `supabase/migrations/`. **Always create migrations using the CLI** — never apply SQL directly via MCP or other tools (direct applies corrupt the migration history table):

```bash
pnpm supabase migration new "describe_your_change"  # creates timestamped file
# then write SQL into the generated file, then:
pnpm supabase migration up --local                  # apply to local DB
pnpm types:generate                                 # regenerate types after schema changes
```

The local Supabase stack:
- API: `localhost:54321`
- DB: `localhost:54322` (PostgreSQL)
- Studio: `localhost:54323`

## i18n

Translation files are validated with `pnpm i18n:validate`. Translation hook is `hooks/use-translation.ts`. Translations live in `lib/i18n/`.

## Mobile Interaction Rules

These rules exist because violating them caused "multiple taps required" and general sluggishness on mobile. They are enforced by ESLint where possible, but the architectural ones require human/Claude review.

### 1. Overlay panels must disable pointer events immediately on close

Any `fixed`/`absolute` panel that uses an exit animation **must** have `data-[state=closed]:pointer-events-none` in its className. Without it, the panel remains interactive for the full animation duration and silently swallows taps directed at content behind it.

Already applied to:
- `DrawerContent` ✓
- `DrawerOverlay` ✓
- `DialogOverlay` ✓
- `DialogContent` ✓
- `SheetContent` ✓
- `SheetOverlay` ✓

**Rule**: if you add a new overlay-like component (Portal + fixed + animated exit), add `data-[state=closed]:pointer-events-none`.

### 2. Scrollable content inside a Drawer must use `<DrawerScrollArea>`

```tsx
// ✅ CORRECT — data-vaul-no-drag is applied automatically
import { DrawerScrollArea } from "@/components/ui/drawer"
<DrawerContent>
  <DrawerScrollArea>
    {/* content */}
  </DrawerScrollArea>
</DrawerContent>

// ❌ WRONG — vaul's swipe detection intercepts taps inside scrollable areas
<DrawerContent>
  <div className="flex-1 overflow-y-auto">
    {/* content */}
  </div>
</DrawerContent>
```

**Why**: Vaul registers `onPointerDown` on the entire `DrawerContent` to track swipe-to-close gestures. Without `data-vaul-no-drag`, vertical scroll inside a drawer conflicts with drag detection and can consume the first tap as a drag candidate on iOS.

Non-scrollable areas inside drawers (e.g. a fixed-height nav list) should use `data-vaul-no-drag` directly on the element.

### 3. No `transition-all` — enforced by ESLint

`transition-all` animates **every CSS property** on every change. On mobile this forces the browser to check all properties on each frame. The ESLint rule `no-restricted-syntax` will **error** on any string literal containing `transition-all`.

Use the narrowest correct alternative:
| What changes on interaction | Use |
|---|---|
| Colors, background, border-color | `transition-colors` |
| Opacity | `transition-opacity` |
| Transform (scale, rotate, translate) | `transition-transform` |
| Box-shadow | `transition-shadow` |
| Colors + shadow + transform | `transition` (covers all visual properties, not layout) |

### 4. No `backdrop-blur` on mobile sticky/fixed elements

`backdrop-filter: blur()` on a sticky navbar forces the browser to composite the entire page behind it on every frame. On mobile GPUs this is very expensive.

```tsx
// ✅ CORRECT — blur only on desktop
<header className="... bg-background md:bg-background/80 md:backdrop-blur-md">

// ❌ WRONG — blur applies on mobile too
<header className="... bg-background/80 backdrop-blur-md">
```
