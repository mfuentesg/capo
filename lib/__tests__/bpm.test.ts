import { BPM_MAX, BPM_MIN, clampBpm, getBpmTier } from "../bpm"

describe("getBpmTier", () => {
  it("uses slow < 90, medium 90–120, fast > 120", () => {
    expect(getBpmTier(89)).toBe("slow")
    expect(getBpmTier(90)).toBe("medium")
    expect(getBpmTier(120)).toBe("medium")
    expect(getBpmTier(121)).toBe("fast")
  })
})

describe("clampBpm", () => {
  it("keeps the editable range in sync with the song form", () => {
    expect(clampBpm(10)).toBe(BPM_MIN)
    expect(clampBpm(500)).toBe(BPM_MAX)
    expect(clampBpm(120)).toBe(120)
  })
})
