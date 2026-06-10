"use server"

import { revalidatePath } from "next/cache"
import { z } from "zod"
import { createClient } from "@/lib/supabase/server"
import { uuidSchema, emailSchema, tokenSchema } from "@/lib/validation"
import type { Tables, TablesUpdate, TablesInsert } from "@/lib/supabase/database.types"
import {
  createTeam as createTeamApi,
  updateTeam as updateTeamApi,
  deleteTeam as deleteTeamApi,
  leaveTeam as leaveTeamApi,
  acceptTeamInvitation as acceptTeamInvitationApi,
  transferTeamOwnership as transferTeamOwnershipApi,
  inviteTeamMember as inviteTeamMemberApi,
  removeTeamMember as removeTeamMemberApi,
  changeTeamMemberRole as changeTeamMemberRoleApi,
  deleteTeamInvitation as deleteTeamInvitationApi,
  getPendingInvitations as getPendingInvitationsApi
} from "./teamsApi"
import type { PendingInvitation } from "../types"

const teamRoleSchema = z.enum(["member", "admin", "owner", "viewer"])

const teamFieldsSchema = z.looseObject({
  name: z.string().trim().min(1).max(120).optional(),
  description: z.string().max(500).nullish(),
  icon: z.string().max(50).nullish()
})

export async function createTeamAction(teamData: TablesInsert<"teams">): Promise<string> {
  const validated = teamFieldsSchema.parse(teamData) as TablesInsert<"teams">
  const supabase = await createClient()
  const team = await createTeamApi(supabase, validated)
  revalidatePath("/dashboard/teams")
  return team.id
}

export async function updateTeamAction(
  teamId: string,
  updates: TablesUpdate<"teams">
): Promise<void> {
  uuidSchema.parse(teamId)
  const validated = teamFieldsSchema.parse(updates) as TablesUpdate<"teams">
  const supabase = await createClient()
  await updateTeamApi(supabase, teamId, validated)
  revalidatePath("/dashboard/teams")
}

export async function deleteTeamAction(teamId: string): Promise<void> {
  uuidSchema.parse(teamId)
  const supabase = await createClient()
  await deleteTeamApi(supabase, teamId)
  revalidatePath("/dashboard/teams")
}

export async function leaveTeamAction(teamId: string): Promise<void> {
  uuidSchema.parse(teamId)
  const supabase = await createClient()
  await leaveTeamApi(supabase, teamId)
  revalidatePath("/dashboard/teams")
}

export async function transferTeamOwnershipAction(
  teamId: string,
  newOwnerId: string
): Promise<void> {
  uuidSchema.parse(teamId)
  uuidSchema.parse(newOwnerId)
  const supabase = await createClient()
  await transferTeamOwnershipApi(supabase, teamId, newOwnerId)
  revalidatePath("/dashboard/teams")
}

export async function inviteTeamMemberAction(
  teamId: string,
  email: string,
  role: "member" | "admin" | "owner" | "viewer" = "member"
): Promise<Tables<"team_invitations">> {
  uuidSchema.parse(teamId)
  const validatedEmail = emailSchema.parse(email)
  teamRoleSchema.parse(role)
  const supabase = await createClient()
  return inviteTeamMemberApi(supabase, teamId, validatedEmail, role)
}

export async function removeTeamMemberAction(teamId: string, userId: string): Promise<void> {
  uuidSchema.parse(teamId)
  uuidSchema.parse(userId)
  const supabase = await createClient()
  await removeTeamMemberApi(supabase, teamId, userId)
  revalidatePath(`/dashboard/teams/${teamId}`)
}

export async function changeTeamMemberRoleAction(
  teamId: string,
  userId: string,
  newRole: "member" | "admin" | "owner" | "viewer"
): Promise<void> {
  uuidSchema.parse(teamId)
  uuidSchema.parse(userId)
  teamRoleSchema.parse(newRole)
  const supabase = await createClient()
  await changeTeamMemberRoleApi(supabase, teamId, userId, newRole)
  revalidatePath(`/dashboard/teams/${teamId}`)
}

export async function deleteTeamInvitationAction(invitationId: string): Promise<void> {
  uuidSchema.parse(invitationId)
  const supabase = await createClient()
  // We don't have teamId here easily, but we can revalidate the invitations dashboard
  await deleteTeamInvitationApi(supabase, invitationId)
  revalidatePath("/dashboard/invitations")
}

export async function getPendingInvitationsAction(): Promise<PendingInvitation[]> {
  const supabase = await createClient()
  return getPendingInvitationsApi(supabase)
}

export interface AcceptTeamInvitationResult {
  teamId: string | null
  errorCode: string | null
  errorMessage: string | null
}

export async function acceptTeamInvitationAction(token: string): Promise<AcceptTeamInvitationResult> {
  if (!tokenSchema.safeParse(token).success) {
    return {
      teamId: null,
      errorCode: "INVALID_TOKEN",
      errorMessage: "Invalid invitation token"
    }
  }

  const supabase = await createClient()
  const {
    data: { user },
    error
  } = await supabase.auth.getUser()

  if (error || !user) {
    return {
      teamId: null,
      errorCode: "AUTH_REQUIRED",
      errorMessage: "Not authenticated"
    }
  }

  try {
    const teamId = await acceptTeamInvitationApi(supabase, token)
    revalidatePath("/dashboard/invitations")
    revalidatePath("/dashboard/teams")
    return {
      teamId,
      errorCode: null,
      errorMessage: null
    }
  } catch (err) {
    const errorCode =
      typeof err === "object" &&
      err !== null &&
      "code" in err &&
      typeof (err as { code?: unknown }).code === "string"
        ? (err as { code: string }).code
        : null

    const errorMessage =
      err instanceof Error
        ? err.message
        : typeof err === "string"
          ? err
          : typeof err === "object" &&
              err !== null &&
              "message" in err &&
              typeof (err as { message?: unknown }).message === "string"
            ? (err as { message: string }).message
            : "Failed to accept invitation"

    return {
      teamId: null,
      errorCode,
      errorMessage
    }
  }
}
