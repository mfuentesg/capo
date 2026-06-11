import {
  resolveTheme,
  resolvePalette,
  resolveFont,
  isValidTheme,
  DEFAULT_THEME
} from "@/lib/display-preferences"
import { DEFAULT_PALETTE } from "@/lib/palette"
import { DEFAULT_UI_FONT } from "@/lib/font"

describe("isValidTheme", () => {
  it("accepts light, dark and system", () => {
    expect(isValidTheme("light")).toBe(true)
    expect(isValidTheme("dark")).toBe(true)
    expect(isValidTheme("system")).toBe(true)
  })

  it("rejects anything else", () => {
    expect(isValidTheme("blue")).toBe(false)
    expect(isValidTheme(undefined)).toBe(false)
    expect(isValidTheme(null)).toBe(false)
    expect(isValidTheme(1)).toBe(false)
  })
})

describe("resolveTheme", () => {
  it("prefers the DB value over the cookie", () => {
    expect(resolveTheme("dark", "light")).toBe("dark")
  })

  it("falls back to the cookie when the DB value is missing or invalid", () => {
    expect(resolveTheme(undefined, "dark")).toBe("dark")
    expect(resolveTheme("bogus", "light")).toBe("light")
  })

  it("falls back to the default when both are missing or invalid", () => {
    expect(resolveTheme(undefined, undefined)).toBe(DEFAULT_THEME)
    expect(resolveTheme("bogus", "bogus")).toBe(DEFAULT_THEME)
  })
})

describe("resolvePalette", () => {
  it("prefers the DB value over the cookie", () => {
    expect(resolvePalette("dracula", "nord")).toBe("dracula")
  })

  it("falls back to the cookie when the DB value is missing or invalid", () => {
    expect(resolvePalette(undefined, "nord")).toBe("nord")
    expect(resolvePalette("bogus", "gruvbox")).toBe("gruvbox")
  })

  it("falls back to the default when both are missing or invalid", () => {
    expect(resolvePalette(undefined, undefined)).toBe(DEFAULT_PALETTE)
    expect(resolvePalette("bogus", "bogus")).toBe(DEFAULT_PALETTE)
  })
})

describe("resolveFont", () => {
  it("prefers the DB value over the cookie", () => {
    expect(resolveFont("inter", "lato")).toBe("inter")
  })

  it("falls back to the cookie when the DB value is missing or invalid", () => {
    expect(resolveFont(undefined, "lato")).toBe("lato")
    expect(resolveFont("bogus", "manrope")).toBe("manrope")
  })

  it("falls back to the default when both are missing or invalid", () => {
    expect(resolveFont(undefined, undefined)).toBe(DEFAULT_UI_FONT)
    expect(resolveFont("bogus", "bogus")).toBe(DEFAULT_UI_FONT)
  })
})
