# Dashboard KPI + Resilience Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four generic dashboard stat cards with actionable music-specific metrics and isolate every dashboard section so failures are contained and independently retryable.

**Architecture:** Each stat card gets its own React Query hook backed by its own API function — replacing the single batched `getDashboardStats` call. A new `SectionErrorBoundary` React class component wraps content sections (Recently Added, Activity Feed) to catch render-phase errors. Fetch-phase errors are surfaced through React Query's `isError`/`refetch` and displayed with a shared `SectionErrorFallback` component.

**Tech Stack:** Next.js 16 (App Router), Supabase JS client, React Query v5, React 19, Jest + @testing-library/react, TypeScript

---

## Chunk 1: Foundation — i18n keys + SectionErrorBoundary

### Task 1: Add i18n translation keys

**Files:**
- Modify: `lib/i18n/locales/en.json`
- Modify: `lib/i18n/locales/es.json`

- [ ] **Step 1: Update `lib/i18n/locales/en.json`** — replace the four old stat card keys and add sublabel + error keys inside the `"dashboard"` block:

Replace:
```json
"totalSongs": "Total Songs",
"playlists": "Playlists",
"thisMonth": "This Month",
"upcoming": "Upcoming",
```

With:
```json
"songsReady": "Songs Ready",
"songsReadySublabel": "have key · BPM · lyrics",
"upcomingPlaylists": "Upcoming Playlists",
"upcomingPlaylistsSublabel": "scheduled from today",
"songsThisWeek": "Songs This Week",
"songsThisWeekSublabel": "added since Monday",
"libraryCompleteness": "Library Complete",
"libraryCompletenessSublabel": "songs with full metadata",
"failedToLoad": "Failed to load",
"retry": "Retry",
```

- [ ] **Step 2: Update `lib/i18n/locales/es.json`** — same keys, Spanish values:

Replace the equivalent four old keys with:
```json
"songsReady": "Canciones listas",
"songsReadySublabel": "con tonalidad · BPM · letras",
"upcomingPlaylists": "Listas próximas",
"upcomingPlaylistsSublabel": "programadas desde hoy",
"songsThisWeek": "Canciones esta semana",
"songsThisWeekSublabel": "añadidas desde el lunes",
"libraryCompleteness": "Biblioteca completa",
"libraryCompletenessSublabel": "canciones con metadatos completos",
"failedToLoad": "Error al cargar",
"retry": "Reintentar",
```

- [ ] **Step 3: Validate translations**

```bash
pnpm i18n:validate
```

Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add lib/i18n/locales/en.json lib/i18n/locales/es.json
git commit -m "feat(dashboard): add i18n keys for new KPI stat cards and error states"
```

---

### Task 2: SectionErrorBoundary component

**Files:**
- Create: `components/ui/section-error-boundary.tsx`
- Create: `components/ui/__tests__/section-error-boundary.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `components/ui/__tests__/section-error-boundary.test.tsx`:

```tsx
import { render, screen, fireEvent } from "@testing-library/react"
import { SectionErrorBoundary } from "../section-error-boundary"

function Bomb({ shouldThrow }: { shouldThrow: boolean }) {
  if (shouldThrow) throw new Error("boom")
  return <div>safe content</div>
}

describe("SectionErrorBoundary", () => {
  let consoleSpy: jest.SpyInstance

  beforeEach(() => {
    consoleSpy = jest.spyOn(console, "error").mockImplementation(() => {})
  })

  afterEach(() => {
    consoleSpy.mockRestore()
  })

  it("renders children when no error occurs", () => {
    render(
      <SectionErrorBoundary fallback={() => <div>fallback</div>}>
        <Bomb shouldThrow={false} />
      </SectionErrorBoundary>
    )
    expect(screen.getByText("safe content")).toBeInTheDocument()
    expect(screen.queryByText("fallback")).not.toBeInTheDocument()
  })

  it("renders fallback when child throws during render", () => {
    render(
      <SectionErrorBoundary fallback={() => <div>fallback shown</div>}>
        <Bomb shouldThrow />
      </SectionErrorBoundary>
    )
    expect(screen.getByText("fallback shown")).toBeInTheDocument()
    expect(screen.queryByText("safe content")).not.toBeInTheDocument()
  })

  it("passes a retry function to fallback that resets the error state", () => {
    let shouldThrow = true
    const { rerender } = render(
      <SectionErrorBoundary fallback={(retry) => <button onClick={retry}>Retry</button>}>
        <Bomb shouldThrow={shouldThrow} />
      </SectionErrorBoundary>
    )
    expect(screen.getByRole("button", { name: "Retry" })).toBeInTheDocument()

    shouldThrow = false
    fireEvent.click(screen.getByRole("button", { name: "Retry" }))

    rerender(
      <SectionErrorBoundary fallback={(retry) => <button onClick={retry}>Retry</button>}>
        <Bomb shouldThrow={shouldThrow} />
      </SectionErrorBoundary>
    )

    expect(screen.getByText("safe content")).toBeInTheDocument()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --testPathPattern=components/ui/__tests__/section-error-boundary
```

Expected: FAIL — `Cannot find module '../section-error-boundary'`

- [ ] **Step 3: Implement `components/ui/section-error-boundary.tsx`**

```tsx
"use client"

import { Component, type ReactNode } from "react"

interface Props {
  children: ReactNode
  fallback: (retry: () => void) => ReactNode
}

interface State {
  hasError: boolean
}

export class SectionErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(): State {
    return { hasError: true }
  }

  private retry = () => {
    this.setState({ hasError: false })
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback(this.retry)
    }
    return this.props.children
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
pnpm test -- --testPathPattern=components/ui/__tests__/section-error-boundary
```

Expected: PASS — 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add components/ui/section-error-boundary.tsx components/ui/__tests__/section-error-boundary.test.tsx
git commit -m "feat(ui): add SectionErrorBoundary for per-section render error isolation"
```

---

## Chunk 2: API Layer — 4 new functions + query keys + hooks

### Task 3: Replace getDashboardStats with 4 independent API functions

**Files:**
- Modify: `features/dashboard/api/dashboardApi.ts`
- Modify: `features/dashboard/api/__tests__/dashboardApi.test.ts`
- Modify: `features/dashboard/api/index.ts`

- [ ] **Step 1: Write failing tests for the 4 new functions**

Replace the `"fetches dashboard stats..."` test in `features/dashboard/api/__tests__/dashboardApi.test.ts` with tests for the 4 new functions. Keep the `getRecentSongs` tests untouched.

```ts
import { applyContextFilter } from "@/lib/supabase/apply-context-filter"
import {
  getSongsReady,
  getUpcomingPlaylists,
  getSongsThisWeek,
  getLibraryCompleteness,
  getRecentSongs
} from "../dashboardApi"

jest.mock("@/lib/supabase/apply-context-filter", () => ({
  applyContextFilter: jest.fn((query: unknown) => query)
}))

const personalCtx = { type: "personal" as const, userId: "user-1" }
const teamCtx = { type: "team" as const, teamId: "team-1", userId: "user-1" }

function makeSingleCountSupabase(count: number | null) {
  return {
    from: jest.fn().mockReturnValue({
      select: jest.fn().mockResolvedValue({ count, error: null })
    })
  }
}

describe("getSongsReady", () => {
  afterEach(() => jest.clearAllMocks())

  it("returns count of songs where key, bpm, lyrics are all non-null", async () => {
    // notMock is called 3 times: calls 1+2 return { not: notMock }, call 3 resolves the query
    const notMock = jest.fn()
      .mockReturnValueOnce({ not: notMock })     // .not("key","is",null)
      .mockReturnValueOnce({ not: notMock })     // .not("bpm","is",null)
      .mockResolvedValueOnce({ count: 5, error: null }) // .not("lyrics","is",null) → awaited

    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({ not: notMock })
      })
    }

    const result = await getSongsReady(supabase as never, personalCtx)
    expect(supabase.from).toHaveBeenCalledWith("songs")
    expect(notMock).toHaveBeenNthCalledWith(1, "key", "is", null)
    expect(notMock).toHaveBeenNthCalledWith(2, "bpm", "is", null)
    expect(notMock).toHaveBeenNthCalledWith(3, "lyrics", "is", null)
    expect(applyContextFilter).toHaveBeenCalledTimes(1)
    expect(result).toBe(5)
  })

  it("throws when query returns an error", async () => {
    const queryError = new Error("db error")
    const notMock = jest.fn().mockReturnThis()
    notMock.mockReturnValueOnce({ not: notMock })
      .mockReturnValueOnce({ not: notMock })
      .mockResolvedValue({ count: null, error: queryError })
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({ not: notMock })
      })
    }
    await expect(getSongsReady(supabase as never, personalCtx)).rejects.toThrow("db error")
  })
})

describe("getUpcomingPlaylists", () => {
  afterEach(() => jest.clearAllMocks())

  it("returns count of playlists with date >= today", async () => {
    const gteMock = jest.fn().mockResolvedValue({ count: 3, error: null })
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({ gte: gteMock })
      })
    }
    const result = await getUpcomingPlaylists(supabase as never, teamCtx)
    expect(supabase.from).toHaveBeenCalledWith("playlists")
    expect(gteMock).toHaveBeenCalledWith("date", expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/))
    expect(applyContextFilter).toHaveBeenCalledTimes(1)
    expect(result).toBe(3)
  })

  it("throws when query returns an error", async () => {
    const queryError = new Error("upstream error")
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({
          gte: jest.fn().mockResolvedValue({ count: null, error: queryError })
        })
      })
    }
    await expect(getUpcomingPlaylists(supabase as never, personalCtx)).rejects.toThrow("upstream error")
  })
})

describe("getSongsThisWeek", () => {
  afterEach(() => {
    jest.clearAllMocks()
    jest.useRealTimers()
  })

  it("returns count of songs created since the most recent UTC Monday", async () => {
    // Wednesday 2026-03-18 UTC → Monday is 2026-03-16
    jest.useFakeTimers().setSystemTime(new Date("2026-03-18T10:00:00Z"))
    const gteMock = jest.fn().mockResolvedValue({ count: 4, error: null })
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({ gte: gteMock })
      })
    }
    const result = await getSongsThisWeek(supabase as never, personalCtx)
    expect(supabase.from).toHaveBeenCalledWith("songs")
    expect(gteMock).toHaveBeenCalledWith("created_at", "2026-03-16T00:00:00.000Z")
    expect(result).toBe(4)
  })

  it("handles Sunday correctly — Monday is 6 days prior", async () => {
    // Sunday 2026-03-22 UTC → Monday is 2026-03-16
    jest.useFakeTimers().setSystemTime(new Date("2026-03-22T00:00:00Z"))
    const gteMock = jest.fn().mockResolvedValue({ count: 0, error: null })
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({ gte: gteMock })
      })
    }
    await getSongsThisWeek(supabase as never, personalCtx)
    expect(gteMock).toHaveBeenCalledWith("created_at", "2026-03-16T00:00:00.000Z")
  })

  it("throws when query returns an error", async () => {
    const queryError = new Error("songs error")
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({
          gte: jest.fn().mockResolvedValue({ count: null, error: queryError })
        })
      })
    }
    await expect(getSongsThisWeek(supabase as never, personalCtx)).rejects.toThrow("songs error")
  })
})

describe("getLibraryCompleteness", () => {
  afterEach(() => jest.clearAllMocks())

  it("returns ready and total counts", async () => {
    const notMock = jest.fn().mockReturnThis()
    notMock
      .mockReturnValueOnce({ not: notMock })
      .mockReturnValueOnce({ not: notMock })
      .mockResolvedValue({ count: 8, error: null })

    const supabase = {
      from: jest
        .fn()
        .mockReturnValueOnce({
          // total songs query
          select: jest.fn().mockResolvedValue({ count: 20, error: null })
        })
        .mockReturnValueOnce({
          // ready songs query
          select: jest.fn().mockReturnValue({ not: notMock })
        })
    }
    const result = await getLibraryCompleteness(supabase as never, personalCtx)
    expect(result).toEqual({ ready: 8, total: 20 })
  })

  it("throws when total query errors", async () => {
    const queryError = new Error("total failed")
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockResolvedValue({ count: null, error: queryError })
      })
    }
    await expect(getLibraryCompleteness(supabase as never, personalCtx)).rejects.toThrow("total failed")
  })
})
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pnpm test -- --testPathPattern=features/dashboard/api/__tests__/dashboardApi
```

Expected: FAIL — `getSongsReady`, `getUpcomingPlaylists`, `getSongsThisWeek`, `getLibraryCompleteness` not exported

- [ ] **Step 3: Implement the 4 new functions in `features/dashboard/api/dashboardApi.ts`**

Remove `getDashboardStats` and `DashboardStats`. Keep `RecentSong`, `getRecentSongs`, `formatRelativeTime`. Add:

```ts
/**
 * Count songs where key, bpm, and lyrics are all non-null (ready for setlist)
 */
export async function getSongsReady(
  supabase: SupabaseClient<Database>,
  context: AppContext
): Promise<number> {
  let query = supabase.from("songs").select("id", { count: "exact", head: true })
  query = applyContextFilter(query, context)
  const { count, error } = await query
    .not("key", "is", null)
    .not("bpm", "is", null)
    .not("lyrics", "is", null)
  if (error) throw error
  return count ?? 0
}

/**
 * Count playlists scheduled from today onwards
 */
export async function getUpcomingPlaylists(
  supabase: SupabaseClient<Database>,
  context: AppContext
): Promise<number> {
  const today = new Date().toISOString().split("T")[0]
  let query = supabase.from("playlists").select("id", { count: "exact", head: true })
  query = applyContextFilter(query, context)
  const { count, error } = await query.gte("date", today)
  if (error) throw error
  return count ?? 0
}

/**
 * Count songs created since the most recent Monday (UTC)
 */
export async function getSongsThisWeek(
  supabase: SupabaseClient<Database>,
  context: AppContext
): Promise<number> {
  const now = new Date()
  const utcDay = now.getUTCDay() // 0 = Sunday
  const daysFromMonday = utcDay === 0 ? 6 : utcDay - 1
  const monday = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - daysFromMonday)
  )
  const mondayISO = monday.toISOString()

  let query = supabase.from("songs").select("id", { count: "exact", head: true })
  query = applyContextFilter(query, context)
  const { count, error } = await query.gte("created_at", mondayISO)
  if (error) throw error
  return count ?? 0
}

/**
 * Return the count of songs ready (key+bpm+lyrics) and total songs,
 * so the caller can compute a completion percentage.
 */
export async function getLibraryCompleteness(
  supabase: SupabaseClient<Database>,
  context: AppContext
): Promise<{ ready: number; total: number }> {
  let totalQuery = supabase.from("songs").select("id", { count: "exact", head: true })
  totalQuery = applyContextFilter(totalQuery, context)

  let readyQuery = supabase.from("songs").select("id", { count: "exact", head: true })
  readyQuery = applyContextFilter(readyQuery, context)

  const [totalResult, readyResult] = await Promise.all([
    totalQuery,
    readyQuery.not("key", "is", null).not("bpm", "is", null).not("lyrics", "is", null)
  ])

  if (totalResult.error) throw totalResult.error
  if (readyResult.error) throw readyResult.error

  return {
    total: totalResult.count ?? 0,
    ready: readyResult.count ?? 0
  }
}
```

- [ ] **Step 4: Update `features/dashboard/api/index.ts`** — keep `DashboardStats` re-export for now (it is removed in Task 7 when `dashboard-client.tsx` is replaced):

```ts
import { createApi } from "@/lib/supabase/factory"
import * as dashboardApi from "./dashboardApi"
export { dashboardApi as rawApi }

export const api = createApi(dashboardApi)

// Re-export types
// Note: DashboardStats is intentionally kept here until dashboard-client.tsx is replaced in Task 7
export type { RecentSong } from "./dashboardApi"
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
pnpm test -- --testPathPattern=features/dashboard/api/__tests__/dashboardApi
```

Expected: all tests PASS

- [ ] **Step 6: Commit**

```bash
git add features/dashboard/api/dashboardApi.ts features/dashboard/api/index.ts features/dashboard/api/__tests__/dashboardApi.test.ts
git commit -m "feat(dashboard): replace getDashboardStats with 4 independent API functions"
```

---

### Task 4: Update query keys and add 4 individual hooks

**Files:**
- Modify: `features/dashboard/hooks/query-keys.ts`
- Create: `features/dashboard/hooks/__tests__/query-keys.test.ts`
- Modify: `features/dashboard/hooks/use-dashboard.ts`
- Modify: `features/dashboard/hooks/index.ts`

- [ ] **Step 1: Write failing test for query keys**

Create `features/dashboard/hooks/__tests__/query-keys.test.ts`:

```ts
import { dashboardKeys } from "../query-keys"

const ctx = { type: "personal" as const, userId: "u1" }

describe("dashboardKeys", () => {
  it("all returns base key", () => {
    expect(dashboardKeys.all).toEqual(["dashboard"])
  })
  it("songsReady returns scoped key", () => {
    expect(dashboardKeys.songsReady(ctx)).toEqual(["dashboard", "songsReady", ctx])
  })
  it("upcomingPlaylists returns scoped key", () => {
    expect(dashboardKeys.upcomingPlaylists(ctx)).toEqual(["dashboard", "upcomingPlaylists", ctx])
  })
  it("songsThisWeek returns scoped key", () => {
    expect(dashboardKeys.songsThisWeek(ctx)).toEqual(["dashboard", "songsThisWeek", ctx])
  })
  it("libraryCompleteness returns scoped key", () => {
    expect(dashboardKeys.libraryCompleteness(ctx)).toEqual(["dashboard", "libraryCompleteness", ctx])
  })
  it("recentSongs returns scoped key with limit", () => {
    expect(dashboardKeys.recentSongs(ctx, 3)).toEqual(["dashboard", "recentSongs", ctx, 3])
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --testPathPattern=features/dashboard/hooks/__tests__/query-keys
```

Expected: FAIL — missing keys `songsReady`, `upcomingPlaylists`, `songsThisWeek`, `libraryCompleteness`

- [ ] **Step 3: Update `features/dashboard/hooks/query-keys.ts`**

```ts
import type { AppContext } from "@/features/app-context"

export const dashboardKeys = {
  all: ["dashboard"] as const,
  songsReady: (context: AppContext) => [...dashboardKeys.all, "songsReady", context] as const,
  upcomingPlaylists: (context: AppContext) =>
    [...dashboardKeys.all, "upcomingPlaylists", context] as const,
  songsThisWeek: (context: AppContext) =>
    [...dashboardKeys.all, "songsThisWeek", context] as const,
  libraryCompleteness: (context: AppContext) =>
    [...dashboardKeys.all, "libraryCompleteness", context] as const,
  recentSongs: (context: AppContext, limit: number) =>
    [...dashboardKeys.all, "recentSongs", context, limit] as const
}
```

- [ ] **Step 4: Run query key tests to verify they pass**

```bash
pnpm test -- --testPathPattern=features/dashboard/hooks/__tests__/query-keys
```

Expected: PASS — 6 tests pass

- [ ] **Step 5: Replace `useDashboardStats` with 4 hooks in `features/dashboard/hooks/use-dashboard.ts`**

```ts
"use client"

import { useQuery } from "@tanstack/react-query"
import { useUser } from "@/features/auth"
import { useAppContext } from "@/features/app-context"
import { api } from "@/features/dashboard/api"
import type { RecentSong } from "@/features/dashboard/api"
import { dashboardKeys } from "./query-keys"

function useEnabled() {
  const { context } = useAppContext()
  const { data: user } = useUser()
  return { context, enabled: !!context && !!user?.id }
}

export function useSongsReady(initialData?: number) {
  const { context, enabled } = useEnabled()
  return useQuery({
    queryKey: context ? dashboardKeys.songsReady(context) : dashboardKeys.all,
    queryFn: () => (context ? api.getSongsReady(context) : 0),
    enabled,
    initialData
  })
}

export function useUpcomingPlaylists(initialData?: number) {
  const { context, enabled } = useEnabled()
  return useQuery({
    queryKey: context ? dashboardKeys.upcomingPlaylists(context) : dashboardKeys.all,
    queryFn: () => (context ? api.getUpcomingPlaylists(context) : 0),
    enabled,
    initialData
  })
}

export function useSongsThisWeek(initialData?: number) {
  const { context, enabled } = useEnabled()
  return useQuery({
    queryKey: context ? dashboardKeys.songsThisWeek(context) : dashboardKeys.all,
    queryFn: () => (context ? api.getSongsThisWeek(context) : 0),
    enabled,
    initialData
  })
}

export function useLibraryCompleteness(initialData?: { ready: number; total: number }) {
  const { context, enabled } = useEnabled()
  return useQuery({
    queryKey: context ? dashboardKeys.libraryCompleteness(context) : dashboardKeys.all,
    queryFn: () =>
      context ? api.getLibraryCompleteness(context) : { ready: 0, total: 0 },
    enabled,
    initialData
  })
}

export function useRecentSongs(limit: number = 5, initialData?: RecentSong[]) {
  const { context, enabled } = useEnabled()
  return useQuery({
    queryKey: context ? dashboardKeys.recentSongs(context, limit) : dashboardKeys.all,
    queryFn: () => (context ? api.getRecentSongs(context, limit) : []),
    enabled,
    initialData
  })
}
```

- [ ] **Step 6: Update `features/dashboard/hooks/index.ts`**

```ts
export { useSongsReady, useUpcomingPlaylists, useSongsThisWeek, useLibraryCompleteness, useRecentSongs } from "./use-dashboard"
export { dashboardKeys } from "./query-keys"
```

- [ ] **Step 7: Update `features/dashboard/index.ts`** — update public exports:

```ts
export { api, rawApi } from "./api"
export type { RecentSong } from "./api"
export {
  useSongsReady,
  useUpcomingPlaylists,
  useSongsThisWeek,
  useLibraryCompleteness,
  useRecentSongs,
  dashboardKeys
} from "./hooks"
```

- [ ] **Step 8: Run typecheck**

```bash
pnpm typecheck
```

Expected: no errors

- [ ] **Step 9: Commit**

```bash
git add features/dashboard/hooks/query-keys.ts \
        features/dashboard/hooks/__tests__/query-keys.test.ts \
        features/dashboard/hooks/use-dashboard.ts \
        features/dashboard/hooks/index.ts \
        features/dashboard/index.ts
git commit -m "feat(dashboard): add 4 individual stat hooks and granular query keys"
```

---

## Chunk 3: StatCard Component + ActivityFeed Error Handling

### Task 5: StatCard component

**Files:**
- Create: `features/dashboard/components/stat-card.tsx`
- Create: `features/dashboard/components/__tests__/stat-card.test.tsx`

Note: `features/dashboard/components/` does not exist yet — it will be created when you write these files.

- [ ] **Step 1: Write the failing test**

Create `features/dashboard/components/__tests__/stat-card.test.tsx`:

```tsx
import { render, screen, fireEvent } from "@testing-library/react"
import { StatCard } from "../stat-card"

describe("StatCard", () => {
  it("renders value and labels normally", () => {
    render(
      <StatCard label="Songs Ready" sublabel="have key · BPM · lyrics" value={42} />
    )
    expect(screen.getByText("42")).toBeInTheDocument()
    expect(screen.getByText("Songs Ready")).toBeInTheDocument()
    expect(screen.getByText("have key · BPM · lyrics")).toBeInTheDocument()
  })

  it("renders skeleton when isLoading", () => {
    const { container } = render(
      <StatCard label="Songs Ready" sublabel="have key · BPM · lyrics" value={0} isLoading />
    )
    // Skeleton elements should be present, value should not be rendered as text
    expect(container.querySelector("[data-slot='skeleton']")).toBeInTheDocument()
    expect(screen.queryByText("42")).not.toBeInTheDocument()
  })

  it("renders error state with retry button when isError", () => {
    const onRetry = jest.fn()
    render(
      <StatCard
        label="Songs Ready"
        sublabel="have key · BPM · lyrics"
        value={0}
        isError
        onRetry={onRetry}
      />
    )
    expect(screen.getByText("Failed to load")).toBeInTheDocument()
    expect(screen.queryByText("42")).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole("button", { name: /retry/i }))
    expect(onRetry).toHaveBeenCalledTimes(1)
  })

  it("renders '—' for zero value when displayDash is true", () => {
    render(
      <StatCard label="Library Complete" sublabel="songs with full metadata" value="—" />
    )
    expect(screen.getByText("—")).toBeInTheDocument()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pnpm test -- --testPathPattern=features/dashboard/components/__tests__/stat-card
```

Expected: FAIL — `Cannot find module '../stat-card'`

- [ ] **Step 3: Implement `features/dashboard/components/stat-card.tsx`**

```tsx
import { Skeleton } from "@/components/ui/skeleton"

interface StatCardProps {
  label: string
  sublabel: string
  value: number | string
  isLoading?: boolean
  isError?: boolean
  onRetry?: () => void
}

export function StatCard({ label, sublabel, value, isLoading, isError, onRetry }: StatCardProps) {
  return (
    <div className="rounded-lg border bg-card p-6 shadow-sm">
      <div className="flex items-center gap-4">
        <div className="space-y-2">
          {isLoading ? (
            <>
              <Skeleton className="h-7 w-12" data-slot="skeleton" />
              <Skeleton className="h-4 w-20" data-slot="skeleton" />
            </>
          ) : isError ? (
            <div>
              <p className="text-sm text-destructive">Failed to load</p>
              <button
                onClick={onRetry}
                className="text-xs text-destructive underline"
                aria-label="Retry"
              >
                Retry
              </button>
            </div>
          ) : (
            <>
              <p className="text-2xl font-bold">{value}</p>
              <p className="text-sm text-muted-foreground">{label}</p>
              <p className="text-xs text-muted-foreground">{sublabel}</p>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
pnpm test -- --testPathPattern=features/dashboard/components/__tests__/stat-card
```

Expected: PASS — 4 tests pass

- [ ] **Step 5: Commit**

```bash
git add features/dashboard/components/stat-card.tsx \
        features/dashboard/components/__tests__/stat-card.test.tsx
git commit -m "feat(dashboard): add StatCard component with loading and error states"
```

---

### Task 6: ActivityFeed error handling

**Files:**
- Modify: `features/activity/components/activity-feed.tsx`
- Modify: `features/activity/index.ts`

- [ ] **Step 1: Add error state handling to `features/activity/components/activity-feed.tsx`**

Add `isError` and `refetch` to the `useActivities` destructuring at line 112, and render an inline error fallback when the feed fails. Also import `SectionErrorBoundary` and `SectionErrorFallback`. Update the component signature — no external props are needed since the error state comes from `useActivities`.

Update the hook destructuring at line 112:

```ts
const { data: activities, isLoading, isError, refetch } = useActivities(5)
```

Add an error state check directly after the `isLoading` check:

```tsx
if (isError) {
  return (
    <div className="flex flex-col items-center justify-center p-8 text-center gap-3">
      <p className="text-sm text-destructive">Failed to load activity</p>
      <button
        onClick={() => refetch()}
        className="text-xs text-destructive underline"
      >
        Retry
      </button>
    </div>
  )
}
```

- [ ] **Step 2: Verify the activity feature still exports correctly from `features/activity/index.ts`**

The index uses `export * from "./components"` — no changes needed if `ActivityFeed` signature didn't change (it hasn't; error state is internal). Confirm by running typecheck:

```bash
pnpm typecheck
```

Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add features/activity/components/activity-feed.tsx
git commit -m "feat(activity): add inline error state with retry to ActivityFeed"
```

---

## Chunk 4: Server Component + Client Component

### Task 7: Update server component — 5 parallel fetches

**Files:**
- Modify: `app/(app)/dashboard/page.tsx`

- [ ] **Step 1: Update `app/(app)/dashboard/page.tsx`**

Replace the `Promise.all` block (lines 40-48) with a 5-item version. Each has its own `.catch()` fallback:

```ts
const [
  initialSongsReady,
  initialUpcomingPlaylists,
  initialSongsThisWeek,
  initialLibraryCompleteness,
  initialRecentSongs
] = await Promise.all([
  dashboardApi.getSongsReady(supabase, context).catch(() => 0),
  dashboardApi.getUpcomingPlaylists(supabase, context).catch(() => 0),
  dashboardApi.getSongsThisWeek(supabase, context).catch(() => 0),
  dashboardApi.getLibraryCompleteness(supabase, context).catch(() => ({ ready: 0, total: 0 })),
  dashboardApi.getRecentSongs(supabase, context, 3).catch(() => [])
])
```

Update the `return` to pass the 5 props to `DashboardClient`:

```tsx
return (
  <DashboardClient
    initialSongsReady={initialSongsReady}
    initialUpcomingPlaylists={initialUpcomingPlaylists}
    initialSongsThisWeek={initialSongsThisWeek}
    initialLibraryCompleteness={initialLibraryCompleteness}
    initialRecentSongs={initialRecentSongs}
    t={t}
  />
)
```

- [ ] **Step 2: Run typecheck** (DashboardClient props don't match yet — expect failure)

```bash
pnpm typecheck
```

Expected: type error on `DashboardClient` props — this is expected; we fix it in Task 8.

---

### Task 8: Rewrite DashboardClient

**Files:**
- Modify: `app/(app)/dashboard/dashboard-client.tsx`

This is the largest change. The dashboard-client receives 5 new initial values, uses 4 individual hooks for stats, wires `isError`/`refetch` to each `StatCard`, wraps the recently-added section with error boundary + React Query error state, and wraps the activity feed with `SectionErrorBoundary`.

- [ ] **Step 1: Remove stale `DashboardStats` from `features/dashboard/api/index.ts`**

Now that `dashboard-client.tsx` is being replaced (it no longer uses `DashboardStats`), clean up:

```ts
import { createApi } from "@/lib/supabase/factory"
import * as dashboardApi from "./dashboardApi"
export { dashboardApi as rawApi }

export const api = createApi(dashboardApi)

export type { RecentSong } from "./dashboardApi"
```

Also update `features/dashboard/index.ts` to remove `DashboardStats` from its re-exports (already done in Task 4 Step 7, just confirm it's not present).

- [ ] **Step 2: Replace the entire `dashboard-client.tsx`**

```tsx
"use client"

import Link from "next/link"
import dynamic from "next/dynamic"
import { Music, ListMusic, Plus, Clock, ArrowRight, Zap } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import KeyBadge from "@/components/key-badge"
import { useActivityRealtime } from "@/features/activity"
import type { RecentSong } from "@/features/dashboard"
import {
  useSongsReady,
  useUpcomingPlaylists,
  useSongsThisWeek,
  useLibraryCompleteness,
  useRecentSongs
} from "@/features/dashboard"
import { StatCard } from "@/features/dashboard/components/stat-card"
import { SectionErrorBoundary } from "@/components/ui/section-error-boundary"
import { Skeleton } from "@/components/ui/skeleton"
import { getBpmColorClasses } from "@/lib/badge-colors"
import { cn } from "@/lib/utils"
import type { getTranslations } from "@/lib/i18n/translations"

const ActivityFeedLazy = dynamic(
  () => import("@/features/activity").then((mod) => mod.ActivityFeed),
  {
    ssr: false,
    loading: () => (
      <div className="space-y-3 p-4">
        {[1, 2, 3].map((i) => (
          <div key={i} className="flex items-center gap-3">
            <Skeleton className="h-8 w-8 rounded-full" />
            <div className="flex-1 space-y-1">
              <Skeleton className="h-4 w-3/4" />
              <Skeleton className="h-3 w-1/2" />
            </div>
          </div>
        ))}
      </div>
    )
  }
)

function RecentSongSkeleton() {
  return (
    <div className="flex items-center gap-4 rounded-xl p-3">
      <Skeleton className="h-10 w-10 rounded-lg" />
      <div className="flex-1 space-y-2">
        <Skeleton className="h-5 w-32" />
        <Skeleton className="h-4 w-24" />
      </div>
      <div className="hidden sm:flex items-center gap-3">
        <Skeleton className="h-6 w-16 rounded-full" />
        <Skeleton className="h-4 w-20" />
      </div>
    </div>
  )
}

function SectionErrorFallback({ title, onRetry }: { title: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center p-8 text-center gap-2">
      <p className="text-sm font-medium">{title}</p>
      <p className="text-sm text-destructive">Failed to load</p>
      <button onClick={onRetry} className="text-xs text-destructive underline">
        Retry
      </button>
    </div>
  )
}

interface DashboardClientProps {
  initialSongsReady?: number
  initialUpcomingPlaylists?: number
  initialSongsThisWeek?: number
  initialLibraryCompleteness?: { ready: number; total: number }
  initialRecentSongs?: RecentSong[]
  t: ReturnType<typeof getTranslations>
}

export default function DashboardClient({
  initialSongsReady = 0,
  initialUpcomingPlaylists = 0,
  initialSongsThisWeek = 0,
  initialLibraryCompleteness = { ready: 0, total: 0 },
  initialRecentSongs = [],
  t
}: DashboardClientProps) {
  const { data: songsReady = 0, isLoading: readyLoading, isError: readyError, refetch: refetchReady } =
    useSongsReady(initialSongsReady)
  const { data: upcomingPlaylists = 0, isLoading: upcomingLoading, isError: upcomingError, refetch: refetchUpcoming } =
    useUpcomingPlaylists(initialUpcomingPlaylists)
  const { data: songsThisWeek = 0, isLoading: weekLoading, isError: weekError, refetch: refetchWeek } =
    useSongsThisWeek(initialSongsThisWeek)
  const { data: completeness = initialLibraryCompleteness, isLoading: completenessLoading, isError: completenessError, refetch: refetchCompleteness } =
    useLibraryCompleteness(initialLibraryCompleteness)
  const { data: recentSongs = initialRecentSongs, isLoading: songsLoading, isError: songsError, refetch: refetchSongs } =
    useRecentSongs(3, initialRecentSongs)

  useActivityRealtime()

  const completenessValue =
    completeness.total === 0
      ? "—"
      : `${Math.round((completeness.ready / completeness.total) * 100)}%`

  return (
    <div className="relative min-h-screen bg-background overflow-hidden">
      <div className="pointer-events-none absolute inset-0 -z-10" aria-hidden>
        <div
          className="absolute -top-32 -right-32 h-[500px] w-[500px] rounded-full"
          style={{ background: "radial-gradient(circle, oklch(0.62 0.2 280 / 10%) 0%, transparent 70%)" }}
        />
        <div
          className="absolute top-1/2 -left-48 h-[600px] w-[600px] rounded-full"
          style={{ background: "radial-gradient(circle, oklch(0.65 0.21 40 / 10%) 0%, transparent 70%)" }}
        />
        <div
          className="absolute -bottom-32 right-1/3 h-[400px] w-[400px] rounded-full"
          style={{ background: "radial-gradient(circle, oklch(0.58 0.18 220 / 8%) 0%, transparent 70%)" }}
        />
      </div>

      <main className="px-4 py-6 sm:px-8 sm:py-10 lg:px-12 lg:py-12">
        <div className="mx-auto max-w-7xl space-y-6 sm:space-y-8">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="space-y-1">
              <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">{t.dashboard.title}</h1>
              <p className="text-muted-foreground">{t.dashboard.description}</p>
            </div>
            <div className="flex gap-2">
              <Button variant="outline" asChild className="transition-shadow hover:shadow-md bg-transparent">
                <Link href="/dashboard/playlists">
                  <ListMusic className="mr-2 h-4 w-4" />
                  {t.dashboard.newPlaylist}
                </Link>
              </Button>
              <Button asChild className="transition-shadow hover:shadow-md">
                <Link href="/dashboard/songs">
                  <Plus className="mr-2 h-4 w-4" />
                  {t.dashboard.addSong}
                </Link>
              </Button>
            </div>
          </div>

          {/* Stat Cards — each fails and retries independently */}
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Link href="/dashboard/songs" className="block transition hover:shadow-md hover:-translate-y-0.5">
              <StatCard
                label={t.dashboard.songsReady}
                sublabel={t.dashboard.songsReadySublabel}
                value={songsReady}
                isLoading={readyLoading}
                isError={readyError}
                onRetry={() => refetchReady()}
              />
            </Link>
            <Link href="/dashboard/playlists" className="block transition hover:shadow-md hover:-translate-y-0.5">
              <StatCard
                label={t.dashboard.upcomingPlaylists}
                sublabel={t.dashboard.upcomingPlaylistsSublabel}
                value={upcomingPlaylists}
                isLoading={upcomingLoading}
                isError={upcomingError}
                onRetry={() => refetchUpcoming()}
              />
            </Link>
            <Link href="/dashboard/songs" className="block transition hover:shadow-md hover:-translate-y-0.5">
              <StatCard
                label={t.dashboard.songsThisWeek}
                sublabel={t.dashboard.songsThisWeekSublabel}
                value={songsThisWeek > 0 ? `+${songsThisWeek}` : "—"}
                isLoading={weekLoading}
                isError={weekError}
                onRetry={() => refetchWeek()}
              />
            </Link>
            <div>
              <StatCard
                label={t.dashboard.libraryCompleteness}
                sublabel={t.dashboard.libraryCompletenessSublabel}
                value={completenessValue}
                isLoading={completenessLoading}
                isError={completenessError}
                onRetry={() => refetchCompleteness()}
              />
            </div>
          </div>

          <div className="grid gap-6 lg:grid-cols-3">
            {/* Recently Added — error boundary + React Query error state */}
            <div className="lg:col-span-2 rounded-lg border bg-card shadow-sm">
              <div className="flex items-center justify-between p-4 border-b">
                <div>
                  <div className="flex items-center gap-2 mb-0.5">
                    <div
                      className="flex h-6 w-6 items-center justify-center rounded-full"
                      style={{ backgroundColor: "color-mix(in oklch, var(--accent-songs) 10%, transparent)" }}
                    >
                      <Music className="h-3.5 w-3.5" style={{ color: "var(--accent-songs)" }} />
                    </div>
                    <h3 className="text-lg font-semibold">{t.dashboard.recentlyAdded}</h3>
                  </div>
                  <p className="text-sm text-muted-foreground">{t.dashboard.latestSongs}</p>
                </div>
                <Button variant="ghost" size="sm" asChild className="hover:bg-accent">
                  <Link href="/dashboard/songs">
                    {t.dashboard.viewAll}
                    <ArrowRight className="ml-1 h-4 w-4" />
                  </Link>
                </Button>
              </div>
              <SectionErrorBoundary
                fallback={(retry) => (
                  <SectionErrorFallback title={t.dashboard.recentlyAdded} onRetry={retry} />
                )}
              >
                <div className="space-y-3 p-4">
                  {songsLoading ? (
                    <>
                      <RecentSongSkeleton />
                      <RecentSongSkeleton />
                      <RecentSongSkeleton />
                    </>
                  ) : songsError ? (
                    <SectionErrorFallback
                      title={t.dashboard.recentlyAdded}
                      onRetry={() => refetchSongs()}
                    />
                  ) : recentSongs && recentSongs.length > 0 ? (
                    recentSongs.map((song: RecentSong) => (
                      <Link
                        key={song.id}
                        href={`/dashboard/songs/${song.id}`}
                        className="flex items-center gap-4 rounded-xl p-3 transition hover:bg-muted/50 hover:shadow-sm cursor-pointer"
                      >
                        <KeyBadge keyValue={song.key} size="md" />
                        <div className="flex-1 min-w-0">
                          <p className="font-medium truncate">{song.title}</p>
                          <p className="text-sm text-muted-foreground truncate">{song.artist}</p>
                        </div>
                        <div className="hidden sm:flex items-center gap-3 text-sm text-muted-foreground">
                          <Badge variant="secondary" className={cn("rounded-full", getBpmColorClasses(song.bpm))}>
                            {song.bpm} BPM
                          </Badge>
                          <span className="flex items-center gap-1">
                            <Clock className="h-3.5 w-3.5" />
                            {song.addedAt}
                          </span>
                        </div>
                      </Link>
                    ))
                  ) : (
                    <div className="text-center py-8 text-muted-foreground">
                      <Music className="mx-auto h-8 w-8 mb-2 opacity-50" />
                      <p>{t.dashboard.noSongsYet}</p>
                      <Button variant="link" asChild className="mt-2">
                        <Link href="/dashboard/songs">{t.dashboard.addYourFirstSong}</Link>
                      </Button>
                    </div>
                  )}
                </div>
              </SectionErrorBoundary>
            </div>

            {/* Activity Feed — SectionErrorBoundary for render-phase crashes */}
            <div className="rounded-lg border bg-card shadow-sm">
              <div className="p-4 border-b">
                <div className="flex items-center gap-2 mb-0.5">
                  <div className="flex h-6 w-6 items-center justify-center rounded-full bg-primary/10">
                    <Zap className="h-3.5 w-3.5 text-primary" />
                  </div>
                  <h3 className="text-lg font-semibold">{t.dashboard.recentActivity}</h3>
                </div>
                <p className="text-sm text-muted-foreground">{t.dashboard.recentActivityDescription}</p>
              </div>
              <SectionErrorBoundary
                fallback={(retry) => (
                  <SectionErrorFallback title={t.dashboard.recentActivity} onRetry={retry} />
                )}
              >
                <ActivityFeedLazy />
              </SectionErrorBoundary>
            </div>
          </div>
        </div>
      </main>
    </div>
  )
}
```

- [ ] **Step 3: Run typecheck**

```bash
pnpm typecheck
```

Expected: no errors

- [ ] **Step 4: Run lint**

```bash
pnpm lint
```

Expected: zero warnings/errors

- [ ] **Step 5: Run full test suite**

```bash
pnpm test
```

Expected: all tests pass, coverage ≥ 80%

- [ ] **Step 6: Validate i18n**

```bash
pnpm i18n:validate
```

Expected: no errors

- [ ] **Step 7: Commit**

```bash
git add features/dashboard/api/index.ts \
        app/(app)/dashboard/page.tsx \
        app/(app)/dashboard/dashboard-client.tsx
git commit -m "feat(dashboard): wire 4 independent stat hooks and per-section error boundaries"
```

---

## Final Verification

- [ ] Start dev server and open `http://localhost:3000/dashboard` — confirm 4 new stat cards render
- [ ] Temporarily break one API call (e.g., add `.not('key','is',null).not('key','is',null)` to `getSongsReady` to cause a type error) and verify only that card shows "Failed to load · Retry" while all others remain functional, then revert
- [ ] Confirm "Recently Added" section shows "Failed to load · Retry" independently when `useRecentSongs` fails (e.g., temporarily throw from `getRecentSongs`)
- [ ] Confirm activity section shows its own error state from `useActivities` failing
- [ ] Run `pnpm test:coverage` and confirm ≥ 80% on all thresholds
