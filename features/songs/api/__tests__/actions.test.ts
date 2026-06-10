import { createClient } from "@/lib/supabase/server"
import {
  getSongs as getSongsApi,
  getSongsAllBuckets as getSongsAllBucketsApi,
  createSong as createSongApi,
  deleteSong as deleteSongApi,
  updateSong as updateSongApi,
  transferSongToTeam as transferSongToTeamApi
} from "../songsApi"
import {
  getAllUserSongSettings,
  getUserSongSettings as getUserSongSettingsApi,
  upsertUserSongSettings as upsertUserSongSettingsApi
} from "../user-song-settings-api"
import {
  getUserProfileData as getUserProfileDataApi,
  upsertUserPreferences as upsertUserPreferencesApi
} from "../user-preferences-api"
import {
  getSongsAction,
  getSongsAllBucketsAction,
  createSongAction,
  deleteSongAction,
  getAllUserSongSettingsAction,
  getUserSongSettingsAction,
  upsertUserSongSettingsAction,
  getUserProfileDataAction,
  upsertUserPreferencesAction,
  transferSongToTeamAction,
  updateSongAction
} from "../actions"

jest.mock("@/lib/supabase/server", () => ({
  createClient: jest.fn()
}))

jest.mock("../songsApi", () => ({
  getSongs: jest.fn(),
  getSongsAllBuckets: jest.fn(),
  createSong: jest.fn(),
  updateSong: jest.fn(),
  deleteSong: jest.fn(),
  transferSongToTeam: jest.fn()
}))

jest.mock("../user-song-settings-api", () => ({
  getAllUserSongSettings: jest.fn(),
  getUserSongSettings: jest.fn(),
  upsertUserSongSettings: jest.fn()
}))

jest.mock("../user-preferences-api", () => ({
  getUserProfileData: jest.fn(),
  upsertUserPreferences: jest.fn()
}))

jest.mock("../tags-api", () => ({
  getTagAssignmentsForSongs: jest.fn().mockResolvedValue(new Map()),
  getTagsForContext: jest.fn().mockResolvedValue([]),
  getTagsForUser: jest.fn().mockResolvedValue([]),
  createTag: jest.fn(),
  deleteTag: jest.fn(),
  setSongTags: jest.fn()
}))

describe("song actions", () => {
  const mockSupabase = { id: "supabase-client" }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("creates a song", async () => {
    const song = {
      id: "song-1",
      title: "Amazing Grace",
      artist: "Traditional",
      key: "C",
      bpm: 120,
      lyrics: "",
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-01T00:00:00.000Z"
    }
    ;(createSongApi as jest.Mock).mockResolvedValue(song)

    const result = await createSongAction({ title: "Amazing Grace" }, "user-1")

    expect(result).toEqual(song)
    expect(createSongApi).toHaveBeenCalledWith(mockSupabase, { title: "Amazing Grace" }, "user-1")
  })

  it("updates a song without revalidating routes", async () => {
    const updatedSong = {
      id: "song-1",
      title: "Updated Song",
      artist: "",
      key: "",
      bpm: 0,
      lyrics: "",
      createdAt: "2026-01-01T00:00:00.000Z",
      updatedAt: "2026-01-02T00:00:00.000Z"
    }
    ;(updateSongApi as jest.Mock).mockResolvedValue(updatedSong)

    const result = await updateSongAction("song-1", { title: "Updated Song" })

    expect(result).toEqual(updatedSong)
    expect(updateSongApi).toHaveBeenCalledWith(mockSupabase, "song-1", { title: "Updated Song" })
  })

  it("deletes a song", async () => {
    await deleteSongAction("song-4")

    expect(deleteSongApi).toHaveBeenCalledWith(mockSupabase, "song-4")
  })
})

describe("transferSongToTeamAction", () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it("throws Unauthorized when no user is authenticated", async () => {
    ;(createClient as jest.Mock).mockResolvedValue({
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: null } }) }
    })

    await expect(transferSongToTeamAction("song-1", "team-1")).rejects.toThrow("Unauthorized")
    expect(transferSongToTeamApi).not.toHaveBeenCalled()
  })

  it("transfers song to team", async () => {
    const mockSupabase = {
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: { id: "user-1" } } }) }
    }
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    ;(transferSongToTeamApi as jest.Mock).mockResolvedValue(undefined)

    await transferSongToTeamAction("song-1", "team-1")

    expect(transferSongToTeamApi).toHaveBeenCalledWith(mockSupabase, "song-1", "team-1")
  })
})

describe("getAllUserSongSettingsAction", () => {
  it("returns empty array when no user is authenticated", async () => {
    ;(createClient as jest.Mock).mockResolvedValue({
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: null } }) }
    })

    const result = await getAllUserSongSettingsAction()

    expect(result).toEqual([])
  })

  it("calls getAllUserSongSettings with supabase and userId", async () => {
    const mockSupabase = {
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: { id: "user-1" } } }) }
    }
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    ;(getAllUserSongSettings as jest.Mock).mockResolvedValue([
      { songId: "song-1", capo: 2, transpose: 0, fontSize: undefined }
    ])

    const result = await getAllUserSongSettingsAction()

    expect(getAllUserSongSettings).toHaveBeenCalledWith(mockSupabase, "user-1")
    expect(result).toEqual([{ songId: "song-1", capo: 2, transpose: 0, fontSize: undefined }])
  })
})

describe("getSongsAction", () => {
  const mockSupabase = { id: "supabase-client" }
  const context = { type: "personal" as const, userId: "user-1" }
  const songs = [{ id: "song-1", title: "Song", artist: "", key: "C", bpm: 120 }]
  const settings = [{ songId: "song-1", capo: 2, transpose: 0 }]

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("fetches songs and settings in parallel and merges them", async () => {
    ;(getSongsApi as jest.Mock).mockResolvedValue(songs)
    ;(getAllUserSongSettings as jest.Mock).mockResolvedValue(settings)

    const result = await getSongsAction(context)

    expect(getSongsApi).toHaveBeenCalledWith(mockSupabase, context, undefined)
    expect(getAllUserSongSettings).toHaveBeenCalledWith(mockSupabase, "user-1")
    expect(result).toEqual([{ ...songs[0], userSettings: settings[0] }])
  })

  it("sets userSettings to null for songs without saved settings", async () => {
    ;(getSongsApi as jest.Mock).mockResolvedValue(songs)
    ;(getAllUserSongSettings as jest.Mock).mockResolvedValue([])

    const result = await getSongsAction(context)

    expect(result).toEqual([{ ...songs[0], userSettings: null }])
  })
})

describe("getSongsAllBucketsAction", () => {
  const mockSupabase = { id: "supabase-client" }
  const songs = [{ id: "song-2", title: "Another", artist: "", key: "G", bpm: 90 }]

  beforeEach(() => {
    jest.clearAllMocks()
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
  })

  it("fetches all-bucket songs with settings merged", async () => {
    const settings = [{ songId: "song-2", capo: 0, transpose: 1 }]
    ;(getSongsAllBucketsApi as jest.Mock).mockResolvedValue(songs)
    ;(getAllUserSongSettings as jest.Mock).mockResolvedValue(settings)

    const result = await getSongsAllBucketsAction("user-1", ["team-1"], [
      { id: "team-1", name: "Band", icon: null }
    ])

    expect(getSongsAllBucketsApi).toHaveBeenCalledWith(
      mockSupabase,
      "user-1",
      ["team-1"],
      [{ id: "team-1", name: "Band", icon: null }],
      undefined
    )
    expect(result).toEqual([{ ...songs[0], userSettings: settings[0] }])
  })
})

describe("getUserSongSettingsAction", () => {
  it("returns null when no user is authenticated", async () => {
    ;(createClient as jest.Mock).mockResolvedValue({
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: null } }) }
    })

    const result = await getUserSongSettingsAction("song-1")

    expect(result).toBeNull()
    expect(getUserSongSettingsApi).not.toHaveBeenCalled()
  })

  it("calls getUserSongSettings with supabase, userId, and songId", async () => {
    const settings = { songId: "song-1", capo: 1, transpose: 0 }
    const mockSupabase = {
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: { id: "user-1" } } }) }
    }
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    ;(getUserSongSettingsApi as jest.Mock).mockResolvedValue(settings)

    const result = await getUserSongSettingsAction("song-1")

    expect(getUserSongSettingsApi).toHaveBeenCalledWith(mockSupabase, "user-1", "song-1")
    expect(result).toEqual(settings)
  })
})

describe("upsertUserSongSettingsAction", () => {
  it("throws Unauthorized when no user is authenticated", async () => {
    ;(createClient as jest.Mock).mockResolvedValue({
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: null } }) }
    })

    await expect(
      upsertUserSongSettingsAction("song-1", { capo: 2, transpose: 0 })
    ).rejects.toThrow("Unauthorized")
    expect(upsertUserSongSettingsApi).not.toHaveBeenCalled()
  })

  it("calls upsertUserSongSettings with supabase, userId, songId, and settings", async () => {
    const settings = { songId: "song-1", capo: 2, transpose: 0 }
    const mockSupabase = {
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: { id: "user-1" } } }) }
    }
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    ;(upsertUserSongSettingsApi as jest.Mock).mockResolvedValue(settings)

    const result = await upsertUserSongSettingsAction("song-1", { capo: 2, transpose: 0 })

    expect(upsertUserSongSettingsApi).toHaveBeenCalledWith(mockSupabase, "user-1", "song-1", {
      capo: 2,
      transpose: 0
    })
    expect(result).toEqual(settings)
  })
})

describe("getUserProfileDataAction", () => {
  it("returns null when no session exists", async () => {
    ;(createClient as jest.Mock).mockResolvedValue({
      auth: { getSession: jest.fn().mockResolvedValue({ data: { session: null } }) }
    })

    const result = await getUserProfileDataAction()

    expect(result).toBeNull()
    expect(getUserProfileDataApi).not.toHaveBeenCalled()
  })

  it("calls getUserProfileData with supabase and userId from session", async () => {
    const profileData = { preferences: { lyricsColumns: 2 as const }, songSettings: [] }
    const mockSupabase = {
      auth: {
        getSession: jest
          .fn()
          .mockResolvedValue({ data: { session: { user: { id: "user-1" } } } })
      }
    }
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    ;(getUserProfileDataApi as jest.Mock).mockResolvedValue(profileData)

    const result = await getUserProfileDataAction()

    expect(getUserProfileDataApi).toHaveBeenCalledWith(mockSupabase, "user-1")
    expect(result).toEqual(profileData)
  })
})

describe("upsertUserPreferencesAction", () => {
  it("returns null when no user is authenticated", async () => {
    ;(createClient as jest.Mock).mockResolvedValue({
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: null } }) }
    })

    const result = await upsertUserPreferencesAction({ lyricsColumns: 2 })

    expect(result).toBeNull()
    expect(upsertUserPreferencesApi).not.toHaveBeenCalled()
  })

  it("calls upsertUserPreferences with supabase, userId, and preferences", async () => {
    const prefs = { lyricsColumns: 1 as const }
    const mockSupabase = {
      auth: { getUser: jest.fn().mockResolvedValue({ data: { user: { id: "user-1" } } }) }
    }
    ;(createClient as jest.Mock).mockResolvedValue(mockSupabase)
    ;(upsertUserPreferencesApi as jest.Mock).mockResolvedValue(prefs)

    const result = await upsertUserPreferencesAction(prefs)

    expect(upsertUserPreferencesApi).toHaveBeenCalledWith(mockSupabase, "user-1", prefs)
    expect(result).toEqual(prefs)
  })
})
