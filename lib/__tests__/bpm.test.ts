import { getBpmTier } from "../bpm"

describe("getBpmTier", () => {
  it("uses slow < 90, medium 90–120, fast > 120", () => {
    expect(getBpmTier(89)).toBe("slow")
    expect(getBpmTier(90)).toBe("medium")
    expect(getBpmTier(120)).toBe("medium")
    expect(getBpmTier(121)).toBe("fast")
  })
})
