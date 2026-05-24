import { songsKeys } from "../query-keys"

describe("songsKeys", () => {
  it("lists returns base list key", () => {
    expect(songsKeys.lists()).toEqual(["songs", "list"])
  })

  it("list returns key scoped to context", () => {
    const context = { type: "personal" as const, userId: "u1" }
    expect(songsKeys.list(context)).toEqual(["songs", "list", context, ""])
  })

  it("list includes searchQuery when provided", () => {
    const context = { type: "personal" as const, userId: "u1" }
    expect(songsKeys.list(context, "grace")).toEqual(["songs", "list", context, "grace"])
  })

  it("listAll returns key scoped to userId and teamIds", () => {
    expect(songsKeys.listAll("u1", [])).toEqual(["songs", "list", "all", "u1", [], ""])
  })

  it("listAll includes teamIds in the key", () => {
    expect(songsKeys.listAll("u1", ["t1", "t2"])).toEqual([
      "songs",
      "list",
      "all",
      "u1",
      ["t1", "t2"],
      ""
    ])
  })

  it("listAll includes searchQuery when provided", () => {
    expect(songsKeys.listAll("u1", [], "grace")).toEqual(["songs", "list", "all", "u1", [], "grace"])
  })

  it("details returns base detail key", () => {
    expect(songsKeys.details()).toEqual(["songs", "detail"])
  })

  it("detail returns key scoped to song id", () => {
    expect(songsKeys.detail("s1")).toEqual(["songs", "detail", "s1"])
  })

  it("allUserSettings returns all user-settings key", () => {
    expect(songsKeys.allUserSettings()).toEqual(["songs", "user-settings", "all"])
  })

  it("userSettings returns key scoped to song id", () => {
    expect(songsKeys.userSettings("s1")).toEqual(["songs", "detail", "s1", "user-settings"])
  })

  it("userPreferences returns user-preferences key", () => {
    expect(songsKeys.userPreferences()).toEqual(["songs", "user-preferences"])
  })
})
