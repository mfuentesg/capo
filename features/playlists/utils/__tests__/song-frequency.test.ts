import { computeSongFrequencies, isRecentlyPlayed, getFrequencyBadgeInfo } from "../song-frequency"

describe("computeSongFrequencies", () => {
  it("counts one play and uses the playlist date as lastPlayedDate", () => {
    const result = computeSongFrequencies([
      { songId: "song-1", date: "2026-01-01", createdAt: "2026-01-01T00:00:00.000Z" }
    ])

    expect(result.get("song-1")).toEqual({ count: 1, lastPlayedDate: "2026-01-01" })
  })

  it("falls back to createdAt when the playlist date is null", () => {
    const result = computeSongFrequencies([
      { songId: "song-1", date: null, createdAt: "2026-01-05T00:00:00.000Z" }
    ])

    expect(result.get("song-1")).toEqual({ count: 1, lastPlayedDate: "2026-01-05T00:00:00.000Z" })
  })

  it("counts multiple appearances of the same song across playlists", () => {
    const result = computeSongFrequencies([
      { songId: "song-1", date: "2026-01-01", createdAt: "2026-01-01T00:00:00.000Z" },
      { songId: "song-1", date: "2026-01-15", createdAt: "2026-01-15T00:00:00.000Z" }
    ])

    expect(result.get("song-1")?.count).toBe(2)
  })

  it("keeps the most recent date as lastPlayedDate regardless of row order", () => {
    const result = computeSongFrequencies([
      { songId: "song-1", date: "2026-01-15", createdAt: "2026-01-15T00:00:00.000Z" },
      { songId: "song-1", date: "2026-01-01", createdAt: "2026-01-01T00:00:00.000Z" }
    ])

    expect(result.get("song-1")?.lastPlayedDate).toBe("2026-01-15")
  })

  it("keeps separate entries per song", () => {
    const result = computeSongFrequencies([
      { songId: "song-1", date: "2026-01-01", createdAt: "2026-01-01T00:00:00.000Z" },
      { songId: "song-2", date: "2026-01-02", createdAt: "2026-01-02T00:00:00.000Z" }
    ])

    expect(result.size).toBe(2)
    expect(result.get("song-2")).toEqual({ count: 1, lastPlayedDate: "2026-01-02" })
  })
})

describe("isRecentlyPlayed", () => {
  it("returns false when the song has never been played", () => {
    expect(isRecentlyPlayed(null, new Date("2026-01-15"))).toBe(false)
  })

  it("returns true when last played within the 2-week window", () => {
    expect(isRecentlyPlayed("2026-01-05", new Date("2026-01-15"))).toBe(true)
  })

  it("returns false when last played outside the 2-week window", () => {
    expect(isRecentlyPlayed("2026-01-01", new Date("2026-01-20"))).toBe(false)
  })

  it("returns true exactly at the window boundary", () => {
    expect(isRecentlyPlayed("2026-01-01", new Date("2026-01-15"))).toBe(true)
  })
})

describe("getFrequencyBadgeInfo", () => {
  const reference = new Date("2026-02-15")

  it("returns undefined when the song has no recorded plays", () => {
    const frequencies = new Map()
    expect(getFrequencyBadgeInfo("song-1", frequencies, reference)).toBeUndefined()
  })

  it("returns count, recency flag, and a compact last-played label", () => {
    const frequencies = new Map([["song-1", { count: 3, lastPlayedDate: "2026-02-10" }]])

    expect(getFrequencyBadgeInfo("song-1", frequencies, reference)).toEqual({
      count: 3,
      isRecentlyPlayed: true,
      lastPlayedLabel: "5d ago"
    })
  })

  it("flags isRecentlyPlayed as false outside the repetition window", () => {
    const frequencies = new Map([["song-1", { count: 1, lastPlayedDate: "2026-01-01" }]])

    expect(getFrequencyBadgeInfo("song-1", frequencies, reference)?.isRecentlyPlayed).toBe(false)
  })
})
