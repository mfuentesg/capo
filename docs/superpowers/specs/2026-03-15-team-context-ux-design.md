# Team Context UX — Design Spec

**Date:** 2026-03-15

---

## Context

The current team context switcher is hidden inside the user profile dropdown, making it hard to discover and use. When a user picks a team or personal view, that choice is lost on page reload because `ViewFilter` is only held in React state and never persisted. Additionally, song/playlist items in the "All" view show team ownership with a faint colored left border and short text label, which is too subtle to be useful at a glance.

**Goals:**
- Surface the context switcher prominently in the navbar as a persistent pill
- Persist the `ViewFilter` selection across reloads via cookie
- Replace the weak ownership indicator with a clearer inline team chip on list items
- Add a Dashboard entry to the mobile nav drawer

---

## Design Decisions

1. **Context pill in navbar** (between nav links and user avatar) — visible on both desktop and mobile
2. **"All" remains the default** — users see everything by default and filter when they want
3. **Team chip on items** — inline chip below artist name in "All" view; hidden when filtered to a specific context
4. **Context switcher removed from user profile menu** — fully replaced by the pill
5. **Dashboard added to mobile nav drawer** with a `LayoutDashboard` icon

---

## Persistence Fix

**Root cause:** `viewFilter` in `AppContextProvider` initializes to `{ type: "all" }` on every load (line 86 of `context.tsx`) and `setViewFilter` calls `setContextState` directly, bypassing the cookie sync.

**Fix:** Add a new cookie `capo_view_filter` storing `"all" | "personal" | "team"`. When type is `"team"`, the existing `capo_selected_team_id` cookie already holds the team ID.

Changes:
- `features/app-context/constants.ts` — add `VIEW_FILTER_KEY = "capo_view_filter"`
- `features/app-context/server.ts` — add `export async function setViewFilterCookie(type: "all" | "personal" | "team")` as a server action (same pattern as the existing `setSelectedTeamId`/`unsetSelectedTeamId` — callable from client components via the `"use server"` file directive). Add `getViewFilterCookie()` as an **unexported** internal async helper — it is only called server-side within `getInitialAppContextData`. Update `getInitialAppContextData` to call `getViewFilterCookie()` and return `initialViewFilter: ViewFilter`.
- `features/app-context/context.tsx` — accept `initialViewFilter` prop; initialize `viewFilter` state from it; call `setViewFilterCookie` inside `setViewFilter` callback (after updating local state). **Do not** call `router.refresh()`.
- `app/(app)/layout.tsx` — pass `initialViewFilter` from `getInitialAppContextData` to `AppContextProvider`

**AppContext / ViewFilter decoupling on restore:** `AppContext` (the creation bucket) and `ViewFilter` (the display filter) are intentionally decoupled. On initial mount when `initialViewFilter.type === "all"`, `AppContext` is initialized from `initialSelectedTeamId` as before — no changes to that logic. The "All" view filter does not drive `setContextState`. This matches the existing design where `setViewFilter({ type: "all" })` leaves `contextState` untouched.

**Stale team ID fallback:** In `getInitialAppContextData`, after reading both `capo_view_filter` and `capo_selected_team_id`, validate the stored team ID against the user's team list. If `capo_view_filter === "team"` but the team ID is not in `teams`, fall back to `initialViewFilter: { type: "all" }` and delete the stale `capo_view_filter` cookie. This reuses the same teams validation already done for `initialSelectedTeamId`.

**`setViewFilter` side-effects and cookie sync:** The current `setViewFilter` calls `setContextState` directly (not `setContext`) to avoid `router.refresh()`. That behavior is unchanged. Additionally — **this is new** — to keep `capo_selected_team_id` in sync with `capo_view_filter`:
- When filter is `{ type: "team", teamId }`: also fire-and-forget `setClientSelectedTeamId(teamId)` — this keeps the creation-bucket cookie aligned with the view filter
- When filter is `{ type: "personal" }`: also fire-and-forget `unsetClientSelectedTeamId()`
- When filter is `{ type: "all" }`: do NOT change `capo_selected_team_id` — the creation context on "All" view stays as the last explicitly selected team/personal

This means on reload after switching to a team via the new pill, both `capo_view_filter = "team"` and `capo_selected_team_id = teamId` are set, so both `AppContext` and `ViewFilter` restore correctly. No `router.refresh()` needed.

---

## New Component: `ContextPill`

**File:** `components/layout/context-pill.tsx`

A `Popover`-based navbar button that shows the current `ViewFilter` and lets the user switch.

**Pill appearance by state:**

| ViewFilter | Pill content |
|---|---|
| `all` | Stacked user + team avatars (up to 2) · "All" label |
| `personal` | User avatar · display name (truncated) |
| `team` | Team icon/avatar · team name (truncated) · accent border in team color |

On mobile: compact — icon(s) + label truncated to fit navbar. The pill uses `bg-accent/50` background when in a specific context (not "all").

**Popover dropdown content** — same options as current `ContextSwitcher`:
- "All" (only shown if user has teams)
- Personal (user avatar + display name)
- Per-team row (team icon + name + member count)
- Divider → "Manage Teams" link

The popover uses `align="end"` and `w-64`.

**No `DropdownMenuItem`** — this component uses `Popover`/`PopoverContent` since it lives outside any `DropdownMenu`.

---

## Navbar Changes

**File:** `components/layout/navbar.tsx`

Add `<ContextPill />` between `<NavLinks>` and `<UserProfileMenu>` in the right-side slot:

```tsx
<div className="ml-auto flex items-center gap-1 sm:gap-2">
  <ContextPill />        {/* NEW */}
  <UserProfileMenu />
</div>
```

---

## UserProfileMenu Changes

**File:** `components/layout/user-profile-menu.tsx`

- Remove `<ContextSwitcher teams={teams} />` from dropdown content
- Remove the `context`/`teams`/`currentTeam` logic used to decide which avatar to show — avatar always shows the user's own avatar now
- Remove the `ContextSwitcher` import

---

## MobileNavDrawer Changes

**File:** `components/layout/mobile-nav-drawer.tsx`

Two additions:

1. **Dashboard nav item** — add `{ title: "Dashboard", href: "/dashboard", icon: LayoutDashboard }` at the start of `navItems`

2. **Inline context section** — above the nav items, render the context switcher as a **flat inline list** (no nested Popover — a Popover-inside-Drawer causes Vaul pointer-event conflicts on mobile). Structure:
   ```
   VIEWING
   ○ All              ✓
   ○ Personal
   ● Worship Team
   ```
   Use `useViewFilter()` and `useAppContext()` directly. Each row is a plain `<button>` that calls `setViewFilter(...)` and then `onOpenChange(false)` to close the drawer. The entire context section must have `data-vaul-no-drag` to avoid Vaul swipe detection conflicts.

   If the list grows long enough to scroll, wrap it in `<DrawerScrollArea>` per the CLAUDE.md rule.

---

## Song Item Changes

**File:** `features/songs/components/song-item/song-item.tsx`

Two changes: remove the left border (lines 40–44 of the outer div's `style` prop), and enhance the existing ownership chip span (lines 84–94) to include a color dot:

**Remove:**
- `style={{ borderLeftColor, borderLeftWidth, borderLeftStyle }}` on the outer div
- The `ownershipLabel && bucketColor` span with the color-mixed background

**Add (when `ownershipLabel` and `bucketColor` are present):**
```tsx
<span className="shrink-0 inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-medium"
  style={{
    color: bucketColor,
    background: `color-mix(in oklch, ${bucketColor} 15%, transparent)`
  }}
>
  <span className="h-1.5 w-1.5 rounded-sm shrink-0" style={{ background: bucketColor }} />
  {ownershipLabel}
</span>
```

The chip sits in the same `flex items-center gap-1.5` row as the artist name (no layout change needed).

**Caller responsibility:** `ownershipLabel` / `bucketColor` props are only passed when `viewFilter.type === "all"` — no chip renders in filtered views. This is already how the callers work; no change needed there.

---

## Playlist Item Changes

**File:** `features/playlists/components/playlist-item/playlist-item.tsx`

Playlists currently have no team ownership display. Add the same chip pattern:
- Add `ownershipLabel?: string` and `bucketColor?: string` props
- Render the chip in the same position as on song items (next to the description/artist row)

**File:** `features/playlists/components/playlist-list/playlist-list.tsx`

The `Playlist` type has `teamId?: string | null` (camelCase) but no `ownership` discriminant like `Song` has. Derive ownership inline here:
- `PlaylistList` can read `teams` from `useAppContext().teams`
- For each playlist: find the matching team from `teams.find(t => t.id === playlist.teamId)`
- If found, derive a synthetic `SongOwnership` — `{ type: "team", teamId: team.id, teamName: team.name, teamIcon: team.icon ?? null }` — and pass to `getBucketColor(syntheticOwnership, teams)` from `features/songs/utils/bucket-colors.ts`
- `ownershipLabel` = `team.name` (truncated in the chip if needed)
- If `playlist.teamId` is null/undefined, no chip is rendered (personal)
- Only compute and pass props when `viewFilter.type === "all"`

---

## Files to Modify

| File | Change |
|---|---|
| `features/app-context/constants.ts` | Add `VIEW_FILTER_KEY` |
| `features/app-context/server.ts` | Add `setViewFilterCookie`, `getViewFilterCookie`; update `getInitialAppContextData` |
| `features/app-context/context.tsx` | Accept + use `initialViewFilter`; persist on `setViewFilter` |
| `app/(app)/layout.tsx` | Pass `initialViewFilter` to `AppContextProvider` |
| `components/layout/navbar.tsx` | Add `<ContextPill />` |
| `components/layout/context-pill.tsx` | **New component** |
| `components/layout/user-profile-menu.tsx` | Remove `ContextSwitcher`, simplify avatar |
| `components/layout/mobile-nav-drawer.tsx` | Add Dashboard item + context card |
| `features/songs/components/song-item/song-item.tsx` | Replace left border with chip |
| `features/playlists/components/playlist-item/playlist-item.tsx` | Add chip support |
| `features/playlists/components/playlist-list/playlist-list.tsx` | Pass bucket props to item |

---

## What Does NOT Change

- `ViewFilter` type definition — no changes to `types.ts`
- `useViewFilter` hook — no changes
- `applyContextFilter` — no changes
- Song/playlist data fetching — no changes

## Cleanup

- Delete `components/layout/context-switcher.tsx` — it is only used in `UserProfileMenu` and is fully replaced by `ContextPill`

## i18n

Reuse existing translation keys from `ContextSwitcher` where applicable: `t.nav.filterContext`, `t.nav.viewAll`, `t.nav.viewAllDescription`, `t.nav.personalAccount`. Any new copy in the pill or drawer context section must be added to all locale files under `lib/i18n/` and verified with `pnpm i18n:validate`.

---

## Verification

1. **Persistence**: Switch to a team, reload — pill still shows that team. Switch to Personal, reload — pill shows Personal. Switch to All, reload — pill shows All.
2. **All view**: Songs/playlists from a team show the chip; personal ones do not.
3. **Filtered view**: No chips visible; pill shows the active context with accent styling.
4. **Mobile**: Navbar pill is visible and tappable. Drawer shows Dashboard link and context card.
5. **User menu**: Context section is gone from the profile dropdown.
6. **Tests**: Run `pnpm test` — existing context and song/playlist tests should pass. Update snapshots if any.
