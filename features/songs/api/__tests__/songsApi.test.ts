import { applyContextFilter } from "@/lib/supabase/apply-context-filter"
import { getSongs, getSongsByIds } from "../songsApi"

jest.mock("@/lib/supabase/apply-context-filter", () => ({
  applyContextFilter: jest.fn((query: unknown) => query)
}))

// Must match the constants in songsApi.ts — list queries exclude lyrics/notes
// and embed tags; the by-ids query fetches full content
const SONG_LIST_COLUMNS =
  "id, title, artist, key, bpm, transpose, capo, status, song_tag_assignments(song_tags(id, name, color))"
const SONG_DETAIL_COLUMNS = "id, title, artist, key, bpm, lyrics, notes, transpose, capo, status"

const personalContext = { type: "personal" as const, userId: "user-1" }

function makeOrderSupabase(result: { data: unknown; error: unknown }) {
  const order = jest.fn().mockResolvedValue(result)
  const selectResult = { order }
  const select = jest.fn().mockReturnValue(selectResult)
  const from = jest.fn().mockReturnValue({ select })
  return { supabase: { from }, select, selectResult, order }
}

describe("getSongs", () => {
  afterEach(() => jest.clearAllMocks())

  it("selects list columns (no lyrics/notes) with embedded tags", async () => {
    const { supabase, select } = makeOrderSupabase({ data: [], error: null })

    await getSongs(supabase as never, personalContext)

    expect(select).toHaveBeenCalledWith(SONG_LIST_COLUMNS)
  })

  it("queries the songs table and orders by created_at descending", async () => {
    const { supabase, order } = makeOrderSupabase({ data: [], error: null })

    await getSongs(supabase as never, personalContext)

    expect(supabase.from).toHaveBeenCalledWith("songs")
    expect(order).toHaveBeenCalledWith("created_at", { ascending: false })
  })

  it("passes the query through applyContextFilter before ordering", async () => {
    const { supabase, selectResult } = makeOrderSupabase({ data: [], error: null })

    await getSongs(supabase as never, personalContext)

    expect(applyContextFilter).toHaveBeenCalledWith(selectResult, personalContext)
  })

  it("maps database rows to the frontend Song type", async () => {
    const dbRows = [
      {
        id: "s1",
        title: "Amazing Grace",
        artist: "Traditional",
        key: "C",
        bpm: 120,
        transpose: 2,
        capo: 0,
        status: "published",
        song_tag_assignments: [
          { song_tags: { id: "tag-1", name: "Hymn", color: "#fff" } }
        ]
      },
      {
        id: "s2",
        title: "Draft Song",
        artist: null,
        key: null,
        bpm: null,
        transpose: 0,
        capo: 0,
        status: "draft",
        song_tag_assignments: []
      }
    ]
    const { supabase } = makeOrderSupabase({ data: dbRows, error: null })

    const result = await getSongs(supabase as never, personalContext)

    expect(result).toEqual([
      {
        id: "s1",
        title: "Amazing Grace",
        artist: "Traditional",
        key: "C",
        bpm: 120,
        lyrics: undefined,
        notes: undefined,
        transpose: 2,
        capo: 0,
        tags: [{ id: "tag-1", name: "Hymn", color: "#fff" }]
      },
      {
        id: "s2",
        title: "Draft Song",
        artist: "",
        key: "",
        bpm: 0,
        lyrics: undefined,
        notes: undefined,
        transpose: 0,
        capo: 0,
        tags: []
      }
    ])
  })

  it("throws when the query returns an error", async () => {
    const { supabase } = makeOrderSupabase({ data: null, error: new Error("db error") })

    await expect(getSongs(supabase as never, personalContext)).rejects.toThrow("db error")
  })
})

describe("getSongsByIds", () => {
  afterEach(() => jest.clearAllMocks())

  it("returns empty array immediately without querying when given no IDs", async () => {
    const supabase = { from: jest.fn() }

    const result = await getSongsByIds(supabase as never, [])

    expect(result).toEqual([])
    expect(supabase.from).not.toHaveBeenCalled()
  })

  it("selects detail columns and filters by the provided IDs", async () => {
    const inFn = jest.fn().mockResolvedValue({ data: [], error: null })
    const select = jest.fn().mockReturnValue({ in: inFn })
    const supabase = { from: jest.fn().mockReturnValue({ select }) }

    await getSongsByIds(supabase as never, ["s1", "s2"])

    expect(supabase.from).toHaveBeenCalledWith("songs")
    expect(select).toHaveBeenCalledWith(SONG_DETAIL_COLUMNS)
    expect(inFn).toHaveBeenCalledWith("id", ["s1", "s2"])
  })

  it("maps results to the frontend Song type", async () => {
    const dbRows = [
      {
        id: "s1",
        title: "Holy",
        artist: "Artist",
        key: "G",
        bpm: 100,
        lyrics: null,
        notes: "Note",
        transpose: 0,
        capo: 1,
        status: "published"
      }
    ]
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({
          in: jest.fn().mockResolvedValue({ data: dbRows, error: null })
        })
      })
    }

    const result = await getSongsByIds(supabase as never, ["s1"])

    expect(result).toEqual([
      {
        id: "s1",
        title: "Holy",
        artist: "Artist",
        key: "G",
        bpm: 100,
        lyrics: undefined,
        notes: "Note",
        transpose: 0,
        capo: 1
      }
    ])
  })

  it("throws when the query returns an error", async () => {
    const supabase = {
      from: jest.fn().mockReturnValue({
        select: jest.fn().mockReturnValue({
          in: jest.fn().mockResolvedValue({ data: null, error: new Error("db error") })
        })
      })
    }

    await expect(getSongsByIds(supabase as never, ["s1"])).rejects.toThrow("db error")
  })
})
