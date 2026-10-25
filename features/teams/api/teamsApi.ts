/**
 * Teams API - Supabase REST API functions
 *
 * Pure functions for data fetching and mutations.
 * No React hooks, no side effects beyond Supabase calls.
 */

import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database, Tables, TablesInsert, TablesUpdate } from "@/lib/supabase/database.types"
import type { PendingInvitation } from "../types"

export type TeamWithMemberCount = Tables<"teams"> & {
  member_count: number
  role: Tables<"team_members">["role"]
}

export async function getTeams(supabase: SupabaseClient<Database>): Promise<TeamWithMemberCount[]> {
  const {
    data: { user },
    error: userError
  } = await supabase.auth.getUser()

  if (userError) {
    throw userError
  }

  if (!user) {
    return []
  }

  return getTeamsWithClient(supabase, user.id)
}

export async function getTeamsWithClient(
  supabase: SupabaseClient<Database>,
  userId: string
): Promise<TeamWithMemberCount[]> {
  // Embed `all_members(count)` to get per-team counts in a single round-trip.
  const { data, error } = await supabase
    .from("team_members")
    .select(
      `
      team:teams (
        id,
        name,
        avatar_url,
        icon,
        is_public,
        created_at,
        created_by,
        updated_at,
        all_members:team_members(count)
      ),
      role
    `
    )
    .eq("user_id", userId)
    .order("joined_at", { ascending: false })

  if (error) {
    throw error
  }

  const result: TeamWithMemberCount[] = []
  for (const item of data || []) {
    // PostgREST might return team as an array if it's not sure about cardinality
    const teamData = (Array.isArray(item.team) ? item.team[0] : item.team) as
      | (Tables<"teams"> & { all_members: [{ count: number }] | { count: number } | null })
      | null

    if (teamData && item.role) {
      const memberCountData = teamData.all_members
      const memberCount = Array.isArray(memberCountData)
        ? memberCountData[0]?.count ?? 1
        : memberCountData?.count ?? 1

      result.push({
        id: teamData.id,
        name: teamData.name,
        avatar_url: teamData.avatar_url,
        icon: teamData.icon,
        is_public: teamData.is_public,
        created_at: teamData.created_at,
        created_by: teamData.created_by,
        updated_at: teamData.updated_at,
        role: item.role,
        member_count: memberCount
      })
    }
  }

  return result
}

export async function getTeam(
  supabase: SupabaseClient<Database>,
  teamId: string
): Promise<Tables<"teams"> | null> {
  return getTeamWithClient(supabase, teamId)
}

export async function getTeamWithClient(
  supabase: SupabaseClient<Database>,
  teamId: string
): Promise<Tables<"teams"> | null> {
  const { data, error } = await supabase.from("teams").select("*").eq("id", teamId).single()

  if (error) {
    if (error.code === "PGRST116") return null
    throw error
  }

  return data || null
}

export async function createTeam(
  supabase: SupabaseClient<Database>,
  team: TablesInsert<"teams">
): Promise<Tables<"teams">> {
  const { data, error: rpcError } = await supabase.rpc("create_team_with_owner", {
    team_name: team.name,
    team_is_public: team.is_public || false,
    team_icon: team.icon || undefined
  })

  if (rpcError) throw rpcError
  if (!Array.isArray(data) || data.length === 0) throw new Error("Failed to create team")

  // The RPC returns the full team object
  return data[0]
}

export async function updateTeam(
  supabase: SupabaseClient<Database>,
  teamId: string,
  updates: TablesUpdate<"teams">
): Promise<Tables<"teams">> {
  const { data, error } = await supabase
    .from("teams")
    .update(updates)
    .eq("id", teamId)
    .select()
    .single()

  if (error) throw error
  return data
}

export async function deleteTeam(
  supabase: SupabaseClient<Database>,
  teamId: string
): Promise<void> {
  const { error } = await supabase.from("teams").delete().eq("id", teamId)
  if (error) throw error
}

export async function leaveTeam(supabase: SupabaseClient<Database>, teamId: string): Promise<void> {
  const { error } = await supabase.rpc("leave_team", { target_team_id: teamId })
  if (error) throw error
}

export async function getTeamMembers(
  supabase: SupabaseClient<Database>,
  teamId: string
): Promise<
  (Tables<"team_members"> & {
    user_full_name: string | null
    user_email: string | null
    user_avatar_url: string | null
  })[]
> {
  return getTeamMembersWithClient(supabase, teamId)
}

export async function getTeamMembersWithClient(
  supabase: SupabaseClient<Database>,
  teamId: string
): Promise<
  (Tables<"team_members"> & {
    user_full_name: string | null
    user_email: string | null
    user_avatar_url: string | null
  })[]
> {
  const { data, error } = await supabase
    .from("team_members")
    .select(`*, profiles(full_name,email,avatar_url)`)
    .eq("team_id", teamId)
    .order("joined_at", { ascending: true })

  if (error) {
    throw error
  }

  // Map results to include user_full_name/user_email at the top level
  type MemberWithProfile = Tables<"team_members"> & {
    profiles:
      | { full_name: string | null; email: string | null; avatar_url: string | null }
      | { full_name: string | null; email: string | null; avatar_url: string | null }[]
      | null
  }
  return (
    (data as MemberWithProfile[] | null)?.map((item) => {
      const profile = Array.isArray(item.profiles) ? item.profiles[0] : item.profiles
      return {
        ...item,
        user_full_name: profile?.full_name || null,
        user_email: profile?.email || null,
        user_avatar_url: profile?.avatar_url || null
      }
    }) || []
  )
}

export async function getTeamInvitations(
  supabase: SupabaseClient<Database>,
  teamId: string
): Promise<Tables<"team_invitations">[]> {
  const { data, error } = await supabase
    .from("team_invitations")
    .select("*")
    .eq("team_id", teamId)
    .is("accepted_at", null)
    .order("created_at", { ascending: false })

  if (error) throw error
  return data || []
}

export async function acceptTeamInvitation(
  supabase: SupabaseClient<Database>,
  token: string
): Promise<string> {
  const { data, error } = await supabase.rpc("accept_team_invitation", {
    invitation_token: token
  })

  if (error) throw error
  return data as string
}

export async function deleteTeamInvitation(
  supabase: SupabaseClient<Database>,
  invitationId: string
): Promise<void> {
  const { error } = await supabase.from("team_invitations").delete().eq("id", invitationId)

  if (error) throw error
}

export async function changeTeamMemberRole(
  supabase: SupabaseClient<Database>,
  teamId: string,
  userId: string,
  newRole: Tables<"team_members">["role"]
): Promise<void> {
  const { error } = await supabase.rpc("change_team_member_role", {
    target_team_id: teamId,
    target_user_id: userId,
    new_role: newRole
  })

  if (error) throw error
}

export async function transferTeamOwnership(
  supabase: SupabaseClient<Database>,
  teamId: string,
  newOwnerId: string
): Promise<void> {
  const { error } = await supabase.rpc("transfer_team_ownership", {
    target_team_id: teamId,
    new_owner_id: newOwnerId
  })

  if (error) throw error
}

export async function inviteTeamMember(
  supabase: SupabaseClient<Database>,
  teamId: string,
  email: string,
  role: Tables<"team_invitations">["role"] = "member"
): Promise<Tables<"team_invitations">> {
  const { data, error } = await supabase.rpc("invite_team_member", {
    target_team_id: teamId,
    member_email: email,
    member_role: role
  })

  if (error) throw error
  if (!data) throw new Error("Failed to create invitation")
  return data
}

export async function removeTeamMember(
  supabase: SupabaseClient<Database>,
  teamId: string,
  userId: string
): Promise<void> {
  const { error } = await supabase.rpc("remove_team_member", {
    target_team_id: teamId,
    target_user_id: userId
  })

  if (error) throw error
}

type PendingInvitationRow = Database["public"]["Functions"]["get_my_pending_invitations"]["Returns"][number]

export function mapPendingInvitation(row: PendingInvitationRow): PendingInvitation {
  const { team_name, inviter_name, ...invitation } = row
  return { ...invitation, teamName: team_name, inviterName: inviter_name }
}

/**
 * Fetches all pending invitations for the current user by email. Goes through an RPC because the
 * team_invitations SELECT policy only exposes rows to members of the inviting team.
 */
export async function getPendingInvitations(
  supabase: SupabaseClient<Database>
): Promise<PendingInvitation[]> {
  const { data, error } = await supabase.rpc("get_my_pending_invitations")

  if (error) throw error
  return (data ?? []).map(mapPendingInvitation)
}

/**
 * Declines (removes) the current user's own invitation. Returns false when nothing matched.
 */
export async function declineTeamInvitation(
  supabase: SupabaseClient<Database>,
  token: string
): Promise<boolean> {
  const { data, error } = await supabase.rpc("decline_team_invitation", { p_token: token })

  if (error) throw error
  return data
}

/**
 * Replaces an invitation with a fresh one (new token and expiry) in a single transaction.
 */
export async function resendTeamInvitation(
  supabase: SupabaseClient<Database>,
  invitationId: string
): Promise<Tables<"team_invitations">> {
  const { data, error } = await supabase.rpc("resend_team_invitation", {
    p_invitation_id: invitationId
  })

  if (error) throw error
  if (!data) throw new Error("Failed to resend invitation")
  return data
}
