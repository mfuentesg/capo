# Teams UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the teams list and team detail pages with color-accent cards and a hero-banner detail header — no logic changes.

**Architecture:** Pure UI changes across 4 existing component files. No new files, no new queries, no new tests. Each task modifies one file, verifies with lint + typecheck, then commits.

**Tech Stack:** Next.js App Router, React, Tailwind CSS, shadcn/ui components (`Card`, `Badge`, `Avatar`, `Button`), lucide-react icons.

**Spec:** `docs/specs/2026-03-16-teams-ui-redesign.md`

---

## Chunk 1: Team Card Redesign

### Task 1: Redesign `team-card.tsx`

**Files:**
- Modify: `features/teams/components/team-card.tsx`

**Context:** The current card has a flat `<CardHeader>` (icon + name + Active/Switch badge) and a single `<CardContent>` row (role badge, member count, Public badge, action buttons). We restructure to:
- Add a role-colored 4px accent bar at the very top of the card
- Move role + public badges into `<CardHeader>` below the team name
- Clean up `<CardContent>` to show only member count stat + action buttons

**Role → accent bar gradient / icon container colors:**
- `owner` → bar: `from-blue-400 to-purple-400`, icon: `bg-blue-500/10 border-blue-500/20`
- `admin` → bar: `from-green-400 to-teal-400`, icon: `bg-green-500/10 border-green-500/20`
- `member` / `viewer` → bar: `from-yellow-300 to-orange-300`, icon: `bg-yellow-500/10 border-yellow-500/20`

- [ ] **Step 1: Add `cn` import**

`cn` is not currently imported in `team-card.tsx` and there is no `@/lib/utils` import at all. Add it after the last existing import group (the last `import` line in the file):

```typescript
import { cn } from "@/lib/utils"
```

- [ ] **Step 2: Add role-classes helper before the component**

Before the `export function TeamCard(...)` line, add:

```typescript
function getRoleAccentClasses(role: string | undefined) {
  switch (role) {
    case "owner":
      return { bar: "from-blue-400 to-purple-400", iconBg: "bg-blue-500/10 border-blue-500/20" }
    case "admin":
      return { bar: "from-green-400 to-teal-400", iconBg: "bg-green-500/10 border-green-500/20" }
    default:
      return { bar: "from-yellow-300 to-orange-300", iconBg: "bg-yellow-500/10 border-yellow-500/20" }
  }
}
```

- [ ] **Step 3: Wire up `roleClasses` inside the component**

At the top of the `TeamCard` function body, after the existing state/hook declarations, add:

```typescript
const roleClasses = getRoleAccentClasses(team.role)
```

- [ ] **Step 4: Replace the `<Card>` JSX block**

The return block is wrapped in an outer `<>` fragment containing: `<Card>...</Card>` followed by two `<Dialog>` blocks. **Replace only the `<Card>` through `</Card>` portion.** The outer `<>` fragment and both `<Dialog>` blocks that follow must remain completely unchanged.

Replace the card with:

```tsx
<Card
  className={cn(
    "hover:shadow-md transition-shadow overflow-hidden",
    isCurrentTeam ? "border-2 border-primary" : ""
  )}
>
  {/* Role-colored accent bar — h-1 (4px), rounded top corners only */}
  <div className={cn("h-1 rounded-t-lg bg-gradient-to-r", roleClasses.bar)} />

  <CardHeader className="pb-2">
    {/* Row 1: icon + name + Active badge */}
    <div className="flex items-start justify-between gap-2">
      <div className="flex items-center gap-3 flex-1 min-w-0">
        {isOwner ? (
          <div
            className={cn(
              "h-9 w-9 rounded-lg border flex items-center justify-center shrink-0",
              roleClasses.iconBg
            )}
          >
            <IconPicker
              value={editingIcon}
              onChange={handleIconChange}
              iconClassName="h-5 w-5"
              idBase={`team-card-${team.id}-icon-picker`}
            />
          </div>
        ) : (
          <Avatar className={cn("h-9 w-9 rounded-lg border", roleClasses.iconBg)}>
            {team.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
            <AvatarFallback className="rounded-lg bg-transparent">
              <TeamIcon icon={editingIcon} className="h-5 w-5" />
            </AvatarFallback>
          </Avatar>
        )}
        <div className="flex-1 min-w-0">
          <Link href={`/dashboard/teams/${team.id}`}>
            <CardTitle className="text-base truncate hover:underline cursor-pointer">
              {team.name}
            </CardTitle>
          </Link>
        </div>
      </div>
      {isCurrentTeam && (
        <Badge variant="default" className="shrink-0">
          Active
        </Badge>
      )}
    </div>

    {/* Row 2: role badge + public badge */}
    <div className="flex items-center gap-2 mt-1">
      {team.role && <RoleBadge role={team.role} className="text-[10px]" />}
      {team.is_public && (
        <Badge variant="secondary" className="text-xs">
          Public
        </Badge>
      )}
    </div>
  </CardHeader>

  <CardContent className="pt-0">
    <div className="border-t border-border my-2" />
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-1 text-sm text-muted-foreground">
        <UsersIcon className="h-4 w-4" />
        <span>
          {memberCount} {t.teams.members}
        </span>
      </div>
      <div className="flex items-center gap-1">
        {!isCurrentTeam && (
          <Button
            variant="outline"
            size="sm"
            onClick={() => switchToTeam(team.id)}
            aria-label={`${t.teams.switchToTeam}: ${team.name}`}
          >
            <ArrowLeftRight className="h-3.5 w-3.5 mr-1" />
            {t.teams.switchToTeam}
          </Button>
        )}
        <Button
          variant="ghost"
          size="sm"
          onClick={handleLeaveOrDelete}
          className="text-destructive hover:text-destructive hover:bg-destructive/10"
          title={isOwner && isOnlyMember ? t.teams.deleteTeam : t.teams.leaveTeam}
        >
          {isOwner && isOnlyMember ? (
            <Trash2 className="h-4 w-4" />
          ) : (
            <LogOut className="h-4 w-4" />
          )}
        </Button>
        <Button
          variant="ghost"
          size="sm"
          asChild
          title={`${t.teams.manageTeam}: ${team.name}`}
        >
          <Link
            href={`/dashboard/teams/${team.id}`}
            aria-label={`${t.teams.manageTeam}: ${team.name}`}
          >
            <Wrench className="h-4 w-4" />
          </Link>
        </Button>
      </div>
    </div>
  </CardContent>
</Card>
```

- [ ] **Step 5: Run typecheck and lint**

```bash
cd /Users/mfuentesg/code/capo && pnpm typecheck && pnpm lint
```

Expected: no errors, no warnings.

- [ ] **Step 6: Commit**

```bash
git add features/teams/components/team-card.tsx
git commit -m "feat(teams): redesign team card with role-accent bar and labeled Switch button"
```

---

## Chunk 2: Team Detail Header Redesign

### Task 2: Redesign `team-detail-header.tsx`

**Files:**
- Modify: `features/teams/components/team-detail-header.tsx`

**Context:** The current header is a flat horizontal `flex` row: back button → icon → name/date → badges/switch. Replace with: back button (normal flow) → hero gradient banner with floating icon → info block (name, date, badges) → stats strip (members count, pending invites count).

**New optional props (all default to 0 / undefined — existing call sites and tests need no changes):**
- `memberCount?: number` — displayed in stats strip
- `pendingInviteCount?: number` — displayed in stats strip
- `currentUserRole?: Tables<"team_members">["role"]` — used for `RoleBadge` in info block

**New import needed:** `RoleBadge` from `"./role-badge"` — it is NOT in the public API, use the relative path (same pattern as `team-members-section.tsx`).

- [ ] **Step 1: Add `RoleBadge` import**

At the top of `team-detail-header.tsx`, add:

```typescript
import { RoleBadge } from "./role-badge"
```

- [ ] **Step 2: Update the `TeamDetailHeaderProps` interface**

Find the existing interface and replace it with:

```typescript
interface TeamDetailHeaderProps {
  team: Tables<"teams">
  onUpdate?: (updates: TablesUpdate<"teams">) => void
  isOwner?: boolean
  memberCount?: number
  pendingInviteCount?: number
  currentUserRole?: Tables<"team_members">["role"]
}
```

- [ ] **Step 3: Update the function signature to destructure new props**

```typescript
export function TeamDetailHeader({
  team,
  onUpdate,
  isOwner,
  memberCount = 0,
  pendingInviteCount = 0,
  currentUserRole
}: TeamDetailHeaderProps) {
```

- [ ] **Step 4: Replace the `return (...)` block**

Replace the entire return block with:

```tsx
return (
  <div className="space-y-0">
    {/* Back button */}
    <Button
      variant="ghost"
      size="icon"
      asChild
      aria-label={t.invitations.backToTeams}
      className="mb-2"
    >
      <Link href="/dashboard/teams">
        <ArrowLeft className="h-4 w-4" />
      </Link>
    </Button>

    {/* Hero banner + floating icon */}
    <div className="relative">
      <div className="h-16 rounded-t-xl bg-gradient-to-br from-primary/15 to-primary/5 border-b border-primary/20" />
      <div className="absolute bottom-[-18px] left-4 h-11 w-11 rounded-xl border-2 border-border bg-background shadow-sm flex items-center justify-center">
        {isOwner ? (
          <IconPicker
            value={editingIcon}
            onChange={handleIconChange}
            iconClassName="h-6 w-6"
            idBase={`team-detail-${team.id}-icon-picker`}
          />
        ) : (
          <Avatar className="h-11 w-11 rounded-xl">
            {team.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
            <AvatarFallback className="rounded-xl bg-primary/10">
              <TeamIcon icon={editingIcon} className="h-6 w-6" />
            </AvatarFallback>
          </Avatar>
        )}
      </div>
    </div>

    {/* Info block — mt-7 clears the 18px icon overflow */}
    <div className="mt-7 flex items-start justify-between gap-3">
      <div className="min-w-0">
        {isOwner && onUpdate ? (
          <EditableField
            value={team.name}
            onSave={(value) => onUpdate({ name: value })}
            className="max-w-full text-xl font-bold tracking-tight"
          />
        ) : (
          <h1 className="truncate text-xl font-bold tracking-tight">{team.name}</h1>
        )}
        <p className="text-xs text-muted-foreground mt-0.5">
          {t.teams.created} {formatDate(team.created_at)}
        </p>
        <div className="flex flex-wrap items-center gap-2 mt-2">
          {currentUserRole && <RoleBadge role={currentUserRole} />}
          {team.is_public && <Badge variant="secondary">{t.filters.public}</Badge>}
        </div>
      </div>
      <div className="shrink-0">
        {isCurrentTeam ? (
          <Badge variant="default" className="gap-1.5">
            <Check className="h-3 w-3" />
            {t.teams.active}
          </Badge>
        ) : (
          <Button size="sm" onClick={handleSwitchToTeam}>
            {t.teams.switchToTeam}
          </Button>
        )}
      </div>
    </div>

    {/* Stats strip */}
    <div className="mt-4 grid grid-cols-2 gap-3">
      <div className="bg-card border border-border rounded-lg p-3 flex flex-col gap-0.5">
        <span className="text-lg font-bold text-primary">{memberCount}</span>
        <span className="text-xs text-muted-foreground uppercase tracking-wide">
          {t.teams.members}
        </span>
      </div>
      <div className="bg-card border border-border rounded-lg p-3 flex flex-col gap-0.5">
        <span className="text-lg font-bold text-primary">{pendingInviteCount}</span>
        <span className="text-xs text-muted-foreground uppercase tracking-wide">
          {t.teams.pendingInvitations}
        </span>
      </div>
    </div>
  </div>
)
```

- [ ] **Step 5: Run typecheck and lint**

```bash
cd /Users/mfuentesg/code/capo && pnpm typecheck && pnpm lint
```

Expected: no errors, no warnings.

- [ ] **Step 6: Commit**

```bash
git add features/teams/components/team-detail-header.tsx
git commit -m "feat(teams): redesign detail header with hero banner and stats strip"
```

---

## Chunk 3: Wire Up Client + Members Section

### Task 3: Update `team-detail-client.tsx`

**Files:**
- Modify: `features/teams/components/team-detail-client.tsx`

**Context:** Two small changes: (1) compute `memberCount` and `pendingInviteCount` from already-fetched data and pass them to `<TeamDetailHeader>` along with `currentUserRole`. (2) Wrap `<TeamDangerZone>` in a subtle red-tinted container.

- [ ] **Step 1: Compute counts**

In `team-detail-client.tsx`, find the existing line:

```typescript
const currentUserRole = resolvedMembers.find((member) => member.user_id === user?.id)?.role
```

Immediately after it, add:

```typescript
const memberCount = resolvedMembers.length
const pendingInviteCount = resolvedInvitations.filter(
  (inv) => inv.expires_at >= new Date().toISOString()
).length
```

- [ ] **Step 2: Pass new props to `<TeamDetailHeader>`**

Find the `<TeamDetailHeader>` JSX and update it to:

```tsx
<TeamDetailHeader
  team={team}
  onUpdate={handleUpdate}
  isOwner={isOwner}
  memberCount={memberCount}
  pendingInviteCount={pendingInviteCount}
  currentUserRole={currentUserRole}
/>
```

- [ ] **Step 3: Wrap the danger zone**

Find the existing conditional block:

```tsx
{user && (
  <TeamDangerZone
    ...all existing props...
  />
)}
```

Wrap `<TeamDangerZone>` in a styled container (keep all existing props unchanged):

```tsx
{user && (
  <div className="rounded-lg border border-destructive/20 bg-destructive/5 p-1">
    <TeamDangerZone
      teamName={team.name}
      members={resolvedMembers}
      currentUserId={user.id}
      isOwner={isOwner}
      onLeave={handleLeave}
      onDelete={handleDelete}
      onTransferOwnership={handleTransferOwnership}
      onTransferAndLeave={handleTransferAndLeave}
      isDeleting={deleteTeamMutation.isPending}
      isTransferring={
        transferOwnershipMutation.isPending || transferAndLeaveMutation.isPending
      }
      isLeaving={leaveTeamMutation.isPending}
    />
  </div>
)}
```

- [ ] **Step 4: Run typecheck and lint**

```bash
cd /Users/mfuentesg/code/capo && pnpm typecheck && pnpm lint
```

Expected: no errors, no warnings.

- [ ] **Step 5: Commit**

```bash
git add features/teams/components/team-detail-client.tsx
git commit -m "feat(teams): pass counts to detail header and add danger zone container"
```

---

### Task 4: Update `team-members-section.tsx`

**Files:**
- Modify: `features/teams/components/team-members-section.tsx`

**Context:** Single-line change — add `rounded-md` to the current-user row highlight so the accent background has rounded corners.

- [ ] **Step 1: Apply the change**

Find the `<Item>` for member rows that has the `isCurrentUser` conditional className. It looks like:

```tsx
className={cn(
  "hover:bg-muted/50",
  isCurrentUser && "border-primary/40 bg-primary/5"
)}
```

Change to:

```tsx
className={cn(
  "hover:bg-muted/50",
  isCurrentUser && "border-primary/40 bg-primary/5 rounded-md"
)}
```

- [ ] **Step 2: Run typecheck and lint**

```bash
cd /Users/mfuentesg/code/capo && pnpm typecheck && pnpm lint
```

Expected: no errors, no warnings.

- [ ] **Step 3: Run existing teams tests**

```bash
cd /Users/mfuentesg/code/capo && pnpm test -- --testPathPattern=features/teams
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add features/teams/components/team-members-section.tsx
git commit -m "feat(teams): add rounded corners to current-user member row highlight"
```

---

## Final Verification

- [ ] **Run full lint + typecheck**

```bash
cd /Users/mfuentesg/code/capo && pnpm typecheck && pnpm lint
```

- [ ] **Run all teams tests**

```bash
cd /Users/mfuentesg/code/capo && pnpm test -- --testPathPattern=features/teams
```

- [ ] **Start dev server and manually verify both pages**

```bash
cd /Users/mfuentesg/code/capo && pnpm dev
```

Check:
1. `/dashboard/teams` — cards show 4px colored accent bars (blue/owner, green/admin, yellow/member), role badges in card header, labeled "Switch" button on inactive cards
2. `/dashboard/teams/[id]` — gradient hero banner visible, floating team icon, stats strip shows member count + pending invite count, danger zone has subtle red border container
3. Teams nav icon stays highlighted when on detail page (already shipped separately)
