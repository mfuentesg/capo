import type { CifraClubParseError } from "../../types/cifraclub-import.types"

// Exact-match allowlist only — never `includes()`/`endsWith()`, which would
// let a host like "cifraclub.com.evil.example" slip through.
const ALLOWED_HOSTS = new Set(["cifraclub.com"])

export type ValidatedCifraClubUrl =
  | { ok: true; url: URL }
  | { ok: false; error: Extract<CifraClubParseError, "invalid_url" | "wrong_host"> }

export function validateCifraClubUrl(input: string): ValidatedCifraClubUrl {
  let url: URL
  try {
    url = new URL(input)
  } catch {
    return { ok: false, error: "invalid_url" }
  }

  if (url.protocol !== "https:") {
    return { ok: false, error: "invalid_url" }
  }

  const hostname = url.hostname.replace(/^www\./, "").toLowerCase()
  if (!ALLOWED_HOSTS.has(hostname)) {
    return { ok: false, error: "wrong_host" }
  }

  return { ok: true, url }
}
