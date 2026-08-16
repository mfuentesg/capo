import { formatCompactRelativeTime } from "../format-relative-time"

describe("formatCompactRelativeTime", () => {
  const reference = new Date("2026-02-15T00:00:00.000Z")

  it("returns 'today' for the same day", () => {
    expect(formatCompactRelativeTime("2026-02-15", reference)).toBe("today")
  })

  it("formats a few days ago in days", () => {
    expect(formatCompactRelativeTime("2026-02-12", reference)).toBe("3d ago")
  })

  it("formats two weeks ago in weeks", () => {
    expect(formatCompactRelativeTime("2026-02-01", reference)).toBe("2w ago")
  })

  it("formats a month and a half ago in months", () => {
    expect(formatCompactRelativeTime("2026-01-01", reference)).toBe("1mo ago")
  })

  it("formats over a year ago in years", () => {
    expect(formatCompactRelativeTime("2024-01-01", reference)).toBe("2y ago")
  })
})
