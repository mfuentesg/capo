import { createHash, randomBytes } from "node:crypto"

export const TOKEN_PREFIX = "capo_"

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex")
}

export function generateToken(): { token: string; hash: string } {
  const token = TOKEN_PREFIX + randomBytes(32).toString("base64url")
  return { token, hash: hashToken(token) }
}

export function parseBearer(header: string | null): string | null {
  if (!header) return null
  const match = /^Bearer ([^\s]+)$/i.exec(header.trim())
  return match ? match[1] : null
}
