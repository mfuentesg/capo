import {
  createPlaylist,
  updatePlaylist,
  getPlaylistByShareCode,
  getPublicPlaylistByShareCode,
  getPlaylistWithSongs
} from "../playlistsApi"

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

const BASE_PLAYLIST_ROW = {
  id: "playlist-1",
  name: "Live Set",
  description: null,
  date: null,
  is_public: false,
  allow_guest_editing: false,
  share_code: "ABCDEF123456",
  created_at: "2026-01-01T00:00:00.000Z",
  updated_at: "2026-01-01T00:00:00.000Z",
  user_id: "user-1",
  team_id: null,
  created_by: "user-1",
  share_expires_at: null
}

const SONG_ROW = {
  id: "song-1",
  title: "Amazing Grace",
  artist: "Traditional",
  key: "C",
  bpm: 120,
  lyrics: "Amazing grace",
  notes: null,
  transpose: 0,
  capo: 0,
  status: "published" as const
}

// Builds a playlist row with inline playlist_songs for queries that use RETURNING/nested select
function makePlaylistWithSongsRow(songs: Array<{ song_id: string; position: number }> = []) {
  return { ...BASE_PLAYLIST_ROW, playlist_songs: songs }
}

// ---------------------------------------------------------------------------
// createPlaylist
// ---------------------------------------------------------------------------

describe("createPlaylist", () => {
  beforeEach(() => jest.spyOn(console, "error").mockImplementation(() => {}))
  afterEach(() => {
    jest.restoreAllMocks()
    jest.clearAllMocks()
  })

  function makeCreateSupabase({
    playlistResult = { data: BASE_PLAYLIST_ROW, error: null },
    songsResult = { error: null } as { error: Error | null }
  } = {}) {
    const playlistSingle = jest.fn().mockResolvedValue(playlistResult)
    const playlistSelect = jest.fn().mockReturnValue({ single: playlistSingle })
    const playlistInsert = jest.fn().mockReturnValue({ select: playlistSelect })

    const songsInsert = jest.fn().mockResolvedValue(songsResult)

    const from = jest.fn()
      .mockReturnValueOnce({ insert: playlistInsert })  // playlists
      .mockReturnValueOnce({ insert: songsInsert })      // playlist_songs

    return { supabase: { from }, from, playlistInsert, songsInsert, playlistSingle }
  }

  it("makes exactly 2 DB calls when songs are provided (no extra refetch)", async () => {
    const { supabase, from } = makeCreateSupabase()

    await createPlaylist(supabase as never, { name: "Live Set", songs: ["song-1"] }, "user-1")

    expect(from).toHaveBeenCalledTimes(2)
  })

  it("makes exactly 1 DB call when no songs are provided", async () => {
    const single = jest.fn().mockResolvedValue({ data: BASE_PLAYLIST_ROW, error: null })
    const from = jest.fn().mockReturnValueOnce({
      insert: jest.fn().mockReturnValue({ select: jest.fn().mockReturnValue({ single }) })
    })

    await createPlaylist({ from } as never, { name: "Empty" }, "user-1")

    expect(from).toHaveBeenCalledTimes(1)
  })

  it("constructs the response from inserted data without a third SELECT", async () => {
    const { supabase } = makeCreateSupabase()

    const result = await createPlaylist(
      supabase as never,
      { name: "Live Set", songs: ["song-1", "song-2"] },
      "user-1"
    )

    expect(result).toMatchObject({
      id: "playlist-1",
      name: "Live Set",
      description: undefined,
      visibility: "private",
      allowGuestEditing: false,
      shareCode: "ABCDEF123456",
      songs: ["song-1", "song-2"],
      createdAt: BASE_PLAYLIST_ROW.created_at,
      updatedAt: BASE_PLAYLIST_ROW.updated_at
    })
  })

  it("returns empty songs array when the playlist_songs insert fails", async () => {
    const { supabase } = makeCreateSupabase({
      songsResult: { error: new Error("FK violation") }
    })

    const result = await createPlaylist(
      supabase as never,
      { name: "Live Set", songs: ["song-1"] },
      "user-1"
    )

    expect(result.songs).toEqual([])
  })

  it("includes the share_code from the inserted row", async () => {
    const { supabase } = makeCreateSupabase()

    const result = await createPlaylist(supabase as never, { name: "Live Set" }, "user-1")

    expect(result.shareCode).toBe("ABCDEF123456")
  })

  it("retries without allow_guest_editing when the column is missing (code 42703)", async () => {
    const allowGuestError = { code: "42703", message: "column allow_guest_editing does not exist" }
    const playlistSingleFail = jest.fn().mockResolvedValue({ data: null, error: allowGuestError })
    const playlistSingleOk = jest.fn().mockResolvedValue({ data: BASE_PLAYLIST_ROW, error: null })

    const failInsert = jest
      .fn()
      .mockReturnValue({ select: jest.fn().mockReturnValue({ single: playlistSingleFail }) })
    const okInsert = jest
      .fn()
      .mockReturnValue({ select: jest.fn().mockReturnValue({ single: playlistSingleOk }) })

    const from = jest.fn()
      .mockReturnValueOnce({ insert: failInsert })  // first attempt → fails
      .mockReturnValueOnce({ insert: okInsert })    // retry without allow_guest_editing

    await createPlaylist({ from } as never, { name: "Live Set" }, "user-1")

    // Second insert should not include allow_guest_editing
    const retryArg = (okInsert.mock.calls[0] as [Record<string, unknown>])[0]
    expect(retryArg).not.toHaveProperty("allow_guest_editing")
  })
})

// ---------------------------------------------------------------------------
// updatePlaylist
// ---------------------------------------------------------------------------

describe("updatePlaylist", () => {
  afterEach(() => jest.clearAllMocks())

  function makeUpdateSupabase({
    currentData = { is_public: false, share_code: "ABCDEF123456" as string | null },
    updatedRow = makePlaylistWithSongsRow([{ song_id: "song-1", position: 0 }])
  } = {}) {
    // Pre-fetch chain: from("playlists").select().eq().single()
    const prefetchSingle = jest.fn().mockResolvedValue({ data: currentData, error: null })
    const prefetchEq = jest.fn().mockReturnValue({ single: prefetchSingle })
    const prefetchSelect = jest.fn().mockReturnValue({ eq: prefetchEq })

    // Update + RETURNING chain: from("playlists").update().eq().select().single()
    const updateSingle = jest.fn().mockResolvedValue({ data: updatedRow, error: null })
    const updateSelectFn = jest.fn().mockReturnValue({ single: updateSingle })
    const updateEq = jest.fn().mockReturnValue({ select: updateSelectFn })
    const updateFn = jest.fn().mockReturnValue({ eq: updateEq })

    const from = jest.fn()
      .mockReturnValueOnce({ select: prefetchSelect })  // pre-fetch
      .mockReturnValueOnce({ update: updateFn })        // update + RETURNING

    return { supabase: { from }, from, prefetchSelect, updateFn, updateSelectFn, updateSingle }
  }

  it("makes exactly 2 DB calls (pre-fetch + update-with-RETURNING, no separate SELECT)", async () => {
    const { supabase, from } = makeUpdateSupabase()

    await updatePlaylist(supabase as never, "playlist-1", { name: "Updated" })

    expect(from).toHaveBeenCalledTimes(2)
  })

  it("passes select clause to the update call so data is returned via RETURNING", async () => {
    const { supabase, updateSelectFn } = makeUpdateSupabase()

    await updatePlaylist(supabase as never, "playlist-1", { name: "Updated" })

    expect(updateSelectFn).toHaveBeenCalledWith(expect.stringContaining("playlist_songs"))
  })

  it("sends only the changed fields to the update", async () => {
    const { supabase, updateFn } = makeUpdateSupabase()

    await updatePlaylist(supabase as never, "playlist-1", { name: "New Name" })

    expect(updateFn).toHaveBeenCalledWith(expect.objectContaining({ name: "New Name" }))
    const payload = (updateFn.mock.calls[0] as [Record<string, unknown>])[0]
    expect(Object.keys(payload)).toEqual(["name"])
  })

  it("generates a share_code when transitioning to public with no existing code", async () => {
    const { supabase, updateFn } = makeUpdateSupabase({
      currentData: { is_public: false, share_code: null }
    })

    await updatePlaylist(supabase as never, "playlist-1", { visibility: "public" })

    const payload = (updateFn.mock.calls[0] as [Record<string, unknown>])[0]
    expect(payload.is_public).toBe(true)
    expect(typeof payload.share_code).toBe("string")
    expect((payload.share_code as string).length).toBe(12)
  })

  it("does not generate a share_code when the playlist already has one", async () => {
    const { supabase, updateFn } = makeUpdateSupabase({
      currentData: { is_public: false, share_code: "EXISTINGCODE" }
    })

    await updatePlaylist(supabase as never, "playlist-1", { visibility: "public" })

    const payload = (updateFn.mock.calls[0] as [Record<string, unknown>])[0]
    expect(payload).not.toHaveProperty("share_code")
  })

  it("returns the transformed Playlist with song IDs sorted by position", async () => {
    const row = makePlaylistWithSongsRow([
      { song_id: "song-b", position: 1 },
      { song_id: "song-a", position: 0 }
    ])
    const { supabase } = makeUpdateSupabase({ updatedRow: row })

    const result = await updatePlaylist(supabase as never, "playlist-1", { name: "Updated" })

    expect(result.songs).toEqual(["song-a", "song-b"])
  })

  it("throws when the pre-fetch query returns an error", async () => {
    const prefetchSingle = jest
      .fn()
      .mockResolvedValue({ data: null, error: new Error("not found") })
    const from = jest.fn().mockReturnValue({
      select: jest.fn().mockReturnValue({ eq: jest.fn().mockReturnValue({ single: prefetchSingle }) })
    })

    await expect(updatePlaylist({ from } as never, "playlist-1", { name: "x" })).rejects.toThrow(
      "not found"
    )
  })
})

// ---------------------------------------------------------------------------
// getPlaylistByShareCode
// ---------------------------------------------------------------------------

describe("getPlaylistByShareCode", () => {
  afterEach(() => jest.clearAllMocks())

  const DB_PLAYLIST = {
    ...BASE_PLAYLIST_ROW,
    is_public: true,
    playlist_songs: [
      { song_id: "song-2", position: 1, song: { ...SONG_ROW, id: "song-2", title: "Holy" } },
      { song_id: "song-1", position: 0, song: SONG_ROW }
    ]
  }

  function makeShareSupabase(result: { data: unknown; error: unknown }) {
    const single = jest.fn().mockResolvedValue(result)
    const eq = jest.fn().mockReturnValue({ single })
    const select = jest.fn().mockReturnValue({ eq })
    const from = jest.fn().mockReturnValue({ select })
    return { supabase: { from }, select, eq, single }
  }

  it("selects only the needed song columns (not *)", async () => {
    const { supabase, select } = makeShareSupabase({ data: DB_PLAYLIST, error: null })

    await getPlaylistByShareCode(supabase as never, "ABCDEF123456")

    const selectArg = (select.mock.calls[0] as [string])[0]
    expect(selectArg).toContain("song:songs (")
    expect(selectArg).toContain("id, title, artist")
    expect(selectArg).toContain("lyrics")
    expect(selectArg).not.toMatch(/song:songs \(\s*\*\s*\)/)
  })

  it("does not select all columns from playlist_songs (avoids *)", async () => {
    const { supabase, select } = makeShareSupabase({ data: DB_PLAYLIST, error: null })

    await getPlaylistByShareCode(supabase as never, "ABCDEF123456")

    const selectArg = (select.mock.calls[0] as [string])[0]
    // The junction table portion should only include song_id and position, not *
    expect(selectArg).toContain("song_id")
    expect(selectArg).toContain("position")
  })

  it("filters by share_code", async () => {
    const { supabase, eq } = makeShareSupabase({ data: DB_PLAYLIST, error: null })

    await getPlaylistByShareCode(supabase as never, "MYCODE")

    expect(eq).toHaveBeenCalledWith("share_code", "MYCODE")
  })

  it("sorts songs by position ascending before returning", async () => {
    const { supabase } = makeShareSupabase({ data: DB_PLAYLIST, error: null })

    const result = await getPlaylistByShareCode(supabase as never, "ABCDEF123456")

    expect(result?.songs[0].id).toBe("song-1")  // position 0
    expect(result?.songs[1].id).toBe("song-2")  // position 1
  })

  it("maps song fields to the frontend Song type", async () => {
    const { supabase } = makeShareSupabase({ data: DB_PLAYLIST, error: null })

    const result = await getPlaylistByShareCode(supabase as never, "ABCDEF123456")

    expect(result?.songs[0]).toMatchObject({
      id: "song-1",
      title: "Amazing Grace",
      artist: "Traditional",
      key: "C",
      bpm: 120,
      lyrics: "Amazing grace"
    })
  })

  it("returns null for PGRST116 (row not found)", async () => {
    const { supabase } = makeShareSupabase({ data: null, error: { code: "PGRST116" } })

    const result = await getPlaylistByShareCode(supabase as never, "MISSING")

    expect(result).toBeNull()
  })

  it("throws for non-PGRST116 errors", async () => {
    const { supabase } = makeShareSupabase({ data: null, error: new Error("timeout") })

    await expect(getPlaylistByShareCode(supabase as never, "CODE")).rejects.toThrow("timeout")
  })
})

// ---------------------------------------------------------------------------
// getPublicPlaylistByShareCode
// ---------------------------------------------------------------------------

describe("getPublicPlaylistByShareCode", () => {
  afterEach(() => jest.clearAllMocks())

  function makePublicShareSupabase(result: { data: unknown; error: unknown }) {
    const single = jest.fn().mockResolvedValue(result)
    const or = jest.fn().mockReturnValue({ single })
    const isPublicEq = jest.fn().mockReturnValue({ or })
    const shareCodeEq = jest.fn().mockReturnValue({ eq: isPublicEq })
    const select = jest.fn().mockReturnValue({ eq: shareCodeEq })
    const from = jest.fn().mockReturnValue({ select })
    return { supabase: { from }, select, shareCodeEq, isPublicEq, or }
  }

  it("filters by share_code, is_public, and expiry", async () => {
    const DB = {
      ...BASE_PLAYLIST_ROW,
      is_public: true,
      playlist_songs: []
    }
    const { supabase, shareCodeEq, isPublicEq, or } = makePublicShareSupabase({
      data: DB,
      error: null
    })

    await getPublicPlaylistByShareCode(supabase as never, "MYCODE")

    expect(shareCodeEq).toHaveBeenCalledWith("share_code", "MYCODE")
    expect(isPublicEq).toHaveBeenCalledWith("is_public", true)
    expect(or).toHaveBeenCalledWith("share_expires_at.is.null,share_expires_at.gt.now()")
  })

  it("selects specific song columns (not *)", async () => {
    const DB = { ...BASE_PLAYLIST_ROW, is_public: true, playlist_songs: [] }
    const { supabase, select } = makePublicShareSupabase({ data: DB, error: null })

    await getPublicPlaylistByShareCode(supabase as never, "MYCODE")

    const selectArg = (select.mock.calls[0] as [string])[0]
    expect(selectArg).toContain("song:songs (")
    expect(selectArg).not.toMatch(/song:songs \(\s*\*\s*\)/)
  })

  it("returns null for PGRST116", async () => {
    const { supabase } = makePublicShareSupabase({ data: null, error: { code: "PGRST116" } })

    const result = await getPublicPlaylistByShareCode(supabase as never, "MISSING")

    expect(result).toBeNull()
  })
})

// ---------------------------------------------------------------------------
// getPlaylistWithSongs
// ---------------------------------------------------------------------------

describe("getPlaylistWithSongs", () => {
  afterEach(() => jest.clearAllMocks())

  function makeDetailSupabase(result: { data: unknown; error: unknown }) {
    const single = jest.fn().mockResolvedValue(result)
    const eq = jest.fn().mockReturnValue({ single })
    const select = jest.fn().mockReturnValue({ eq })
    const from = jest.fn().mockReturnValue({ select })
    return { supabase: { from }, select, eq }
  }

  it("selects specific song columns (not *)", async () => {
    const DB = {
      ...BASE_PLAYLIST_ROW,
      playlist_songs: [{ song_id: "s1", position: 0, song: SONG_ROW }]
    }
    const { supabase, select } = makeDetailSupabase({ data: DB, error: null })

    await getPlaylistWithSongs(supabase as never, "playlist-1")

    const selectArg = (select.mock.calls[0] as [string])[0]
    expect(selectArg).toContain("song:songs (")
    expect(selectArg).toContain("lyrics")
    expect(selectArg).not.toMatch(/song:songs \(\s*\*\s*\)/)
  })

  it("filters by playlist ID", async () => {
    const DB = { ...BASE_PLAYLIST_ROW, playlist_songs: [] }
    const { supabase, eq } = makeDetailSupabase({ data: DB, error: null })

    await getPlaylistWithSongs(supabase as never, "playlist-1")

    expect(eq).toHaveBeenCalledWith("id", "playlist-1")
  })

  it("returns songs sorted by position", async () => {
    const DB = {
      ...BASE_PLAYLIST_ROW,
      playlist_songs: [
        { song_id: "s-b", position: 2, song: { ...SONG_ROW, id: "s-b" } },
        { song_id: "s-a", position: 0, song: { ...SONG_ROW, id: "s-a" } },
        { song_id: "s-c", position: 1, song: { ...SONG_ROW, id: "s-c" } }
      ]
    }
    const { supabase } = makeDetailSupabase({ data: DB, error: null })

    const result = await getPlaylistWithSongs(supabase as never, "playlist-1")

    expect(result?.songs.map((s) => s.id)).toEqual(["s-a", "s-c", "s-b"])
  })

  it("returns null for PGRST116 (row not found)", async () => {
    const { supabase } = makeDetailSupabase({ data: null, error: { code: "PGRST116" } })

    const result = await getPlaylistWithSongs(supabase as never, "missing-id")

    expect(result).toBeNull()
  })

  it("throws for non-PGRST116 errors", async () => {
    const { supabase } = makeDetailSupabase({ data: null, error: new Error("db error") })

    await expect(getPlaylistWithSongs(supabase as never, "playlist-1")).rejects.toThrow("db error")
  })
})
