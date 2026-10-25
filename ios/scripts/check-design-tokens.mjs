#!/usr/bin/env node
// Design-token guard: compares the colour tokens of app/globals.css (the web source of truth) with
// the iOS palette tables (Generated/PaletteTables.swift) for all twelve palettes, light and dark,
// plus the radius scale. OKLCH values are converted with the same formula as gen-palettes.mjs; a
// small per-channel tolerance absorbs the browser's gamut mapping vs. plain clamping.
// Usage: node ios/scripts/check-design-tokens.mjs        (exit 1 on drift)
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, "..", "..")
const css = readFileSync(join(root, "app/globals.css"), "utf8")
const design = join(here, "..", "Packages/CapoUI/Sources/CapoDesign")
const swift = readFileSync(join(design, "Generated/PaletteTables.swift"), "utf8")
const theme = readFileSync(join(design, "Theme.swift"), "utf8")
const TOLERANCE = 3

const ids = ["catppuccin", "aura", "nord", "rose-pine", "dracula", "one-dark-pro", "tokyo-night", "gruvbox", "monokai", "night-owl", "horizon", "shades-of-purple"]
const camel = (s) => s.replace(/-(\w)/g, (_, c) => c.toUpperCase())
// css custom property -> Swift Tokens field
const tokens = {
  background: "background", foreground: "foreground", card: "card", popover: "popover", primary: "primary",
  "primary-foreground": "primaryForeground", secondary: "secondary", muted: "muted",
  "muted-foreground": "mutedForeground", accent: "accent", destructive: "destructive", border: "border",
  input: "input", ring: "ring", chord: "chord", "accent-songs": "accentSongs",
  "accent-playlists": "accentPlaylists", "accent-activity": "accentActivity", sidebar: "sidebar",
  "sidebar-accent": "sidebarAccent", "sidebar-border": "sidebarBorder"
}

function oklchRGB(L, C, H) {
  const r = (H * Math.PI) / 180, a = C * Math.cos(r), b = C * Math.sin(r)
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
  const s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
  const lin = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s]
  const enc = (v) => { v = Math.min(Math.max(v, 0), 1); return v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055 }
  return lin.map((v) => Math.round(enc(v) * 255))
}
const rgb = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16))

// CSS blocks: selector -> { prop: [L, C, H] }
const blocks = new Map()
for (const m of css.matchAll(/(^|\n)(:root|\.dark|html\[data-palette="[\w-]+"\](?:\.dark)?)\s*\{([^}]*)\}/g)) {
  const props = {}
  for (const p of m[3].matchAll(/--([\w-]+):\s*oklch\(([\d.]+)\s+([\d.]+)\s+([\d.]+)\)/g)) props[p[1]] = [+p[2], +p[3], +p[4]]
  blocks.set(m[2], { ...(blocks.get(m[2]) ?? {}), ...props })
}
const selector = (id, dark) => id === "catppuccin" ? (dark ? ".dark" : ":root") : `html[data-palette="${id}"]${dark ? ".dark" : ""}`

// Swift tables: palette -> mode -> field -> hex
function swiftTokens(id, mode) {
  const start = swift.indexOf(`static let ${camel(id)} = CapoPalette(`)
  if (start < 0) return null
  const rest = swift.slice(start)
  const from = rest.indexOf(`${mode}: Tokens(`)
  const body = rest.slice(from, from + 1600)
  const out = {}
  for (const m of body.slice(0, body.indexOf("sectionAccents")).matchAll(/(\w+): "(#[0-9a-f]{6})"/g)) out[m[1]] = m[2]
  return out
}

const problems = []
let checked = 0
for (const id of ids) {
  for (const mode of ["light", "dark"]) {
    const dark = mode === "dark"
    const own = blocks.get(selector(id, dark))
    const sw = swiftTokens(id, mode)
    if (!own) { problems.push(`${id} ${mode}: no CSS block`); continue }
    if (!sw) { problems.push(`${id} ${mode}: no Swift table`); continue }
    // Palettes inherit unset tokens (e.g. accent-songs) from the base blocks.
    const base = blocks.get(dark ? ".dark" : ":root")
    for (const [prop, field] of Object.entries(tokens)) {
      const v = own[prop] ?? base[prop]
      if (!v || !sw[field]) {
        if (v || sw[field]) problems.push(`${id} ${mode} ${prop}: missing on ${v ? "iOS" : "web"}`)
        continue
      }
      const want = oklchRGB(...v), have = rgb(sw[field])
      checked++
      if (want.some((c, i) => Math.abs(c - have[i]) > TOLERANCE)) {
        problems.push(`${id} ${mode} ${prop}: web oklch(${v.join(" ")}) = rgb(${want}) vs iOS ${sw[field]}`)
      }
    }
  }
}

// Radius scale: --radius 0.65rem; md = -2px, xl = +4px (globals.css @theme).
const radius = css.match(/--radius:\s*([\d.]+)rem/)
if (radius) {
  const base = +radius[1] * 16
  const expected = { base, md: base - 2, xl: base + 4 }
  for (const [name, value] of Object.entries(expected)) {
    const m = theme.match(new RegExp(`static let ${name}\\b[^=]*=\\s*([\\d.]+)`))
    if (!m || Math.abs(+m[1] - value) > 0.01) problems.push(`radius ${name}: web ${value} vs iOS ${m ? m[1] : "missing"}`)
  }
}

if (problems.length) {
  console.error(`design tokens drifted (${problems.length}):\n` + problems.join("\n"))
  process.exit(1)
}
console.log(`design tokens in sync (${checked} colour tokens, ${ids.length} palettes)`)
