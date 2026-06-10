import { isValidPalette, DEFAULT_PALETTE, type Palette } from "@/lib/palette"
import { isValidUIFont, DEFAULT_UI_FONT, type UIFont } from "@/lib/font"

export const VALID_THEMES = ["light", "dark", "system"] as const
export type Theme = (typeof VALID_THEMES)[number]

export const DEFAULT_THEME: Theme = "system"

export function isValidTheme(v: unknown): v is Theme {
  return VALID_THEMES.includes(v as Theme)
}

// The DB preference wins over the per-device cookie: cookies are only written
// when the user changes a setting on this device, so they can be missing or
// stale (fresh browser, change made on another device). Resolving DB-first at
// SSR time keeps the first paint correct without any client-side correction —
// every layer that resolves these preferences must use these helpers so the
// server-rendered <html> attributes and the client providers always agree.
export function resolveTheme(dbValue: unknown, cookieValue: string | undefined): Theme {
  if (isValidTheme(dbValue)) return dbValue
  if (isValidTheme(cookieValue)) return cookieValue
  return DEFAULT_THEME
}

export function resolvePalette(dbValue: unknown, cookieValue: string | undefined): Palette {
  if (isValidPalette(dbValue)) return dbValue
  if (isValidPalette(cookieValue)) return cookieValue
  return DEFAULT_PALETTE
}

export function resolveFont(dbValue: unknown, cookieValue: string | undefined): UIFont {
  if (isValidUIFont(dbValue)) return dbValue
  if (isValidUIFont(cookieValue)) return cookieValue
  return DEFAULT_UI_FONT
}
