import { generateToken, hashToken, parseBearer, TOKEN_PREFIX } from "../lib/token"

describe("token utilities", () => {
  it("generates a prefixed token whose hash is the sha256 hex of the token", () => {
    const { token, hash } = generateToken()
    expect(token.startsWith(TOKEN_PREFIX)).toBe(true)
    expect(token.length).toBeGreaterThan(TOKEN_PREFIX.length + 40)
    expect(hash).toMatch(/^[0-9a-f]{64}$/)
    expect(hashToken(token)).toBe(hash)
  })

  it("never repeats", () => {
    expect(generateToken().token).not.toBe(generateToken().token)
  })

  it("parses a bearer header", () => {
    expect(parseBearer("Bearer capo_abc")).toBe("capo_abc")
    expect(parseBearer("bearer capo_abc")).toBe("capo_abc")
  })

  it.each([null, "", "Bearer", "Bearer ", "Basic abc", "capo_abc", "Bearer a b"])(
    "rejects %p",
    (h) => expect(parseBearer(h)).toBeNull()
  )
})
