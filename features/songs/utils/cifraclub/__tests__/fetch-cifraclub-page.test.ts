import { fetchCifraClubPage } from "../fetch-cifraclub-page"

describe("fetchCifraClubPage", () => {
  const originalFetch = global.fetch

  afterEach(() => {
    global.fetch = originalFetch
  })

  it("returns the page body on a direct 200 response", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      headers: new Headers(),
      text: async () => "<html></html>"
    }) as unknown as typeof fetch

    const result = await fetchCifraClubPage("https://www.cifraclub.com/john-mayer/gravity/")

    expect(result).toEqual({ ok: true, html: "<html></html>" })
  })

  it("follows a same-host redirect and returns the final page body", async () => {
    const mockFetch = jest
      .fn()
      .mockResolvedValueOnce({
        ok: false,
        status: 301,
        headers: new Headers({ location: "https://www.cifraclub.com/john-mayer/gravity-2/" }),
        text: async () => ""
      })
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        headers: new Headers(),
        text: async () => "<html>final</html>"
      })
    global.fetch = mockFetch as unknown as typeof fetch

    const result = await fetchCifraClubPage("https://www.cifraclub.com/john-mayer/gravity/")

    expect(result).toEqual({ ok: true, html: "<html>final</html>" })
    expect(mockFetch).toHaveBeenCalledTimes(2)
    expect(mockFetch).toHaveBeenNthCalledWith(
      2,
      "https://www.cifraclub.com/john-mayer/gravity-2/",
      expect.anything()
    )
  })

  it("rejects a redirect to a host outside the allowlist", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 302,
      headers: new Headers({ location: "https://evil.example/steal" }),
      text: async () => ""
    }) as unknown as typeof fetch

    const result = await fetchCifraClubPage("https://www.cifraclub.com/john-mayer/gravity/")

    expect(result).toEqual({ ok: false, reason: "wrong_host" })
  })

  it("returns http_status when a redirect response has no location header", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 302,
      headers: new Headers(),
      text: async () => ""
    }) as unknown as typeof fetch

    const result = await fetchCifraClubPage("https://www.cifraclub.com/john-mayer/gravity/")

    expect(result).toEqual({ ok: false, reason: "http_status" })
  })

  it("gives up after too many redirects", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 302,
      headers: new Headers({ location: "https://www.cifraclub.com/loop/" }),
      text: async () => ""
    }) as unknown as typeof fetch

    const result = await fetchCifraClubPage("https://www.cifraclub.com/john-mayer/gravity/")

    expect(result).toEqual({ ok: false, reason: "http_status" })
  })

  it("returns network on a fetch failure", async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error("boom")) as unknown as typeof fetch

    const result = await fetchCifraClubPage("https://www.cifraclub.com/john-mayer/gravity/")

    expect(result).toEqual({ ok: false, reason: "network" })
  })
})
