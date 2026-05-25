# Dashboard: Actionable KPIs + Per-Section Resilience

## Context

The current dashboard shows four generic stat cards (Total Songs, Total Playlists, Songs This Month, Upcoming Playlists) fetched as a single batched API call. If any query in that batch fails, all four cards fail together. The "Recently Added" and "Recent Activity" sections are also coupled at the page level with no per-section error recovery.

The goal is to replace the KPIs with actionable music-specific metrics and to isolate each stat card and each content section so that failures are contained and retryable independently.

---

## New KPIs

Replace the four existing stat cards with:

| Card | Metric | Query |
|------|--------|-------|
| Songs Ready | COUNT songs where `key IS NOT NULL AND bpm IS NOT NULL AND lyrics IS NOT NULL` | `songs` |
| Upcoming Playlists | COUNT playlists where `date >= today` (unchanged) | `playlists` |
| Songs This Week | COUNT songs where `created_at >= start of current ISO week (Monday)` | `songs` |
| Library Completeness | `(songs_ready / total_songs * 100)` — displayed as `72%` with sublabel | `songs` (two counts) |

`Library Completeness` returns `{ ready: number, total: number }` from the API; the percentage is computed in the hook. When `total === 0`, display `—` instead of `0%`.

---

## Architecture

### 1. API layer — `features/dashboard/api/dashboardApi.ts`

Remove `getDashboardStats` and `DashboardStats`. Add four independent functions:

```ts
getSongsReady(supabase, context): Promise<number>
getUpcomingPlaylists(supabase, context): Promise<number>
getSongsThisWeek(supabase, context): Promise<number>
getLibraryCompleteness(supabase, context): Promise<{ ready: number; total: number }>
```

Each function applies `applyContextFilter`. On Supabase error, call `if (error) throw error` — matching the `getRecentSongs` pattern (note: the old `getDashboardStats` silently swallowed errors via `.count ?? 0`; the new functions intentionally diverge from that). Keep `getRecentSongs` unchanged. Keep `formatRelativeTime` unchanged.

`getSongsThisWeek` computes the start of the current week as the most recent Monday at 00:00:00 UTC (using `created_at >= mondayISO` where `mondayISO` is derived from UTC date arithmetic, not `new Date()` local time).

`getLibraryCompleteness` runs two COUNT queries in `Promise.all`: one for total songs, one for ready songs (key + bpm + lyrics all non-null, using chained `.not('key','is',null).not('bpm','is',null).not('lyrics','is',null)`).

### 2. API index — `features/dashboard/api/index.ts`

Expose the four new functions through the existing factory wrapper (`createApi`). Remove `getDashboardStats` export.

### 3. Query keys — `features/dashboard/hooks/query-keys.ts`

Replace `stats(context)` with four granular keys:

```ts
songsReady: (context) => [...all, "songsReady", context]
upcomingPlaylists: (context) => [...all, "upcomingPlaylists", context]
songsThisWeek: (context) => [...all, "songsThisWeek", context]
libraryCompleteness: (context) => [...all, "libraryCompleteness", context]
```

### 4. Hooks — `features/dashboard/hooks/use-dashboard.ts`

Replace `useDashboardStats` with four individual hooks:

```ts
useSongsReady(initialData?: number)
useUpcomingPlaylists(initialData?: number)
useSongsThisWeek(initialData?: number)
useLibraryCompleteness(initialData?: { ready: number; total: number })
```

Each hook follows the same `enabled: !!context && !!user?.id` + `initialData` pattern as the current hooks. Each returns the full React Query result including `isLoading`, `isError`, and `refetch`.

### 5. Error boundary — `components/ui/section-error-boundary.tsx`

New React class component `SectionErrorBoundary` with:
- `children` prop
- `fallback` prop: `(retry: () => void) => ReactNode` — caller provides the error UI
- Catches render errors from children; resets state when `retry()` is called

This is used to catch both thrown errors from Error Boundary-compatible patterns and is paired with React Query's error state for fetch errors (see below).

### 6. StatCard component (new)

The dashboard currently renders stat cards as inline JSX in `dashboard-client.tsx`. Extract this into a new `features/dashboard/components/stat-card.tsx` with props:

```ts
interface StatCardProps {
  label: string
  sublabel: string
  value: number | string
  isLoading?: boolean
  isError?: boolean
  onRetry?: () => void
}
```

When `isLoading` is true, render the existing skeleton. When `isError` is true, render "Failed to load" + a "Retry" button that calls `onRetry` (which is `refetch()` from the React Query hook). No `SectionErrorBoundary` is needed for individual stat cards since the error state comes from React Query, not a thrown render error.

### 7. Content section error handling

**Recently Added section:** The recently-added block stays inline in `dashboard-client.tsx` (no sub-component extraction). Wrap it in `SectionErrorBoundary`:

```tsx
<SectionErrorBoundary fallback={(retry) => <SectionErrorFallback title="Recently Added" onRetry={retry} />}>
  {/* recently added JSX */}
</SectionErrorBoundary>
```

Additionally, when `songsLoading === false && songsError` (React Query `isError`), render `<SectionErrorFallback title="Recently Added" onRetry={refetch} />` inline — this handles fetch errors that don't throw during render.

**Activity Feed section:** `ActivityFeedLazy` is loaded via `next/dynamic`, so React Error Boundary cannot catch import-time errors. Instead, add `isError` and `onRetry` props to `ActivityFeed` (matching the stat card pattern). Inside `activity-feed.tsx`, add `isError` and `refetch` to the `useActivities` destructuring and wire them to `SectionErrorFallback`. `ActivityFeed`'s public API in `features/activity/index.ts` must be updated to reflect the new props. The `SectionErrorBoundary` wrapper is still useful for unexpected render-phase crashes but the primary error path goes through React Query state.

`SectionErrorFallback` renders the section title + "Failed to load · Retry" in the error style shown in the approved mockup.

### 8. Server component — `app/(app)/dashboard/page.tsx`

Replace the two-item `Promise.all` with a five-item version, one per new API function, each with its own `.catch()` fallback:

```ts
const [initialSongsReady, initialUpcomingPlaylists, initialSongsThisWeek,
        initialLibraryCompleteness, initialRecentSongs] = await Promise.all([
  dashboardApi.getSongsReady(supabase, context).catch(() => 0),
  dashboardApi.getUpcomingPlaylists(supabase, context).catch(() => 0),
  dashboardApi.getSongsThisWeek(supabase, context).catch(() => 0),
  dashboardApi.getLibraryCompleteness(supabase, context).catch(() => ({ ready: 0, total: 0 })),
  dashboardApi.getRecentSongs(supabase, context, 3).catch(() => [])
])
```

Pass each as a separate prop to `DashboardClient`.

### 9. Client component — `app/(app)/dashboard/dashboard-client.tsx`

Update props to receive five initial values. Replace `useDashboardStats` with four individual hooks. Wire `isError` + `refetch` into each `StatCard`. Wrap sections with `SectionErrorBoundary`.

---

## Files Changed

| File | Change |
|------|--------|
| `features/dashboard/api/dashboardApi.ts` | Remove `getDashboardStats`/`DashboardStats`, add 4 new functions |
| `features/dashboard/api/index.ts` | Expose 4 new functions, remove old one |
| `features/dashboard/hooks/query-keys.ts` | Replace `stats` key with 4 granular keys |
| `features/dashboard/hooks/use-dashboard.ts` | Replace `useDashboardStats` with 4 hooks |
| `features/dashboard/index.ts` | Remove exports: `DashboardStats`, `useDashboardStats`. Add exports: `useSongsReady`, `useUpcomingPlaylists`, `useSongsThisWeek`, `useLibraryCompleteness`, `StatCard` |
| `features/dashboard/hooks/index.ts` | Remove `useDashboardStats`. Add the four new hooks. |
| `app/(app)/dashboard/page.tsx` | Fetch 5 items in parallel with individual catch |
| `app/(app)/dashboard/dashboard-client.tsx` | 4 hooks, error props, section error boundaries; remove stale `DashboardStats` import |
| `features/activity/components/activity-feed.tsx` | Add `isError`/`onRetry` props; destructure `isError` and `refetch` from `useActivities` |
| `features/activity/index.ts` | Update `ActivityFeed` export to reflect new props |
| `components/ui/section-error-boundary.tsx` | New: reusable error boundary class component |
| `features/dashboard/components/stat-card.tsx` | New: extracted StatCard component with error/retry state |
| `lib/i18n/locales/en.json` | Replace `dashboard.totalSongs`, `dashboard.playlists`, `dashboard.thisMonth`, `dashboard.upcoming` with `dashboard.songsReady`, `dashboard.upcomingPlaylists`, `dashboard.songsThisWeek`, `dashboard.libraryCompleteness` and their sublabel keys |
| `lib/i18n/locales/es.json` | Same translation key changes in Spanish |

---

## Tests to Update / Add

- `features/dashboard/__tests__/` — add test cases for each new API function (happy path + error thrown)
- `features/dashboard/__tests__/` — add hook tests for the four new hooks
- Update existing hook/API tests that reference `getDashboardStats` or `DashboardStats`
- `components/ui/__tests__/` — test `SectionErrorBoundary` catches errors and calls retry

---

## Verification

1. `pnpm typecheck` — no type errors
2. `pnpm lint` — zero warnings
3. `pnpm test` — all tests pass, coverage ≥ 80%
4. Manual: kill network mid-load, confirm one stat card shows "Failed to load · Retry" while others render normally
5. Manual: retry button on a failed card refetches only that card
6. Manual: confirm Recently Added and Activity sections fail independently of each other and of the stat cards
