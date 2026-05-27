export const VALID_PALETTES = [
  "catppuccin",
  "aura",
  "nord",
  "rose-pine",
  "dracula",
  "one-dark-pro",
  "tokyo-night",
  "gruvbox",
  "monokai",
  "night-owl",
  "horizon",
  "shades-of-purple"
] as const
export type Palette = (typeof VALID_PALETTES)[number]

export function isValidPalette(v: unknown): v is Palette {
  return VALID_PALETTES.includes(v as Palette)
}

export const DEFAULT_PALETTE: Palette = "catppuccin"
