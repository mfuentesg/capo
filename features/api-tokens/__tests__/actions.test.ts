import { createClient } from "@/lib/supabase/server"
import {
  createApiTokenAction,
  revokeApiTokenAction,
  listApiTokensAction
} from "../api/actions"
import { hashToken } from "../lib/token"

jest.mock("@/lib/supabase/server", () => ({
  createClient: jest.fn()
}))

describe("api token actions", () => {
  const mockGetUser = jest.fn()
  const single = jest.fn()
  const insertSelect = jest.fn(() => ({ single }))
  const insert = jest.fn(() => ({ select: insertSelect }))
  const eqSecond = jest.fn()
  const eqFirst = jest.fn(() => ({ eq: eqSecond }))
  const update = jest.fn(() => ({ eq: eqFirst }))
  const order = jest.fn()
  const listEq = jest.fn(() => ({ order }))
  const select = jest.fn(() => ({ eq: listEq }))
  const from = jest.fn(() => ({ insert, update, select }))

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue({ auth: { getUser: mockGetUser }, from })
    mockGetUser.mockResolvedValue({ data: { user: { id: "user-1" } } })
  })

  it("throws when unauthenticated", async () => {
    mockGetUser.mockResolvedValue({ data: { user: null } })
    await expect(createApiTokenAction("x")).rejects.toThrow("Not authenticated")
    await expect(revokeApiTokenAction("1")).rejects.toThrow("Not authenticated")
    await expect(listApiTokensAction()).rejects.toThrow("Not authenticated")
    expect(from).not.toHaveBeenCalled()
  })

  it("rejects an empty name without inserting", async () => {
    await expect(createApiTokenAction("  ")).rejects.toThrow()
    expect(insert).not.toHaveBeenCalled()
  })

  it("inserts the hash, returns the plaintext token, never selects token_hash", async () => {
    single.mockResolvedValue({ data: { id: "tok-1" }, error: null })
    const result = await createApiTokenAction("laptop")

    expect(from).toHaveBeenCalledWith("api_tokens")
    const inserted = (insert.mock.calls[0] as unknown[])[0] as {
      user_id: string
      name: string
      token_hash: string
    }
    expect(inserted.user_id).toBe("user-1")
    expect(inserted.name).toBe("laptop")
    expect(inserted.token_hash).toMatch(/^[0-9a-f]{64}$/)
    expect(result.id).toBe("tok-1")
    expect(result.token.startsWith("capo_")).toBe(true)
    expect(hashToken(result.token)).toBe(inserted.token_hash)
    expect(JSON.stringify(insertSelect.mock.calls)).not.toContain("token_hash")
    expect(inserted).not.toHaveProperty("token")
  })

  it("revokes by id and user_id", async () => {
    eqSecond.mockResolvedValue({ error: null })
    await revokeApiTokenAction("tok-1")
    const payload = (update.mock.calls[0] as unknown[])[0] as { revoked_at: string }
    expect(typeof payload.revoked_at).toBe("string")
    expect(eqFirst).toHaveBeenCalledWith("id", "tok-1")
    expect(eqSecond).toHaveBeenCalledWith("user_id", "user-1")
  })

  it("lists without selecting token_hash", async () => {
    const rows = [{ id: "a", name: "n", created_at: "t", last_used_at: null, revoked_at: null }]
    order.mockResolvedValue({ data: rows, error: null })
    const result = await listApiTokensAction()
    expect(select).toHaveBeenCalledWith("id,name,created_at,last_used_at,revoked_at")
    expect(String((select.mock.calls[0] as unknown[])[0])).not.toContain("token_hash")
    expect(listEq).toHaveBeenCalledWith("user_id", "user-1")
    expect(result).toEqual(rows)
  })
})
