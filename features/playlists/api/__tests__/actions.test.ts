import { revalidatePath } from "next/cache"
import { createClient } from "@/lib/supabase/server"
import {
  getPlaylists as getPlaylistsApi,
  getPlaylistsAllBuckets as getPlaylistsAllBucketsApi,
  getPlaylistWithSongs as getPlaylistWithSongsApi,
  addSongToPlaylist as addSongToPlaylistApi,
  addSongsToPlaylist as addSongsToPlaylistApi,
  createPlaylist as createPlaylistApi,
  deletePlaylist as deletePlaylistApi,
  removeSongFromPlaylist as removeSongFromPlaylistApi,
  reorderPlaylistSongs as reorderPlaylistSongsApi,
  updatePlaylist as updatePlaylistApi
} from "../playlistsApi"
import {
  getPlaylistsAction,
  getPlaylistsAllBucketsAction,
  getPlaylistWithSongsAction,
  addSongToPlaylistAction,
  addSongsToPlaylistAction,
  createPlaylistAction,
  deletePlaylistAction,
  removeSongFromPlaylistAction,
  reorderPlaylistSongsAction,
  updatePlaylistAction
} from "../actions"

jest.mock("next/cache", () => ({
  revalidatePath: jest.fn()
}))

jest.mock("@/lib/supabase/server", () => ({
  createClient: jest.fn()
}))

jest.mock("../playlistsApi", () => ({
  getPlaylists: jest.fn(),
  getPlaylistsAllBuckets: jest.fn(),
  getPlaylistWithSongs: jest.fn(),
  createPlaylist: jest.fn(),
  updatePlaylist: jest.fn(),
  deletePlaylist: jest.fn(),
  addSongToPlaylist: jest.fn(),
  addSongsToPlaylist: jest.fn(),
  removeSongFromPlaylist: jest.fn(),
  reorderPlaylistSongs: jest.fn()
}))

describe("playlist actions", () => {
  const mockSupabase = { id: "supabase-client" }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("creates a playlist", async () => {
    const playlistData = { name: "Setlist", songs: ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"], visibility: "public" as const }
    const createdPlaylist = {
      id: "11111111-1111-4111-8111-111111111111",
      ...playlistData,
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-01T00:00:00.000Z"
    }
    ;(createPlaylistApi as jest.Mock).mockResolvedValue(createdPlaylist)

    const result = await createPlaylistAction(playlistData, "cccccccc-cccc-4ccc-8ccc-cccccccccccc")

    expect(result).toEqual(createdPlaylist)
    expect(createPlaylistApi).toHaveBeenCalledWith(mockSupabase, playlistData, "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
  })

  it("updates a playlist", async () => {
    const updatedPlaylist = {
      id: "11111111-1111-4111-8111-111111111111",
      name: "Updated",
      songs: [],
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-02T00:00:00.000Z"
    }
    ;(updatePlaylistApi as jest.Mock).mockResolvedValue(updatedPlaylist)

    const result = await updatePlaylistAction("11111111-1111-4111-8111-111111111111", { name: "Updated" })

    expect(result).toEqual(updatedPlaylist)
    expect(updatePlaylistApi).toHaveBeenCalledWith(mockSupabase, "11111111-1111-4111-8111-111111111111", { name: "Updated" })
    expect(revalidatePath).not.toHaveBeenCalled()
  })

  it("updates a playlist with shareCode and revalidates shared route", async () => {
    const updatedPlaylist = {
      id: "11111111-1111-4111-8111-111111111111",
      name: "Updated",
      songs: [],
      shareCode: "ABC123",
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-02T00:00:00.000Z"
    }
    ;(updatePlaylistApi as jest.Mock).mockResolvedValue(updatedPlaylist)

    await updatePlaylistAction("11111111-1111-4111-8111-111111111111", { name: "Updated" })

    expect(revalidatePath).toHaveBeenCalledWith("/shared/ABC123")
  })

  it("deletes a playlist", async () => {
    await deletePlaylistAction("22222222-2222-4222-8222-222222222222")

    expect(deletePlaylistApi).toHaveBeenCalledWith(mockSupabase, "22222222-2222-4222-8222-222222222222")
  })

  it("adds a song to a playlist", async () => {
    await addSongToPlaylistAction("11111111-1111-4111-8111-111111111111", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")

    expect(addSongToPlaylistApi).toHaveBeenCalledWith(mockSupabase, "11111111-1111-4111-8111-111111111111", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
  })

  it("removes a song from a playlist", async () => {
    await removeSongFromPlaylistAction("11111111-1111-4111-8111-111111111111", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")

    expect(removeSongFromPlaylistApi).toHaveBeenCalledWith(mockSupabase, "11111111-1111-4111-8111-111111111111", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
  })

  it("reorders songs in a playlist without shareCode and skips shared revalidation", async () => {
    const updates = [
      { songId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", position: 0 },
      { songId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", position: 1 }
    ]

    await reorderPlaylistSongsAction("11111111-1111-4111-8111-111111111111", updates)

    expect(reorderPlaylistSongsApi).toHaveBeenCalledWith(mockSupabase, "11111111-1111-4111-8111-111111111111", updates)
    expect(revalidatePath).not.toHaveBeenCalled()
  })

  it("reorders songs in a playlist with shareCode and revalidates shared route", async () => {
    const updates = [
      { songId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", position: 0 },
      { songId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", position: 1 }
    ]

    await reorderPlaylistSongsAction("11111111-1111-4111-8111-111111111111", updates, "SHARE123")

    expect(revalidatePath).toHaveBeenCalledWith("/shared/SHARE123")
  })
})

describe("getPlaylistsAction", () => {
  const mockSupabase = { id: "supabase-client" }
  const context = { type: "personal" as const, userId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc" }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("fetches playlists for the given context", async () => {
    const playlists = [{ id: "33333333-3333-4333-8333-333333333333", name: "Setlist" }]
    ;(getPlaylistsApi as jest.Mock).mockResolvedValue(playlists)

    const result = await getPlaylistsAction(context)

    expect(getPlaylistsApi).toHaveBeenCalledWith(mockSupabase, context)
    expect(result).toEqual(playlists)
  })
})

describe("getPlaylistsAllBucketsAction", () => {
  const mockSupabase = { id: "supabase-client" }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("fetches playlists across all buckets for a user", async () => {
    const playlists = [{ id: "44444444-4444-4444-8444-444444444444", name: "All Songs" }]
    ;(getPlaylistsAllBucketsApi as jest.Mock).mockResolvedValue(playlists)

    const result = await getPlaylistsAllBucketsAction("cccccccc-cccc-4ccc-8ccc-cccccccccccc", ["dddddddd-dddd-4ddd-8ddd-dddddddddddd"])

    expect(getPlaylistsAllBucketsApi).toHaveBeenCalledWith(mockSupabase, "cccccccc-cccc-4ccc-8ccc-cccccccccccc", ["dddddddd-dddd-4ddd-8ddd-dddddddddddd"])
    expect(result).toEqual(playlists)
  })
})

describe("getPlaylistWithSongsAction", () => {
  const mockSupabase = { id: "supabase-client" }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("fetches a single playlist with its songs", async () => {
    const playlist = { id: "33333333-3333-4333-8333-333333333333", name: "Setlist", songs: [] }
    ;(getPlaylistWithSongsApi as jest.Mock).mockResolvedValue(playlist)

    const result = await getPlaylistWithSongsAction("33333333-3333-4333-8333-333333333333")

    expect(getPlaylistWithSongsApi).toHaveBeenCalledWith(mockSupabase, "33333333-3333-4333-8333-333333333333")
    expect(result).toEqual(playlist)
  })
})

describe("input validation", () => {
  const mockSupabase = { id: "supabase-client" }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("rejects a non-UUID playlist id", async () => {
    await expect(deletePlaylistAction("not-a-uuid")).rejects.toThrow()
    expect(deletePlaylistApi).not.toHaveBeenCalled()
  })

  it("rejects a non-UUID song id when adding to a playlist", async () => {
    await expect(
      addSongToPlaylistAction("11111111-1111-4111-8111-111111111111", "not-a-uuid")
    ).rejects.toThrow()
    expect(addSongToPlaylistApi).not.toHaveBeenCalled()
  })

  it("rejects an empty playlist name on create", async () => {
    await expect(
      createPlaylistAction({ name: "   " }, "cccccccc-cccc-4ccc-8ccc-cccccccccccc")
    ).rejects.toThrow()
    expect(createPlaylistApi).not.toHaveBeenCalled()
  })

  it("rejects negative positions when reordering", async () => {
    await expect(
      reorderPlaylistSongsAction("11111111-1111-4111-8111-111111111111", [
        { songId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", position: -1 }
      ])
    ).rejects.toThrow()
    expect(reorderPlaylistSongsApi).not.toHaveBeenCalled()
  })
})

describe("addSongsToPlaylistAction", () => {
  const mockSupabase = { id: "supabase-client" }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("adds multiple songs to a playlist", async () => {
    await addSongsToPlaylistAction("33333333-3333-4333-8333-333333333333", ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"])

    expect(addSongsToPlaylistApi).toHaveBeenCalledWith(mockSupabase, "33333333-3333-4333-8333-333333333333", ["aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"])
  })
})
