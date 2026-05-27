import { getSongs } from "@/features/songs/api/songsApi"
import type { AppContext } from "@/features/app-context"

const mockPersonalContext: AppContext = { type: "personal", userId: "user-1" }

function makeMockSupabase(rows: object[] = []) {
  const chain = {
    select: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    is: jest.fn().mockReturnThis(),
    or: jest.fn().mockReturnThis(),
    textSearch: jest.fn().mockReturnThis(),
    order: jest.fn().mockResolvedValue({ data: rows, error: null })
  }
  const from = jest.fn().mockReturnValue(chain)
  return { supabase: { from } as unknown as Parameters<typeof getSongs>[0], chain }
}

describe("getSongs", () => {
  it("calls textSearch with prefix query when a non-empty query is provided", async () => {
    const { supabase, chain } = makeMockSupabase()

    await getSongs(supabase, mockPersonalContext, "amazing grace")

    expect(chain.textSearch).toHaveBeenCalledWith("search_vector", "amazing:* & grace:*")
  })

  it("applies prefix matching for partial words", async () => {
    const { supabase, chain } = makeMockSupabase()

    await getSongs(supabase, mockPersonalContext, "hay lib")

    expect(chain.textSearch).toHaveBeenCalledWith("search_vector", "hay:* & lib:*")
  })

  it("does not call textSearch when query is empty", async () => {
    const { supabase, chain } = makeMockSupabase()

    await getSongs(supabase, mockPersonalContext, "")

    expect(chain.textSearch).not.toHaveBeenCalled()
  })

  it("does not call textSearch when query is whitespace only", async () => {
    const { supabase, chain } = makeMockSupabase()

    await getSongs(supabase, mockPersonalContext, "   ")

    expect(chain.textSearch).not.toHaveBeenCalled()
  })

  it("does not call textSearch when query is omitted", async () => {
    const { supabase, chain } = makeMockSupabase()

    await getSongs(supabase, mockPersonalContext)

    expect(chain.textSearch).not.toHaveBeenCalled()
  })

  it("returns empty array when no songs match", async () => {
    const { supabase } = makeMockSupabase([])

    const result = await getSongs(supabase, mockPersonalContext, "nonexistent")

    expect(result).toEqual([])
  })

  it("maps returned rows to frontend Song objects", async () => {
    const row = {
      id: "song-1",
      title: "Amazing Grace",
      artist: "John Newton",
      key: "G",
      bpm: 80,
      lyrics: null,
      notes: null,
      transpose: 0,
      capo: 0,
      status: "published"
    }
    const { supabase } = makeMockSupabase([row])

    const result = await getSongs(supabase, mockPersonalContext, "amazing")

    expect(result).toHaveLength(1)
    expect(result[0]).toMatchObject({
      id: "song-1",
      title: "Amazing Grace",
      artist: "John Newton"
    })
  })
})
