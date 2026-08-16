import { getFrequencyColorClasses } from "../badge-colors"

describe("getFrequencyColorClasses", () => {
  it("returns a warning-colored style when the song was recently played", () => {
    expect(getFrequencyColorClasses(true)).toContain("amber")
  })

  it("returns a muted style when the song was not recently played", () => {
    const classes = getFrequencyColorClasses(false)
    expect(classes).toContain("text-muted-foreground")
    expect(classes).not.toContain("amber")
  })
})
