/** @jest-environment node */
import { GET } from "../route"

const rpc = jest.fn()
jest.mock("@supabase/supabase-js", () => ({ createClient: () => ({ rpc }) }))
jest.mock("@/lib/env", () => ({
  env: { required: { supabaseUrl: "http://x", supabasePublishableKey: "k" }, optional: {} }
}))

const req = (qs = "", auth: string | null = "Bearer capo_tok") =>
  new Request(`http://localhost/api/v1/songs${qs}`, {
    headers: auth ? { authorization: auth } : {}
  })

const row = (n: number) => ({
  id: `00000000-0000-0000-0000-00000000000${n}`, title: `T${n}`, artist: null, key: "G",
  bpm: 100, lyrics: "[G]la", status: "published", tags: [], updated_at: `2026-01-0${n}T00:00:00Z`,
  valid: true
})

type Body = { songs: { id: string }[]; next_cursor: string | null; server_time: string }
const callArgs = (i: number) => (rpc.mock.calls[i] as [string, Record<string, unknown>])[1]

beforeEach(() => rpc.mockReset())

describe("GET /api/v1/songs", () => {
  it("401 without a bearer header", async () => {
    const res = await GET(req("", null))
    expect(res.status).toBe(401)
    expect(await res.json()).toEqual({ error: "unauthorized" })
    expect(rpc).not.toHaveBeenCalled()
  })

  it("401 with the same body for an unknown or revoked token", async () => {
    rpc.mockResolvedValue({ data: [{ valid: false }], error: null })
    const res = await GET(req())
    expect(res.status).toBe(401)
    expect(await res.json()).toEqual({ error: "unauthorized" })
  })

  it("passes the raw token (hashed inside SQL), never a hash", async () => {
    rpc.mockResolvedValue({ data: [], error: null })
    await GET(req())
    const args = callArgs(0)
    expect(args.p_token).toBe("capo_tok")
    expect(args).not.toHaveProperty("p_token_hash")
  })

  it("reads server_time before calling the database", async () => {
    let atRpc = ""
    rpc.mockImplementation(async () => {
      atRpc = new Date(Date.now() + 50).toISOString()
      await new Promise((r) => setTimeout(r, 60))
      return { data: [], error: null }
    })
    const body = (await (await GET(req())).json()) as Body
    expect(Date.parse(body.server_time)).toBeLessThan(Date.parse(atRpc))
  })

  it("returns songs, server_time and a null cursor on the last page", async () => {
    rpc.mockResolvedValue({ data: [row(1), row(2)], error: null })
    const body = (await (await GET(req("?limit=5"))).json()) as Body
    expect(body.songs.map((s: { id: string }) => s.id)).toHaveLength(2)
    expect(body.songs[0]).not.toHaveProperty("valid")
    expect(body.next_cursor).toBeNull()
    expect(Date.parse(body.server_time)).not.toBeNaN()
  })

  it("returns a cursor when the page is full and passes it back", async () => {
    rpc.mockResolvedValue({ data: [row(1), row(2)], error: null })
    const first = (await (await GET(req("?limit=2"))).json()) as Body
    expect(first.next_cursor).toEqual(expect.any(String))
    rpc.mockResolvedValue({ data: [], error: null })
    await GET(req(`?limit=2&cursor=${first.next_cursor}`))
    expect(callArgs(1).p_after_id).toBe(row(2).id)
    expect(callArgs(1).p_after_updated).toBe(row(2).updated_at)
  })

  it("400 for a bad cursor, bad updated_since or bad limit", async () => {
    for (const qs of ["?cursor=zzz", "?updated_since=nope", "?limit=0", "?limit=abc"]) {
      expect((await GET(req(qs))).status).toBe(400)
    }
  })

  it("clamps limit to 500", async () => {
    rpc.mockResolvedValue({ data: [], error: null })
    await GET(req("?limit=9999"))
    expect(callArgs(0).p_limit).toBe(500)
  })

  it("500 with a generic body when the database fails", async () => {
    rpc.mockResolvedValue({ data: null, error: { message: "boom" } })
    const res = await GET(req())
    expect(res.status).toBe(500)
    expect(await res.json()).toEqual({ error: "internal" })
  })
})
