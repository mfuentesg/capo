import {
  getTeamsWithClient,
  getTeamInvitations,
  getPendingInvitations,
  declineTeamInvitation,
  resendTeamInvitation
} from "../teamsApi"

function makeTeamRow(overrides: {
  all_members?: [{ count: number }] | null
  role?: string
} = {}) {
  return {
    team: {
      id: "team-1",
      name: "Worship",
      avatar_url: null,
      icon: null,
      is_public: false,
      created_at: "2026-01-01T00:00:00.000Z",
      created_by: "user-1",
      updated_at: "2026-01-01T00:00:00.000Z",
      all_members: overrides.all_members !== undefined ? overrides.all_members : [{ count: 3 }]
    },
    role: overrides.role ?? "owner"
  }
}

function makeSupabase(result: { data: unknown; error: unknown }) {
  const order = jest.fn().mockResolvedValue(result)
  const eq = jest.fn().mockReturnValue({ order })
  const select = jest.fn().mockReturnValue({ eq })
  const from = jest.fn().mockReturnValue({ select })
  return { supabase: { from }, from, select, eq, order }
}

describe("getTeamsWithClient", () => {
  afterEach(() => jest.clearAllMocks())

  it("issues exactly one query (no second round-trip for counts)", async () => {
    const { supabase, from } = makeSupabase({ data: [], error: null })

    await getTeamsWithClient(supabase as never, "user-1")

    expect(from).toHaveBeenCalledTimes(1)
  })

  it("queries team_members with the embedded all_members count", async () => {
    const { supabase, from, select, eq, order } = makeSupabase({ data: [], error: null })

    await getTeamsWithClient(supabase as never, "user-1")

    expect(from).toHaveBeenCalledWith("team_members")
    expect(select).toHaveBeenCalledWith(
      expect.stringContaining("all_members:team_members(count)")
    )
    expect(eq).toHaveBeenCalledWith("user_id", "user-1")
    expect(order).toHaveBeenCalledWith("joined_at", { ascending: false })
  })

  it("returns empty array when the user belongs to no teams", async () => {
    const { supabase } = makeSupabase({ data: [], error: null })

    const result = await getTeamsWithClient(supabase as never, "user-1")

    expect(result).toEqual([])
  })

  it("extracts member_count from all_members[0].count", async () => {
    const { supabase } = makeSupabase({ data: [makeTeamRow({ all_members: [{ count: 7 }] })], error: null })

    const result = await getTeamsWithClient(supabase as never, "user-1")

    expect((result[0] as { member_count: number }).member_count).toBe(7)
  })

  it("falls back to member_count of 1 when all_members is null", async () => {
    const { supabase } = makeSupabase({ data: [makeTeamRow({ all_members: null })], error: null })

    const result = await getTeamsWithClient(supabase as never, "user-1")

    expect((result[0] as { member_count: number }).member_count).toBe(1)
  })

  it("maps all team scalar fields and role correctly", async () => {
    const { supabase } = makeSupabase({
      data: [makeTeamRow({ all_members: [{ count: 2 }], role: "admin" })],
      error: null
    })

    const result = await getTeamsWithClient(supabase as never, "user-1")

    expect(result[0]).toMatchObject({
      id: "team-1",
      name: "Worship",
      avatar_url: null,
      icon: null,
      is_public: false,
      created_by: "user-1",
      role: "admin",
      member_count: 2
    })
  })

  it("does not expose the all_members field on returned objects", async () => {
    const { supabase } = makeSupabase({ data: [makeTeamRow()], error: null })

    const result = await getTeamsWithClient(supabase as never, "user-1")

    expect(result[0]).not.toHaveProperty("all_members")
  })

  it("skips rows whose team is null", async () => {
    const { supabase } = makeSupabase({
      data: [
        { team: null, role: "member" },
        makeTeamRow({ all_members: [{ count: 1 }] })
      ],
      error: null
    })

    const result = await getTeamsWithClient(supabase as never, "user-1")

    expect(result).toHaveLength(1)
    expect((result[0] as { id: string }).id).toBe("team-1")
  })

  it("throws when the query returns an error", async () => {
    const { supabase } = makeSupabase({ data: null, error: new Error("connection failed") })

    await expect(getTeamsWithClient(supabase as never, "user-1")).rejects.toThrow(
      "connection failed"
    )
  })
})

describe("getTeamInvitations", () => {
  const NOW = "2026-03-01T12:00:00.000Z"
  const FUTURE = "2026-03-08T12:00:00.000Z"
  const PAST = "2026-02-22T12:00:00.000Z"

  function makeInvitation(overrides: Partial<{
    id: string
    email: string
    expires_at: string
    accepted_at: string | null
  }> = {}) {
    return {
      id: overrides.id ?? "inv-1",
      team_id: "team-1",
      email: overrides.email ?? "user@example.com",
      token: "tok",
      role: "member",
      invited_by: "user-0",
      created_at: NOW,
      expires_at: overrides.expires_at ?? FUTURE,
      accepted_at: overrides.accepted_at ?? null
    }
  }

  function makeSupabase(result: { data: unknown; error: unknown }) {
    const order = jest.fn().mockResolvedValue(result)
    const is = jest.fn().mockReturnValue({ order })
    const eq = jest.fn().mockReturnValue({ is })
    const select = jest.fn().mockReturnValue({ eq })
    const from = jest.fn().mockReturnValue({ select })
    return { supabase: { from }, from, select, eq, is, order }
  }

  afterEach(() => jest.clearAllMocks())

  it("does NOT filter by expires_at — returns both pending and expired invitations", async () => {
    const pending = makeInvitation({ id: "inv-pending", expires_at: FUTURE })
    const expired = makeInvitation({ id: "inv-expired", expires_at: PAST })
    const { supabase, is } = makeSupabase({ data: [pending, expired], error: null })

    const result = await getTeamInvitations(supabase as never, "team-1")

    expect(result).toHaveLength(2)
    expect(result.map((r) => (r as { id: string }).id)).toContain("inv-pending")
    expect(result.map((r) => (r as { id: string }).id)).toContain("inv-expired")
    // Confirm there is no gt() call in the chain — the mock chain only exposes is()
    expect(is).toHaveBeenCalledWith("accepted_at", null)
  })

  it("filters out accepted invitations via accepted_at IS NULL", async () => {
    const { supabase, is } = makeSupabase({ data: [], error: null })

    await getTeamInvitations(supabase as never, "team-1")

    expect(is).toHaveBeenCalledWith("accepted_at", null)
  })

  it("orders results by created_at descending", async () => {
    const { supabase, order } = makeSupabase({ data: [], error: null })

    await getTeamInvitations(supabase as never, "team-1")

    expect(order).toHaveBeenCalledWith("created_at", { ascending: false })
  })

  it("returns empty array when there are no invitations", async () => {
    const { supabase } = makeSupabase({ data: null, error: null })

    const result = await getTeamInvitations(supabase as never, "team-1")

    expect(result).toEqual([])
  })

  it("throws when the query returns an error", async () => {
    const { supabase } = makeSupabase({ data: null, error: new Error("db error") })

    await expect(getTeamInvitations(supabase as never, "team-1")).rejects.toThrow("db error")
  })
})

describe("invitation RPCs", () => {
  const row = {
    id: "i1",
    team_id: "t1",
    email: "a@b.co",
    role: "member",
    token: "tok",
    invited_by: "u1",
    expires_at: "2026-02-01T00:00:00Z",
    accepted_at: null,
    created_at: "2026-01-01T00:00:00Z",
    team_name: "Band",
    inviter_name: "Ana"
  }

  it("lists the invitee's pending invitations through the RPC", async () => {
    const rpc = jest.fn().mockResolvedValue({ data: [row], error: null })
    const result = await getPendingInvitations({ rpc } as never)
    expect(rpc).toHaveBeenCalledWith("get_my_pending_invitations")
    expect(result[0]).toMatchObject({ id: "i1", teamName: "Band", inviterName: "Ana", token: "tok" })
    expect(result[0]).not.toHaveProperty("team_name")
  })

  it("declines by token", async () => {
    const rpc = jest.fn().mockResolvedValue({ data: true, error: null })
    expect(await declineTeamInvitation({ rpc } as never, "tok")).toBe(true)
    expect(rpc).toHaveBeenCalledWith("decline_team_invitation", { p_token: "tok" })
  })

  it("resends by id and surfaces errors", async () => {
    const rpc = jest.fn().mockResolvedValue({ data: { id: "i2" }, error: null })
    expect(await resendTeamInvitation({ rpc } as never, "i1")).toEqual({ id: "i2" })
    expect(rpc).toHaveBeenCalledWith("resend_team_invitation", { p_invitation_id: "i1" })
    const failing = jest.fn().mockResolvedValue({ data: null, error: new Error("nope") })
    await expect(resendTeamInvitation({ rpc: failing } as never, "i1")).rejects.toThrow("nope")
  })
})
