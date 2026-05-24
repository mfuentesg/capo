# Teams Feature

## Overview

The teams feature manages teams, allowing users to create, manage, and collaborate within teams. Teams share a common song library and playlists. Supports role-based access control, email invitations with expiry tokens, ownership transfer, and real-time updates for membership changes.

## Roles

| Role | Permissions |
|---|---|
| `owner` | Full control — edit team, manage all members, transfer ownership, delete team |
| `admin` | Invite members, change roles (except owner), remove members |
| `member` | Read and write songs/playlists |
| `viewer` | Read-only access to team content |

## Public API

### Components

- `TeamsClient` - Main container component for teams management
- `CreateTeamClient` - Client component for creating new teams
- `CreateTeamForm` - Form component for team creation
- `TeamDetailClient` - Client component for team detail view
- `TeamCard` - Card component for displaying team information
- `TeamForm` - Form component for editing teams

### Hooks

- `useTeams` - Hook for managing teams data
- `useTeamRealtime` - Hook for real-time team membership updates

### API

- `getTeams()` - Fetch all teams for the current user
- `getTeam(teamId: string)` - Get a single team by ID
- `createTeam(team: TeamInsert)` - Create a new team
- `updateTeam(teamId: string, updates: TeamUpdate)` - Update a team
- `getTeamMembers(teamId: string)` - Get team members with roles
- `getTeamInvitations(teamId: string)` - Get pending invitations
- `acceptTeamInvitation(token: string)` - Accept an invitation via token
- `changeTeamMemberRole(teamId, userId, newRole)` - Change a member's role
- `transferTeamOwnership(teamId, newOwnerId)` - Transfer ownership to another member

### Types

All types are exported from `@/features/teams`.

## Usage

```typescript
import {
  TeamsClient,
  useTeams,
  getTeams,
  createTeam
} from "@/features/teams"

// Using the component
export default function TeamsPage() {
  return <TeamsClient />
}

// Using the hook
function MyComponent() {
  const { teams, isLoading, error } = useTeams()
  // ...
}

// Using the API directly
const teams = await getTeams()
const newTeam = await createTeam({ name: "My Band" })
```

## Dependencies

- `@/lib/supabase` - For database operations
- `@/features/auth` - For authentication and user context

## Internal Structure

```
features/teams/
├── components/       # UI components
├── hooks/            # Custom hooks (useTeams, useTeamRealtime)
├── types/            # TypeScript types
├── api/              # Server actions
├── lib/              # Internal utilities
└── constants/        # Role constants and permissions
```
