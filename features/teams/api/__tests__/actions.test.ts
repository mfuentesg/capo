import { revalidatePath } from "next/cache"
import { createClient } from "@/lib/supabase/server"
import {
  acceptTeamInvitation as acceptTeamInvitationApi,
  changeTeamMemberRole as changeTeamMemberRoleApi,
  createTeam as createTeamApi,
  deleteTeam as deleteTeamApi,
  deleteTeamInvitation as deleteTeamInvitationApi,
  getPendingInvitations as getPendingInvitationsApi,
  inviteTeamMember as inviteTeamMemberApi,
  leaveTeam as leaveTeamApi,
  removeTeamMember as removeTeamMemberApi,
  transferTeamOwnership as transferTeamOwnershipApi,
  updateTeam as updateTeamApi
} from "../teamsApi"
import {
  acceptTeamInvitationAction,
  changeTeamMemberRoleAction,
  createTeamAction,
  deleteTeamAction,
  deleteTeamInvitationAction,
  getPendingInvitationsAction,
  inviteTeamMemberAction,
  leaveTeamAction,
  removeTeamMemberAction,
  transferTeamOwnershipAction,
  updateTeamAction
} from "../actions"

jest.mock("next/cache", () => ({
  revalidatePath: jest.fn()
}))

jest.mock("@/lib/supabase/server", () => ({
  createClient: jest.fn()
}))

jest.mock("../teamsApi", () => ({
  acceptTeamInvitation: jest.fn(),
  createTeam: jest.fn(),
  updateTeam: jest.fn(),
  deleteTeam: jest.fn(),
  leaveTeam: jest.fn(),
  transferTeamOwnership: jest.fn(),
  inviteTeamMember: jest.fn(),
  removeTeamMember: jest.fn(),
  changeTeamMemberRole: jest.fn(),
  deleteTeamInvitation: jest.fn(),
  getPendingInvitations: jest.fn()
}))

describe("team actions", () => {
  const mockSupabase = {
    id: "supabase-client",
    auth: {
      getUser: jest.fn()
    }
  }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    mockSupabase.auth.getUser.mockResolvedValue({
      data: { user: { id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc" } },
      error: null
    })
  })

  it("creates a team and revalidates team list route", async () => {
    ;(createTeamApi as jest.Mock).mockResolvedValue({ id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd" })

    const result = await createTeamAction({
      name: "Worship Team",
      created_by: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    })

    expect(result).toBe("dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    expect(createTeamApi).toHaveBeenCalledWith(mockSupabase, {
      name: "Worship Team",
      created_by: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    })
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/teams")
  })

  it("updates, deletes, leaves, and transfers ownership with team route revalidation", async () => {
    await updateTeamAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd", { name: "Updated Team" })
    await deleteTeamAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    await leaveTeamAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    await transferTeamOwnershipAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd", "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")

    expect(updateTeamApi).toHaveBeenCalledWith(mockSupabase, "dddddddd-dddd-4ddd-8ddd-dddddddddddd", { name: "Updated Team" })
    expect(deleteTeamApi).toHaveBeenCalledWith(mockSupabase, "dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    expect(leaveTeamApi).toHaveBeenCalledWith(mockSupabase, "dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    expect(transferTeamOwnershipApi).toHaveBeenCalledWith(mockSupabase, "dddddddd-dddd-4ddd-8ddd-dddddddddddd", "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")
    expect(revalidatePath).toHaveBeenCalledTimes(4)
    expect(revalidatePath).toHaveBeenNthCalledWith(1, "/dashboard/teams")
    expect(revalidatePath).toHaveBeenNthCalledWith(2, "/dashboard/teams")
    expect(revalidatePath).toHaveBeenNthCalledWith(3, "/dashboard/teams")
    expect(revalidatePath).toHaveBeenNthCalledWith(4, "/dashboard/teams")
  })

  it("invites a member with explicit and default roles", async () => {
    await inviteTeamMemberAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd", "admin@example.com", "admin")
    await inviteTeamMemberAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd", "member@example.com")

    expect(inviteTeamMemberApi).toHaveBeenNthCalledWith(
      1,
      mockSupabase,
      "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "admin@example.com",
      "admin"
    )
    expect(inviteTeamMemberApi).toHaveBeenNthCalledWith(
      2,
      mockSupabase,
      "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "member@example.com",
      "member"
    )
    expect(revalidatePath).not.toHaveBeenCalledWith("/dashboard/teams/dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    expect(revalidatePath).toHaveBeenCalledTimes(0)
  })

  it("removes members, changes role, and deletes invitations", async () => {
    await removeTeamMemberAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd", "ffffffff-ffff-4fff-8fff-ffffffffffff")
    await changeTeamMemberRoleAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd", "ffffffff-ffff-4fff-8fff-ffffffffffff", "viewer")
    await deleteTeamInvitationAction("99999999-9999-4999-8999-999999999999")

    expect(removeTeamMemberApi).toHaveBeenCalledWith(mockSupabase, "dddddddd-dddd-4ddd-8ddd-dddddddddddd", "ffffffff-ffff-4fff-8fff-ffffffffffff")
    expect(changeTeamMemberRoleApi).toHaveBeenCalledWith(
      mockSupabase,
      "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      "ffffffff-ffff-4fff-8fff-ffffffffffff",
      "viewer"
    )
    expect(deleteTeamInvitationApi).toHaveBeenCalledWith(mockSupabase, "99999999-9999-4999-8999-999999999999")
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/teams/dddddddd-dddd-4ddd-8ddd-dddddddddddd")
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/invitations")
    expect(revalidatePath).toHaveBeenCalledTimes(3)
  })

  it("accepts invitation and revalidates invitation and team routes", async () => {
    ;(acceptTeamInvitationApi as jest.Mock).mockResolvedValue("dddddddd-dddd-4ddd-8ddd-dddddddddddd")

    const result = await acceptTeamInvitationAction("invite-token")

    expect(result).toEqual({
      teamId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
      errorCode: null,
      errorMessage: null
    })
    expect(acceptTeamInvitationApi).toHaveBeenCalledWith(mockSupabase, "invite-token")
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/invitations")
    expect(revalidatePath).toHaveBeenCalledWith("/dashboard/teams")
  })

  it("returns AUTH_REQUIRED when current user is missing", async () => {
    mockSupabase.auth.getUser.mockResolvedValue({
      data: { user: null },
      error: null
    })

    const result = await acceptTeamInvitationAction("invite-token")

    expect(result).toEqual({
      teamId: null,
      errorCode: "AUTH_REQUIRED",
      errorMessage: "Not authenticated"
    })
    expect(acceptTeamInvitationApi).not.toHaveBeenCalled()
  })

  it("returns AUTH_REQUIRED when auth.getUser returns an error", async () => {
    mockSupabase.auth.getUser.mockResolvedValue({
      data: { user: null },
      error: { message: "JWT expired" }
    })

    const result = await acceptTeamInvitationAction("invite-token")

    expect(result).toEqual({
      teamId: null,
      errorCode: "AUTH_REQUIRED",
      errorMessage: "Not authenticated"
    })
    expect(acceptTeamInvitationApi).not.toHaveBeenCalled()
  })

  it("returns API error code and message when invitation RPC fails", async () => {
    ;(acceptTeamInvitationApi as jest.Mock).mockRejectedValue({
      code: "P0001",
      message: "Invitation already accepted"
    })

    const result = await acceptTeamInvitationAction("invite-token")

    expect(result).toEqual({
      teamId: null,
      errorCode: "P0001",
      errorMessage: "Invitation already accepted"
    })
    expect(revalidatePath).not.toHaveBeenCalled()
  })

  it("returns fallback error message when invitation RPC fails without message", async () => {
    ;(acceptTeamInvitationApi as jest.Mock).mockRejectedValue({ code: "P0001" })

    const result = await acceptTeamInvitationAction("invite-token")

    expect(result).toEqual({
      teamId: null,
      errorCode: "P0001",
      errorMessage: "Failed to accept invitation"
    })
    expect(revalidatePath).not.toHaveBeenCalled()
  })

  it("returns string error when invitation RPC rejects with a string", async () => {
    ;(acceptTeamInvitationApi as jest.Mock).mockRejectedValue("Invitation already accepted")

    const result = await acceptTeamInvitationAction("invite-token")

    expect(result).toEqual({
      teamId: null,
      errorCode: null,
      errorMessage: "Invitation already accepted"
    })
    expect(revalidatePath).not.toHaveBeenCalled()
  })
})


describe("getPendingInvitationsAction", () => {
  it("fetches pending invitations using the supabase client", async () => {
    const mockSupabase = { id: "supabase-client" }
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    const invitations = [{ id: "inv-1", teamName: "Band" }]
    ;(getPendingInvitationsApi as jest.Mock).mockResolvedValue(invitations)

    const result = await getPendingInvitationsAction()

    expect(getPendingInvitationsApi).toHaveBeenCalledWith(mockSupabase)
    expect(result).toEqual(invitations)
  })
})

describe("input validation", () => {
  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue({ id: "supabase-client" })
  })

  it("rejects a non-UUID team id", async () => {
    await expect(deleteTeamAction("not-a-uuid")).rejects.toThrow()
    expect(deleteTeamApi).not.toHaveBeenCalled()
  })

  it("rejects an invalid email on invitation", async () => {
    await expect(
      inviteTeamMemberAction("dddddddd-dddd-4ddd-8ddd-dddddddddddd", "not-an-email")
    ).rejects.toThrow()
    expect(inviteTeamMemberApi).not.toHaveBeenCalled()
  })

  it("rejects an unknown role on role change", async () => {
    await expect(
      changeTeamMemberRoleAction(
        "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
        "ffffffff-ffff-4fff-8fff-ffffffffffff",
        "superadmin" as never
      )
    ).rejects.toThrow()
    expect(changeTeamMemberRoleApi).not.toHaveBeenCalled()
  })

  it("returns INVALID_TOKEN for malformed invitation tokens", async () => {
    const result = await acceptTeamInvitationAction("")
    expect(result.errorCode).toBe("INVALID_TOKEN")
    expect(acceptTeamInvitationApi).not.toHaveBeenCalled()
  })
})
