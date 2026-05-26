# Team Context UX Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface team/context switching as a persistent navbar pill, persist the ViewFilter across reloads, and replace the weak song/playlist ownership indicator with a clearer inline chip.

**Architecture:** Add a `capo_view_filter` cookie to persist `ViewFilter` server-side; create a `ContextPill` component that replaces the hidden `ContextSwitcher` in the user profile menu; update `SongItem` and `PlaylistItem` to render a colored chip with a color dot for team-owned items in "All" view.

**Tech Stack:** Next.js 14 App Router, React Query, Tailwind CSS, shadcn/ui (Popover, Avatar), Vaul drawer, Lucide icons, `"use server"` directives.

---

## Chunk 1: ViewFilter persistence layer

### Task 1: Add VIEW_FILTER_KEY constant

**Files:**

- Modify: `features/app-context/constants.ts`

- [ ] **Step 1: Add the constant**

```ts
export const SELECTED_TEAM_ID_KEY = "capo_selected_team_id"
export const VIEW_FILTER_KEY = "capo_view_filter"
```

- [ ] **Step 2: Verify TypeScript**

```bash
pnpm typecheck
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add features/app-context/constants.ts
git commit -m "feat(app-context): add VIEW_FILTER_KEY cookie constant"
```

---

### Task 2: Add server-side ViewFilter cookie helpers

**Files:**

- Modify: `features/app-context/server.ts`

`getViewFilterCookie` is an **unexported** internal helper called only inside `getInitialAppContextData`. `setViewFilterCookie` is an exported server action callable from client components (same pattern as `setSelectedTeamId`).

- [ ] **Step 1: Write a failing test for setViewFilterCookie**

Create `features/app-context/__tests__/server.test.ts`:

```ts
import { setViewFilterCookie } from "../server"

// Declare at module scope so they're accessible in all tests
const mockSet = jest.fn()
const mockDelete = jest.fn()

jest.mock("next/headers", () => ({
  cookies: jest.fn().mockResolvedValue({
    set: mockSet,
    delete: mockDelete,
    get: jest.fn()
  })
}))

beforeEach(() => {
  jest.clearAllMocks()
})

describe("setViewFilterCookie", () => {
  it("sets the view filter cookie to the given type", async () => {
    await setViewFilterCookie("team")

    expect(mockSet).toHaveBeenCalledWith(
      "capo_view_filter",
      "team",
      expect.objectContaining({ path: "/", maxAge: 31536000 })
    )
  })

  it("deletes the cookie when type is 'all'", async () => {
    await setViewFilterCookie("all")

    expect(mockDelete).toHaveBeenCalledWith("capo_view_filter")
  })
})
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
pnpm test -- --testPathPattern=features/app-context/__tests__/server.test.ts
```

Expected: FAIL — `setViewFilterCookie` not defined.

- [ ] **Step 3: Add getViewFilterCookie (unexported) and setViewFilterCookie to server.ts**

Add after the existing `unsetSelectedTeamId` function in `features/app-context/server.ts`:

```ts
async function getViewFilterCookie(): Promise<"all" | "personal" | "team" | null> {
  const { cookies } = await import("next/headers")
  const cookieStore = await cookies()
  const value = cookieStore.get(VIEW_FILTER_KEY)?.value
  if (value === "all" || value === "personal" || value === "team") return value
  return null
}

export async function setViewFilterCookie(type: "all" | "personal" | "team") {
  const { cookies } = await import("next/headers")
  const cookieStore = await cookies()
  if (type === "all") {
    cookieStore.delete(VIEW_FILTER_KEY)
  } else {
    cookieStore.set(VIEW_FILTER_KEY, type, {
      path: "/",
      maxAge: 31536000,
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production"
    })
  }
}
```

Also add `VIEW_FILTER_KEY` to the import from constants:

```ts
import { SELECTED_TEAM_ID_KEY, VIEW_FILTER_KEY } from "./constants"
```

- [ ] **Step 4: Run test — expect PASS**

```bash
pnpm test -- --testPathPattern=features/app-context/__tests__/server.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add features/app-context/server.ts features/app-context/__tests__/server.test.ts
git commit -m "feat(app-context): add setViewFilterCookie server action and getViewFilterCookie helper"
```

---

### Task 3: Update getInitialAppContextData to return initialViewFilter

**Files:**

- Modify: `features/app-context/server.ts`

`getInitialAppContextData` already returns `initialSelectedTeamId`. We add `initialViewFilter` with stale-ID validation.

- [ ] **Step 1: Write a failing test**

Add to `features/app-context/__tests__/server.test.ts`:

```ts
import { getInitialAppContextData } from "../server"

describe("getInitialAppContextData", () => {
  it("returns initialViewFilter: all when no cookie is set", async () => {
    // mock supabase, cookies returning null for both cookies
    // ... (mock setup omitted for brevity — follow existing test patterns in the codebase)
    const result = await getInitialAppContextData()
    expect(result.initialViewFilter).toEqual({ type: "all" })
  })

  it("returns initialViewFilter: personal when cookie is 'personal'", async () => {
    // mock capo_view_filter cookie returning 'personal'
    const result = await getInitialAppContextData()
    expect(result.initialViewFilter).toEqual({ type: "personal" })
  })

  it("falls back to all when capo_view_filter is 'team' but team ID is not in user teams", async () => {
    // mock capo_view_filter = 'team', capo_selected_team_id = 'stale-id', teams = []
    const result = await getInitialAppContextData()
    expect(result.initialViewFilter).toEqual({ type: "all" })
  })
})
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
pnpm test -- --testPathPattern=features/app-context/__tests__/server.test.ts
```

Expected: FAIL — `initialViewFilter` not in returned object.

- [ ] **Step 3: Update getInitialAppContextData**

In `features/app-context/server.ts`:

1. At the **top of the file**, extend the existing type import to include `ViewFilter`:

```ts
// Before:
import type { AppContext } from "./types"
// After:
import type { AppContext, ViewFilter } from "./types"
```

2. Add `getViewFilterCookie()` to the parallel `Promise.all` inside `getInitialAppContextData`:

```ts
const [userProfile, teams, selectedTeamId, preferences, rawViewFilter] = await Promise.all([
  getUser(supabase),
  getTeamsWithClient(supabase, userId),
  getSelectedTeamId(),
  getUserPreferences(supabase, userId).catch(() => null),
  getViewFilterCookie()
])
```

3. Both **early-return branches** (before the `Promise.all`) must include `initialViewFilter` to satisfy the return type. Update each:

```ts
// first early return (no authUser):
return {
  user: null,
  teams: [],
  initialSelectedTeamId: null,
  preferences: null,
  initialViewFilter: { type: "all" } as const
}

// second early return (no userProfile):
return {
  user: null,
  teams: [],
  initialSelectedTeamId: null,
  preferences: null,
  initialViewFilter: { type: "all" } as const
}
```

4. After computing `initialSelectedTeamId`, compute and validate `initialViewFilter` (plain code — no imports needed, `ViewFilter` is already imported at the top):

```ts
let initialViewFilter: ViewFilter = { type: "all" }
if (rawViewFilter === "personal") {
  initialViewFilter = { type: "personal" }
} else if (rawViewFilter === "team") {
  if (initialSelectedTeamId) {
    initialViewFilter = { type: "team", teamId: initialSelectedTeamId }
  } else {
    // Stale team ID — reset cookie
    const { cookies } = await import("next/headers")
    const cookieStore = await cookies()
    cookieStore.delete(VIEW_FILTER_KEY)
    initialViewFilter = { type: "all" }
  }
}
```

5. Include `initialViewFilter` in the success return:

```ts
return {
  user: userProfile,
  teams,
  initialSelectedTeamId,
  preferences,
  initialViewFilter
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
pnpm test -- --testPathPattern=features/app-context/__tests__/server.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add features/app-context/server.ts features/app-context/__tests__/server.test.ts
git commit -m "feat(app-context): return initialViewFilter from getInitialAppContextData with stale-ID validation"
```

---

### Task 4: Update AppContextProvider to accept and persist ViewFilter

**Files:**

- Modify: `features/app-context/context.tsx`

- [ ] **Step 1: Write a failing test**

Create `features/app-context/__tests__/context.test.tsx`:

```tsx
import { render, act } from "@testing-library/react"
import { AppContextProvider } from "../context"
import { useViewFilter } from "../view-filter-context"

// Mock server actions
jest.mock("../server", () => ({
  setSelectedTeamId: jest.fn().mockResolvedValue(undefined),
  unsetSelectedTeamId: jest.fn().mockResolvedValue(undefined),
  setViewFilterCookie: jest.fn().mockResolvedValue(undefined)
}))
jest.mock("next/navigation", () => ({ useRouter: () => ({ refresh: jest.fn() }) }))
jest.mock("@tanstack/react-query", () => ({
  useQuery: jest.fn().mockReturnValue({ data: [], isLoading: false }),
  useQueryClient: jest.fn().mockReturnValue({ invalidateQueries: jest.fn() })
}))
jest.mock("@/features/auth", () => ({
  useUser: jest.fn().mockReturnValue({ data: { id: "user-1" } })
}))
jest.mock("@/features/teams/api", () => ({ api: { getTeams: jest.fn().mockResolvedValue([]) } }))
jest.mock("@/features/teams/hooks/query-keys", () => ({ teamsKeys: { list: () => ["teams"] } }))

function TestChild() {
  const { viewFilter } = useViewFilter()
  return <div data-testid="filter">{viewFilter.type}</div>
}

it("initializes viewFilter from initialViewFilter prop", () => {
  const { getByTestId } = render(
    <AppContextProvider
      initialViewFilter={{ type: "personal" }}
      initialUser={{ id: "user-1", email: "a@b.com" }}
    >
      <TestChild />
    </AppContextProvider>
  )
  expect(getByTestId("filter").textContent).toBe("personal")
})
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
pnpm test -- --testPathPattern=features/app-context/__tests__/context.test.tsx
```

Expected: FAIL — `initialViewFilter` prop not accepted.

- [ ] **Step 3: Update AppContextProvider**

In `features/app-context/context.tsx`:

1. Add `setViewFilterCookie` to the server import:

```ts
import {
  setSelectedTeamId as setClientSelectedTeamId,
  unsetSelectedTeamId as unsetClientSelectedTeamId,
  setViewFilterCookie
} from "./server"
```

2. Add `initialViewFilter` to `AppContextProviderProps`:

```ts
interface AppContextProviderProps {
  children: ReactNode
  initialSelectedTeamId?: string | null
  initialTeams?: Tables<"teams">[]
  initialUser?: UserInfo | null
  initialViewFilter?: ViewFilter
}
```

3. Accept it in the function signature and initialize `viewFilter` from it:

```ts
export function AppContextProvider({
  children,
  initialSelectedTeamId = null,
  initialTeams = [],
  initialUser = null,
  initialViewFilter = { type: "all" }
}: AppContextProviderProps) {
  // ...
  const [viewFilter, setViewFilterState] = useState<ViewFilter>(initialViewFilter)
```

4. Update `setViewFilter` to persist the cookie and sync `capo_selected_team_id`:

```ts
const setViewFilter = useCallback(
  (filter: ViewFilter) => {
    setViewFilterState(filter)

    // Sync AppContext (creation bucket) — same as before, no router.refresh()
    if (filter.type !== "all" && user?.id) {
      const newContext: AppContext =
        filter.type === "personal"
          ? { type: "personal", userId: user.id }
          : { type: "team", teamId: filter.teamId, userId: user.id }
      setContextState(newContext)
    }

    // NEW: persist ViewFilter cookie + keep capo_selected_team_id in sync
    void setViewFilterCookie(filter.type)
    if (filter.type === "team") {
      void setClientSelectedTeamId(filter.teamId)
    } else if (filter.type === "personal") {
      void unsetClientSelectedTeamId()
    }
    // filter.type === "all": leave capo_selected_team_id untouched
  },
  [user]
)
```

- [ ] **Step 4: Run test — expect PASS**

```bash
pnpm test -- --testPathPattern=features/app-context/__tests__/context.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add features/app-context/context.tsx features/app-context/__tests__/context.test.tsx
git commit -m "feat(app-context): persist ViewFilter to cookie on change and initialize from server prop"
```

---

### Task 5: Pass initialViewFilter from layout to AppContextProvider

**Files:**

- Modify: `app/(app)/layout.tsx`

- [ ] **Step 1: Update AppContextProvider props in layout**

In `app/(app)/layout.tsx`, add `initialViewFilter` to the `AppContextProvider`:

```tsx
<AppContextProvider
  initialSelectedTeamId={appContextData.initialSelectedTeamId}
  initialTeams={appContextData.teams}
  initialUser={appContextData.user}
  initialViewFilter={appContextData.initialViewFilter}
>
```

- [ ] **Step 2: Verify TypeScript**

```bash
pnpm typecheck
```

Expected: no errors.

- [ ] **Step 3: Verify tests still pass**

```bash
pnpm test
```

Expected: all passing.

- [ ] **Step 4: Commit**

```bash
git add app/\(app\)/layout.tsx
git commit -m "feat(app-context): wire initialViewFilter from server into AppContextProvider"
```

---

## Chunk 2: ContextPill component and navbar changes

### Task 6: Create ContextPill component

**Files:**

- Create: `components/layout/context-pill.tsx`

The `ContextPill` is a `Popover`-based navbar button. It reads `viewFilter` and `teams` from context and renders a compact pill that opens a dropdown switcher.

- [ ] **Step 1: Write a failing test**

Create `components/layout/__tests__/context-pill.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react"
import { ContextPill } from "../context-pill"

jest.mock("@/features/app-context", () => ({
  useViewFilter: jest.fn().mockReturnValue({
    viewFilter: { type: "all" },
    setViewFilter: jest.fn()
  }),
  useAppContext: jest.fn().mockReturnValue({
    teams: [{ id: "t1", name: "Worship Team", icon: null, avatar_url: null }]
  })
}))
jest.mock("@/features/auth", () => ({
  useUser: jest.fn().mockReturnValue({ data: { displayName: "Jane", avatarUrl: null } })
}))
jest.mock("@/features/settings", () => ({
  useLocale: jest.fn().mockReturnValue({
    t: {
      nav: {
        viewAll: "All",
        filterContext: "Filter view",
        personalAccount: "Personal",
        manageTeams: "Manage Teams"
      }
    }
  })
}))

it("shows 'All' label when viewFilter is all", () => {
  render(<ContextPill />)
  expect(screen.getByText("All")).toBeInTheDocument()
})

it("shows team name when viewFilter is team", () => {
  const { useViewFilter } = require("@/features/app-context")
  useViewFilter.mockReturnValue({
    viewFilter: { type: "team", teamId: "t1" },
    setViewFilter: jest.fn()
  })
  render(<ContextPill />)
  expect(screen.getByText("Worship Team")).toBeInTheDocument()
})
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
pnpm test -- --testPathPattern=components/layout/__tests__/context-pill.test.tsx
```

Expected: FAIL — module not found.

- [ ] **Step 3: Implement ContextPill**

Create `components/layout/context-pill.tsx`:

```tsx
"use client"

import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Button } from "@/components/ui/button"
import { Check, ChevronDown, CircleUserRound, Layers } from "lucide-react"
import { cn } from "@/lib/utils"
import { useUser } from "@/features/auth"
import { useAppContext, useViewFilter } from "@/features/app-context"
import { useLocale } from "@/features/settings"
import { TeamIcon } from "@/components/ui/icon-picker"
import Link from "next/link"
import type { Tables } from "@/lib/supabase/database.types"
import type { ViewFilter } from "@/features/app-context"

function PillTrigger({
  viewFilter,
  teams,
  userName,
  userAvatarUrl
}: {
  viewFilter: ViewFilter
  teams: Tables<"teams">[]
  userName: string
  userAvatarUrl?: string | null
}) {
  if (viewFilter.type === "team") {
    const team = teams.find((t) => t.id === viewFilter.teamId)
    return (
      <>
        <Avatar className="h-5 w-5 shrink-0">
          {team?.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
          <AvatarFallback className="rounded text-[9px] bg-primary/20">
            <TeamIcon icon={team?.icon ?? null} className="h-3 w-3" />
          </AvatarFallback>
        </Avatar>
        <span className="max-w-[80px] truncate text-xs font-medium sm:max-w-[120px]">
          {team?.name ?? "Team"}
        </span>
      </>
    )
  }

  if (viewFilter.type === "personal") {
    return (
      <>
        <Avatar className="h-5 w-5 shrink-0">
          {userAvatarUrl && <AvatarImage src={userAvatarUrl} alt={userName} />}
          <AvatarFallback className="bg-primary/10">
            <CircleUserRound className="h-3 w-3 text-muted-foreground" />
          </AvatarFallback>
        </Avatar>
        <span className="max-w-[80px] truncate text-xs font-medium sm:max-w-[120px]">
          {userName}
        </span>
      </>
    )
  }

  // "all"
  return (
    <>
      <div className="relative flex shrink-0">
        <Avatar className="h-5 w-5">
          {userAvatarUrl && <AvatarImage src={userAvatarUrl} alt={userName} />}
          <AvatarFallback className="bg-primary/10">
            <CircleUserRound className="h-3 w-3 text-muted-foreground" />
          </AvatarFallback>
        </Avatar>
        {teams.length > 0 && (
          <Avatar className="h-5 w-5 -ml-1.5 ring-2 ring-background">
            {teams[0].avatar_url && <AvatarImage src={teams[0].avatar_url} alt={teams[0].name} />}
            <AvatarFallback className="bg-primary/20 text-[9px]">
              <TeamIcon icon={teams[0].icon} className="h-3 w-3" />
            </AvatarFallback>
          </Avatar>
        )}
        {teams.length === 0 && <Layers className="h-3.5 w-3.5 text-muted-foreground" />}
      </div>
      <span className="text-xs font-medium">All</span>
    </>
  )
}

export function ContextPill() {
  const { t } = useLocale()
  const { data: user } = useUser()
  const { teams } = useAppContext()
  const { viewFilter, setViewFilter } = useViewFilter()

  const hasTeams = teams.length > 0
  const userName = user?.displayName || user?.email || "You"
  const isFiltered = viewFilter.type !== "all"

  return (
    <Popover>
      <PopoverTrigger asChild>
        <Button
          variant="ghost"
          size="sm"
          className={cn(
            "flex h-8 items-center gap-1.5 rounded-full px-2.5 transition-colors",
            isFiltered && "bg-accent/60 hover:bg-accent/80"
          )}
        >
          <PillTrigger
            viewFilter={viewFilter}
            teams={teams}
            userName={userName}
            userAvatarUrl={user?.avatarUrl}
          />
          <ChevronDown className="h-3 w-3 shrink-0 text-muted-foreground" />
        </Button>
      </PopoverTrigger>
      <PopoverContent align="end" className="w-64 p-2">
        <p className="px-2 py-1 text-xs font-semibold text-muted-foreground">
          {t.nav.filterContext}
        </p>

        {/* All */}
        {hasTeams && (
          <button
            onClick={() => setViewFilter({ type: "all" })}
            className={cn(
              "flex w-full items-center gap-3 rounded-md px-2 py-2 text-left transition-colors hover:bg-accent",
              viewFilter.type === "all" && "bg-accent"
            )}
          >
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 shrink-0">
              <Layers className="h-4 w-4 text-muted-foreground" />
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium">{t.nav.viewAll}</span>
                {viewFilter.type === "all" && <Check className="h-4 w-4 text-primary shrink-0" />}
              </div>
              <p className="text-xs text-muted-foreground truncate">{t.nav.viewAllDescription}</p>
            </div>
          </button>
        )}

        {/* Personal */}
        <button
          onClick={() => setViewFilter({ type: "personal" })}
          className={cn(
            "flex w-full items-center gap-3 rounded-md px-2 py-2 text-left transition-colors hover:bg-accent",
            viewFilter.type === "personal" && "bg-accent"
          )}
        >
          <Avatar className="h-8 w-8 shrink-0">
            {user?.avatarUrl && <AvatarImage src={user.avatarUrl} alt={userName} />}
            <AvatarFallback className="bg-primary/10">
              <CircleUserRound className="h-4 w-4 text-muted-foreground" />
            </AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium truncate">{userName}</span>
              {viewFilter.type === "personal" && (
                <Check className="h-4 w-4 text-primary shrink-0" />
              )}
            </div>
            <p className="text-xs text-muted-foreground truncate">{t.nav.personalAccount}</p>
          </div>
        </button>

        {/* Teams */}
        {teams.map((team) => (
          <button
            key={team.id}
            onClick={() => setViewFilter({ type: "team", teamId: team.id })}
            className={cn(
              "flex w-full items-center gap-3 rounded-md px-2 py-2 text-left transition-colors hover:bg-accent",
              viewFilter.type === "team" && viewFilter.teamId === team.id && "bg-accent"
            )}
          >
            <Avatar className="h-8 w-8 shrink-0">
              {team.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
              <AvatarFallback className="bg-primary/10 text-xs">
                <TeamIcon icon={team.icon} className="h-4 w-4" />
              </AvatarFallback>
            </Avatar>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium truncate">{team.name}</span>
                {viewFilter.type === "team" && viewFilter.teamId === team.id && (
                  <Check className="h-4 w-4 text-primary shrink-0" />
                )}
              </div>
            </div>
          </button>
        ))}

        {/* Footer */}
        <div className="mt-1 border-t pt-1">
          <Button asChild variant="ghost" size="sm" className="w-full justify-start gap-2 text-xs">
            <Link href="/dashboard/teams">{t.nav.manageTeams}</Link>
          </Button>
        </div>
      </PopoverContent>
    </Popover>
  )
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
pnpm test -- --testPathPattern=components/layout/__tests__/context-pill.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Typecheck**

```bash
pnpm typecheck
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add components/layout/context-pill.tsx components/layout/__tests__/context-pill.test.tsx
git commit -m "feat(layout): add ContextPill navbar component with Popover switcher"
```

---

### Task 7: Add ContextPill to Navbar

**Files:**

- Modify: `components/layout/navbar.tsx`

- [ ] **Step 1: Import and render ContextPill**

In `components/layout/navbar.tsx`:

1. Add import:

```tsx
import { ContextPill } from "@/components/layout/context-pill"
```

2. Update the right-side slot:

```tsx
<div className="ml-auto flex items-center gap-1 sm:gap-2">
  <ContextPill />
  <UserProfileMenu />
</div>
```

- [ ] **Step 2: Typecheck and lint**

```bash
pnpm typecheck && pnpm lint
```

Expected: no errors or warnings.

- [ ] **Step 3: Commit**

```bash
git add components/layout/navbar.tsx
git commit -m "feat(layout): add ContextPill to navbar between nav links and user avatar"
```

---

### Task 8: Remove ContextSwitcher from UserProfileMenu

**Files:**

- Modify: `components/layout/user-profile-menu.tsx`
- Delete: `components/layout/context-switcher.tsx`

The avatar now always shows the user's own avatar (team context is shown via ContextPill).

- [ ] **Step 1: Write a test confirming ContextSwitcher is gone and avatar is personal**

Create `components/layout/__tests__/user-profile-menu.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react"
import { UserProfileMenu } from "../user-profile-menu"

jest.mock("@/features/auth", () => ({
  useUser: jest
    .fn()
    .mockReturnValue({ data: { displayName: "Jane", avatarUrl: null, email: "jane@test.com" } })
}))
jest.mock("@/hooks/use-translation", () => ({
  useTranslation: jest.fn().mockReturnValue({ t: { common: { userMenu: "User menu" } } })
}))
jest.mock("@/components/layout/user-profile-header", () => ({
  UserProfileHeader: () => <div data-testid="profile-header" />
}))
jest.mock("@/components/layout/profile-menu-actions", () => ({
  ProfileMenuActions: () => <div data-testid="profile-actions" />
}))
jest.mock("@/lib/ui/stable-overlay-ids", () => ({
  createOverlayIds: () => ({ triggerId: "trigger", contentId: "content" })
}))

it("does not render a ContextSwitcher", () => {
  render(<UserProfileMenu />)
  expect(screen.queryByText("Filter view")).not.toBeInTheDocument()
})
```

- [ ] **Step 2: Run test — expect FAIL (ContextSwitcher still present)**

```bash
pnpm test -- --testPathPattern=components/layout/__tests__/user-profile-menu.test.tsx
```

Expected: FAIL — "Filter view" text found.

- [ ] **Step 3: Simplify UserProfileMenu**

Replace the contents of `components/layout/user-profile-menu.tsx` with:

```tsx
"use client"

import { Button } from "@/components/ui/button"
import { useTranslation } from "@/hooks/use-translation"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import { CircleUserRound } from "lucide-react"
import { useUser } from "@/features/auth"
import { UserProfileHeader } from "@/components/layout/user-profile-header"
import { ProfileMenuActions } from "@/components/layout/profile-menu-actions"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"

export function UserProfileMenu() {
  const { t } = useTranslation()
  const { data: user } = useUser()
  const menuIds = createOverlayIds("user-profile-menu")

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          variant="ghost"
          className="relative h-9 w-9 rounded-full select-none"
          id={menuIds.triggerId}
          aria-controls={menuIds.contentId}
          aria-label={t.common.userMenu}
        >
          <Avatar className="h-9 w-9 ring-2 ring-background transition-shadow">
            <AvatarImage src={user?.avatarUrl} alt={user?.displayName || "You"} />
            <AvatarFallback className="bg-primary/10">
              <CircleUserRound className="h-5 w-5 text-muted-foreground" />
            </AvatarFallback>
          </Avatar>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        align="end"
        className="w-72"
        id={menuIds.contentId}
        aria-labelledby={menuIds.triggerId}
      >
        <UserProfileHeader />
        <ProfileMenuActions />
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
pnpm test -- --testPathPattern=components/layout/__tests__/user-profile-menu.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Delete context-switcher.tsx**

```bash
git rm components/layout/context-switcher.tsx
```

- [ ] **Step 6: Typecheck and lint**

```bash
pnpm typecheck && pnpm lint
```

Expected: no errors or warnings. (If any imports of `ContextSwitcher` remain elsewhere, remove them.)

- [ ] **Step 7: Run all tests**

```bash
pnpm test
```

Expected: all passing.

- [ ] **Step 8: Commit**

```bash
git add components/layout/user-profile-menu.tsx components/layout/__tests__/user-profile-menu.test.tsx
git commit -m "feat(layout): remove ContextSwitcher from user profile menu — replaced by ContextPill"
```

---

### Task 9: Update MobileNavDrawer — Dashboard link + inline context section

**Files:**

- Modify: `components/layout/mobile-nav-drawer.tsx`

Two additions: a Dashboard entry at the top of the nav list, and an inline context section above the nav items. The context section must NOT use a nested Popover (causes Vaul pointer-event conflicts). Use plain `<button>` elements with `data-vaul-no-drag`.

- [ ] **Step 1: Update MobileNavDrawer**

Replace `components/layout/mobile-nav-drawer.tsx` with:

```tsx
"use client"

import { Button } from "@/components/ui/button"
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger
} from "@/components/ui/drawer"
import { OptimizedLogo } from "@/components/optimized-logo"
import {
  Menu,
  Check,
  CircleUserRound,
  Layers,
  LayoutDashboard,
  Music,
  ListMusic,
  Users
} from "lucide-react"
import { NavLinks } from "@/components/layout/nav-links"
import { useLocale } from "@/features/settings"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import { useViewFilter, useAppContext } from "@/features/app-context"
import { useUser } from "@/features/auth"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { TeamIcon } from "@/components/ui/icon-picker"
import { cn } from "@/lib/utils"
import type { ViewFilter } from "@/features/app-context"

interface MobileNavDrawerProps {
  isOpen: boolean
  onOpenChange: (open: boolean) => void
}

export function MobileNavDrawer({ isOpen, onOpenChange }: MobileNavDrawerProps) {
  const { t } = useLocale()
  const drawerIds = createOverlayIds("mobile-nav-drawer")
  const { viewFilter, setViewFilter } = useViewFilter()
  const { teams } = useAppContext()
  const { data: user } = useUser()

  const navItems = [
    { title: t.nav.dashboard, href: "/dashboard", icon: LayoutDashboard },
    { title: t.nav.songs, href: "/dashboard/songs", icon: Music },
    { title: t.nav.playlists, href: "/dashboard/playlists", icon: ListMusic },
    { title: t.nav.teams, href: "/dashboard/teams", icon: Users }
  ]

  function handleSelect(filter: ViewFilter) {
    setViewFilter(filter)
    onOpenChange(false)
  }

  const hasTeams = teams.length > 0
  const userName = user?.displayName || user?.email || "You"

  return (
    <Drawer open={isOpen} onOpenChange={onOpenChange} direction="left">
      <DrawerTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="mr-2 md:hidden"
          id={drawerIds.triggerId}
          aria-controls={drawerIds.contentId}
        >
          <Menu className="h-5 w-5" />
          <span className="sr-only">{t.common.toggleMenu}</span>
        </Button>
      </DrawerTrigger>
      <DrawerContent className="w-64" id={drawerIds.contentId}>
        <DrawerHeader>
          <DrawerTitle className="flex items-center gap-2">
            <OptimizedLogo
              name="capo-text"
              alt={t.common.capoLogo}
              width={80}
              height={27}
              className="dark:invert"
            />
          </DrawerTitle>
        </DrawerHeader>

        {/* Inline context section — no Popover inside Drawer */}
        <div className="px-3 pb-2" data-vaul-no-drag>
          <p className="px-1 py-1 text-xs font-semibold text-muted-foreground">
            {t.nav.filterContext}
          </p>

          {hasTeams && (
            <button
              onClick={() => handleSelect({ type: "all" })}
              className={cn(
                "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left transition-colors hover:bg-accent",
                viewFilter.type === "all" && "bg-accent"
              )}
            >
              <Layers className="h-4 w-4 shrink-0 text-muted-foreground" />
              <span className="flex-1 text-sm">{t.nav.viewAll}</span>
              {viewFilter.type === "all" && <Check className="h-3.5 w-3.5 text-primary" />}
            </button>
          )}

          <button
            onClick={() => handleSelect({ type: "personal" })}
            className={cn(
              "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left transition-colors hover:bg-accent",
              viewFilter.type === "personal" && "bg-accent"
            )}
          >
            <Avatar className="h-5 w-5 shrink-0">
              {user?.avatarUrl && <AvatarImage src={user.avatarUrl} alt={userName} />}
              <AvatarFallback className="bg-primary/10">
                <CircleUserRound className="h-3 w-3 text-muted-foreground" />
              </AvatarFallback>
            </Avatar>
            <span className="flex-1 truncate text-sm">{userName}</span>
            {viewFilter.type === "personal" && <Check className="h-3.5 w-3.5 text-primary" />}
          </button>

          {teams.map((team) => (
            <button
              key={team.id}
              onClick={() => handleSelect({ type: "team", teamId: team.id })}
              className={cn(
                "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left transition-colors hover:bg-accent",
                viewFilter.type === "team" && viewFilter.teamId === team.id && "bg-accent"
              )}
            >
              <Avatar className="h-5 w-5 shrink-0">
                {team.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
                <AvatarFallback className="bg-primary/10 text-[9px]">
                  <TeamIcon icon={team.icon} className="h-3 w-3" />
                </AvatarFallback>
              </Avatar>
              <span className="flex-1 truncate text-sm">{team.name}</span>
              {viewFilter.type === "team" && viewFilter.teamId === team.id && (
                <Check className="h-3.5 w-3.5 text-primary" />
              )}
            </button>
          ))}
        </div>

        <div className="border-t" />

        <nav className="mt-2 flex flex-col gap-2 px-3" data-vaul-no-drag>
          <NavLinks items={navItems} variant="vertical" onItemClick={() => onOpenChange(false)} />
        </nav>
      </DrawerContent>
    </Drawer>
  )
}
```

- [ ] **Step 2: Typecheck and lint**

```bash
pnpm typecheck && pnpm lint
```

Expected: no errors or warnings.

- [ ] **Step 3: Run tests**

```bash
pnpm test
```

Expected: all passing.

- [ ] **Step 4: Commit**

```bash
git add components/layout/mobile-nav-drawer.tsx
git commit -m "feat(layout): add Dashboard nav item and inline context switcher to mobile drawer"
```

---

## Chunk 3: Ownership chips on list items

### Task 10: Enhance SongItem ownership chip with color dot, remove left border

**Files:**

- Modify: `features/songs/components/song-item/song-item.tsx`

- [ ] **Step 1: Write a test for the new chip**

Open `features/songs/__tests__/components/song-item.test.tsx` (or create it):

```tsx
import { render, screen } from "@testing-library/react"
import { SongItem } from "@/features/songs/components/song-item/song-item"

// ownership must be set so ownershipLabel is computed as non-null inside SongItem
const mockSong = {
  id: "1",
  title: "Amazing Grace",
  artist: "John Newton",
  key: "G",
  bpm: 80,
  ownership: { type: "team" as const, teamId: "t1", teamName: "Worship", teamIcon: null }
}

it("renders a colored chip with dot when bucketColor and ownershipLabel are provided", () => {
  const { container } = render(
    <SongItem
      song={mockSong}
      isSelected={false}
      isInCart={false}
      bucketColor="#6366f1"
      onSelect={jest.fn()}
      onToggleCart={jest.fn()}
    />
  )
  // Chip dot should be present
  const dot = container.querySelector("[data-testid='ownership-dot']")
  expect(dot).toBeInTheDocument()
})

it("renders no left border style when bucketColor is provided", () => {
  const { container } = render(
    <SongItem
      song={mockSong}
      isSelected={false}
      isInCart={false}
      bucketColor="#6366f1"
      onSelect={jest.fn()}
      onToggleCart={jest.fn()}
    />
  )
  const outerDiv = container.firstChild as HTMLElement
  expect(outerDiv?.style.borderLeftColor).toBe("")
})
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
pnpm test -- --testPathPattern=features/songs/__tests__/components/song-item.test.tsx
```

Expected: FAIL — left border present, dot not found.

- [ ] **Step 3: Update song-item.tsx**

In `features/songs/components/song-item/song-item.tsx`:

1. **Remove** the `style` prop on the outer `<div>` (lines 40–44):

```tsx
// Before:
style={
  bucketColor
    ? { borderLeftColor: bucketColor, borderLeftWidth: "3px", borderLeftStyle: "solid" }
    : undefined
}
// After: remove entirely — no style prop
```

2. **Replace** the existing ownership chip span (lines 84–94):

```tsx
{
  ownershipLabel && bucketColor && (
    <span
      className="shrink-0 inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-medium"
      style={{
        color: bucketColor,
        background: `color-mix(in oklch, ${bucketColor} 15%, transparent)`
      }}
    >
      <span
        data-testid="ownership-dot"
        className="h-1.5 w-1.5 rounded-sm shrink-0"
        style={{ background: bucketColor }}
      />
      {ownershipLabel}
    </span>
  )
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
pnpm test -- --testPathPattern=features/songs/__tests__/components/song-item.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add features/songs/components/song-item/song-item.tsx features/songs/__tests__/components/song-item.test.tsx
git commit -m "feat(songs): replace left border ownership indicator with colored chip + dot"
```

---

### Task 11: Add team ownership chip to PlaylistItem and PlaylistList

**Files:**

- Modify: `features/playlists/components/playlist-item/playlist-item.tsx`
- Modify: `features/playlists/components/playlist-list/playlist-list.tsx`

`PlaylistList` derives ownership by looking up `playlist.teamId` in `teams` from `useAppContext()`, builds a synthetic `SongOwnership` object, calls the existing `getBucketColor`, and passes the result as props to `PlaylistItem`.

- [ ] **Step 1: Write a failing test for PlaylistItem chip**

Create `features/playlists/__tests__/components/playlist-item.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react"
import { PlaylistItem } from "@/features/playlists/components/playlist-item/playlist-item"

const mockPlaylist = {
  id: "p1",
  name: "Sunday Set",
  songs: [],
  createdAt: "",
  updatedAt: ""
}

it("renders ownership chip when bucketColor and ownershipLabel are provided", () => {
  const { container } = render(
    <PlaylistItem
      playlist={mockPlaylist}
      isSelected={false}
      bucketColor="#6366f1"
      ownershipLabel="Worship"
      onSelect={jest.fn()}
    />
  )
  expect(screen.getByText("Worship")).toBeInTheDocument()
  const dot = container.querySelector("[data-testid='ownership-dot']")
  expect(dot).toBeInTheDocument()
})

it("renders no chip when bucketColor is not provided", () => {
  render(<PlaylistItem playlist={mockPlaylist} isSelected={false} onSelect={jest.fn()} />)
  expect(screen.queryByTestId("ownership-dot")).not.toBeInTheDocument()
})
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
pnpm test -- --testPathPattern=features/playlists/__tests__/components/playlist-item.test.tsx
```

Expected: FAIL — `bucketColor` prop not accepted.

- [ ] **Step 3: Update PlaylistItem to accept and render chip**

In `features/playlists/components/playlist-item/playlist-item.tsx`:

1. Add props to the interface:

```tsx
interface PlaylistItemProps {
  playlist: Playlist
  isSelected: boolean
  onSelect: (playlist: Playlist) => void
  ownershipLabel?: string
  bucketColor?: string
}
```

2. Accept them in the function signature:

```tsx
export const PlaylistItem = memo(function PlaylistItem({
  playlist,
  isSelected,
  onSelect,
  ownershipLabel,
  bucketColor
}: PlaylistItemProps) {
```

3. Add the chip inside the `flex items-center gap-3 mt-1` row (line 85), after the date/songs metadata:

```tsx
{
  ownershipLabel && bucketColor && (
    <span
      className="shrink-0 inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-medium"
      style={{
        color: bucketColor,
        background: `color-mix(in oklch, ${bucketColor} 15%, transparent)`
      }}
    >
      <span
        data-testid="ownership-dot"
        className="h-1.5 w-1.5 rounded-sm shrink-0"
        style={{ background: bucketColor }}
      />
      {ownershipLabel}
    </span>
  )
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
pnpm test -- --testPathPattern=features/playlists/__tests__/components/playlist-item.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Export getBucketColor from the songs public API**

`getBucketColor` is currently only exported from `features/songs/utils` (internal). Per FBA rules, cross-feature imports must go through the public API. Add it to `features/songs/index.ts`:

```ts
export { getBucketColor } from "./utils"
```

- [ ] **Step 6: Update PlaylistList to derive and pass ownership props**

In `features/playlists/components/playlist-list/playlist-list.tsx`:

1. Add imports:

```tsx
import { useAppContext, useViewFilter } from "@/features/app-context"
import { getBucketColor } from "@/features/songs"
import type { SongOwnership } from "@/features/songs"
```

2. Inside `PlaylistList`, read context:

```tsx
const { teams } = useAppContext()
const { viewFilter } = useViewFilter()
const showBucketColors = viewFilter.type === "all"
```

3. Update the `PlaylistItem` render to pass ownership props:

```tsx
{
  filteredPlaylists.map((playlist) => {
    let ownershipLabel: string | undefined
    let bucketColor: string | undefined

    if (showBucketColors && playlist.teamId) {
      const team = teams.find((t) => t.id === playlist.teamId)
      if (team) {
        const ownership: SongOwnership = {
          type: "team",
          teamId: team.id,
          teamName: team.name,
          teamIcon: team.icon ?? null
        }
        ownershipLabel = team.name
        bucketColor = getBucketColor(ownership, teams)
      }
    }

    return (
      <PlaylistItem
        key={playlist.id}
        playlist={playlist}
        isSelected={selectedPlaylistId === playlist.id}
        ownershipLabel={ownershipLabel}
        bucketColor={bucketColor}
        onSelect={onSelectPlaylist}
      />
    )
  })
}
```

- [ ] **Step 7: Update existing playlist-list test to mock the new hooks**

`PlaylistList` now calls `useAppContext()` and `useViewFilter()`. The existing test file at `features/playlists/components/playlist-list/__tests__/playlist-list.test.tsx` (or equivalent path) does not provide these context providers. Add mocks at the top of that file:

```tsx
jest.mock("@/features/app-context", () => ({
  useAppContext: () => ({ teams: [] }),
  useViewFilter: () => ({ viewFilter: { type: "all" } })
}))
```

- [ ] **Step 7: Run all tests**

```bash
pnpm test
```

Expected: all passing.

- [ ] **Step 8: Typecheck and lint**

```bash
pnpm typecheck && pnpm lint
```

Expected: no errors or warnings.

- [ ] **Step 9: Commit**

```bash
git add features/playlists/components/playlist-item/playlist-item.tsx \
        features/playlists/components/playlist-list/playlist-list.tsx \
        features/playlists/__tests__/components/playlist-item.test.tsx
git commit -m "feat(playlists): add team ownership chip to playlist items in All view"
```

---

### Task 12: Final verification and coverage check

- [ ] **Step 1: Run full test suite with coverage**

```bash
pnpm test:coverage
```

Expected: branches/functions/lines/statements all ≥ 80%.

- [ ] **Step 2: Validate i18n**

```bash
pnpm i18n:validate
```

Expected: no missing keys. (All translation keys used in `ContextPill` and the drawer section already exist under `t.nav.*` from the old `ContextSwitcher`.)

- [ ] **Step 3: Check for Dashboard i18n key**

The Dashboard nav item title is hardcoded as `"Dashboard"` in the plan. If the app has an i18n key for it, use it. Check:

```bash
grep -r "dashboard" lib/i18n/locales/en.json | head -5
```

If a key like `t.nav.dashboard` exists, use it in `MobileNavDrawer`. If not, the hardcoded string is fine for now.

- [ ] **Step 4: Manual smoke test checklist**

Start the dev server (`pnpm dev`) and verify:

- [ ] Navbar shows the ContextPill between nav links and user avatar
- [ ] Clicking the pill opens a dropdown with All / Personal / teams
- [ ] Selecting a team → pill shows team name with accent styling
- [ ] Reload → pill still shows that team (cookie persisted)
- [ ] Selecting Personal → pill shows user name, reload persists
- [ ] Selecting All → pill shows stacked avatars + "All", reload persists
- [ ] In All view, team songs show the colored chip with dot; personal songs do not
- [ ] In All view, team playlists show the colored chip; personal playlists do not
- [ ] In filtered (Personal or Team) view, no chips visible on items
- [ ] User avatar in profile menu dropdown always shows personal avatar
- [ ] Profile dropdown no longer contains context switching options
- [ ] Mobile: hamburger drawer shows Dashboard link + inline context section
- [ ] Mobile: selecting a context in the drawer closes the drawer

- [ ] **Step 5: Final commit (if any cleanup needed)**

```bash
git add -p  # review any remaining changes
git commit -m "chore: final cleanup for team context UX feature"
```
