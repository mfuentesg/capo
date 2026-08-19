import { validateCifraClubUrl } from "../validate-url"

describe("validateCifraClubUrl", () => {
  it("accepts a valid cifraclub.com URL", () => {
    const result = validateCifraClubUrl("https://www.cifraclub.com/israel-houghton/eres-fiel/")
    expect(result.ok).toBe(true)
  })

  it("strips the www. prefix before matching the allowlist", () => {
    const result = validateCifraClubUrl("https://cifraclub.com/israel-houghton/eres-fiel/")
    expect(result.ok).toBe(true)
  })

  it("rejects an unparseable URL", () => {
    const result = validateCifraClubUrl("not a url")
    expect(result).toEqual({ ok: false, error: "invalid_url" })
  })

  it("rejects non-https URLs", () => {
    const result = validateCifraClubUrl("http://www.cifraclub.com/israel-houghton/eres-fiel/")
    expect(result).toEqual({ ok: false, error: "invalid_url" })
  })

  it("rejects an unrelated host", () => {
    const result = validateCifraClubUrl("https://example.com/song")
    expect(result).toEqual({ ok: false, error: "wrong_host" })
  })

  it("rejects a spoofed subdomain that merely contains the allowed host", () => {
    const result = validateCifraClubUrl("https://cifraclub.com.evil.example/song")
    expect(result).toEqual({ ok: false, error: "wrong_host" })
  })

  it("rejects a host that merely starts with the allowed host", () => {
    const result = validateCifraClubUrl("https://cifraclub.com.br/song")
    expect(result).toEqual({ ok: false, error: "wrong_host" })
  })
})
