import { validateCifraClubUrl } from "./validate-url"
import type { CifraClubParseError } from "../../types/cifraclub-import.types"

const FETCH_TIMEOUT_MS = 8_000
const MAX_RESPONSE_BYTES = 3_000_000
// CifraClub itself may redirect once (e.g. a canonical URL change); this
// bounds how many hops we'll follow before giving up.
const MAX_REDIRECTS = 3

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
      const res = await fetch(currentUrl, {
        headers: { "User-Agent": "Mozilla/5.0 (compatible; CapoApp/1.0)" },
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
  } catch {
    return { ok: false, reason: "network" }
  }
}
