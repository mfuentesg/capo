import { validateCifraClubUrl } from "./validate-url"
import type { CifraClubParseError } from "../../types/cifraclub-import.types"

const FETCH_TIMEOUT_MS = 8_000
const MAX_RESPONSE_BYTES = 3_000_000
// CifraClub itself may redirect once (e.g. a canonical URL change); this
// bounds how many hops we'll follow before giving up.
const MAX_REDIRECTS = 3
const BROWSER_USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

export type FetchCifraClubPageResult =
  | { ok: true; html: string }
  | { ok: false; reason: Extract<CifraClubParseError, "network" | "http_status" | "wrong_host"> }

// Redirects are followed manually (not via fetch's redirect: "follow") so
// each hop's target host can be re-checked against the same allowlist used
// for the original URL — otherwise CifraClub redirecting (or being tricked
// into redirecting) to an arbitrary host would bypass validate-url entirely.
export async function fetchCifraClubPage(url: string): Promise<FetchCifraClubPageResult> {
  let currentUrl = url

  try {
    for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
      // CifraClub's bot protection blocks datacenter IPs (e.g. Vercel's), so when a
      // proxy is configured the request goes through it. The proxy must return
      // upstream redirects as-is (not follow them) so the host check below still runs.
      const proxyUrl = process.env.CIFRACLUB_PROXY_URL
      const requestUrl = proxyUrl
        ? `${proxyUrl}${proxyUrl.includes("?") ? "&" : "?"}url=${encodeURIComponent(currentUrl)}`
        : currentUrl
      const proxySecret = process.env.CIFRACLUB_PROXY_SECRET

      const res = await fetch(requestUrl, {
        headers: {
          "User-Agent": BROWSER_USER_AGENT,
          Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.9,pt-BR;q=0.8,es;q=0.7",
          ...(proxyUrl && proxySecret ? { "x-proxy-secret": proxySecret } : {})
        },
        signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
        redirect: "manual"
      })

      if (res.status >= 300 && res.status < 400) {
        const location = res.headers.get("location")
        if (!location) return { ok: false, reason: "http_status" }

        let target: URL
        try {
          target = new URL(location, currentUrl)
        } catch {
          return { ok: false, reason: "http_status" }
        }

        const validated = validateCifraClubUrl(target.href)
        if (!validated.ok) {
          return { ok: false, reason: validated.error === "wrong_host" ? "wrong_host" : "http_status" }
        }

        currentUrl = validated.url.href
        continue
      }

      if (!res.ok) {
        console.error(`[cifraclub] unexpected status ${res.status} for ${currentUrl}`)
        return { ok: false, reason: "http_status" }
      }

      const contentLength = res.headers.get("content-length")
      if (contentLength && Number(contentLength) > MAX_RESPONSE_BYTES) {
        return { ok: false, reason: "http_status" }
      }

      const html = await res.text()
      if (html.length > MAX_RESPONSE_BYTES) {
        return { ok: false, reason: "http_status" }
      }

      return { ok: true, html }
    }

    return { ok: false, reason: "http_status" }
  } catch (error) {
    console.error("[cifraclub] fetch failed", error)
    return { ok: false, reason: "network" }
  }
}
