import { playlistsKeys } from "../query-keys"

describe("playlistsKeys", () => {
  it("lists returns base list key", () => {
    expect(playlistsKeys.lists()).toEqual(["playlists", "list"])
  })

  it("list returns key scoped to context", () => {
    const context = { type: "personal" as const, userId: "u1" }
    expect(playlistsKeys.list(context)).toEqual(["playlists", "list", context])
  })

  it("listAll returns key scoped to userId", () => {
    expect(playlistsKeys.listAll("u1")).toEqual(["playlists", "list", "all", "u1"])
  })

  it("details returns base detail key", () => {
    expect(playlistsKeys.details()).toEqual(["playlists", "detail"])
  })

  it("detail returns key scoped to playlist id", () => {
    expect(playlistsKeys.detail("p1")).toEqual(["playlists", "detail", "p1"])
  })

  it("public returns base public key", () => {
    expect(playlistsKeys.public()).toEqual(["playlists", "public"])
  })

  it("publicByCode returns key scoped to share code", () => {
    expect(playlistsKeys.publicByCode("ABC123")).toEqual(["playlists", "public", "ABC123"])
  })

  it("frequencies returns base frequencies key", () => {
    expect(playlistsKeys.frequencies()).toEqual(["playlists", "frequencies"])
  })

  it("frequency returns key scoped to context", () => {
    const context = { type: "personal" as const, userId: "u1" }
    expect(playlistsKeys.frequency(context)).toEqual(["playlists", "frequencies", context])
  })
})
