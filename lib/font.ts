export const VALID_UI_FONTS = ["geist", "inter", "dm-sans"] as const
export type UIFont = (typeof VALID_UI_FONTS)[number]

export function isValidUIFont(v: unknown): v is UIFont {
  return VALID_UI_FONTS.includes(v as UIFont)
}

export const DEFAULT_UI_FONT: UIFont = "geist"
