const FETCH_TIMEOUT_MS = 8_000
const MAX_RESPONSE_BYTES = 3_000_000

export type FetchCifraClubPageResult =
  | { ok: true; html: string }
  | { ok: false; reason: "network" | "http_status" }

export async function fetchCifraClubPage(url: string): Promise<FetchCifraClubPageResult> {
  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; CapoApp/1.0)" },
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
      redirect: "follow"
    })

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
  } catch {
    return { ok: false, reason: "network" }
  }
}
