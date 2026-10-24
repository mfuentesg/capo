#!/usr/bin/env node
// Generates Packages/CapoUI/Sources/CapoDesign/Generated/PaletteTables.swift from
// ios/docs/WEB_PARITY_ANALYSIS.md section 5.4 (rendered sRGB of app/globals.css:421-1175) plus the
// Rosé Pine section-accent overrides (globals.css:381-397) and the picker preview colours/labels in
// features/settings/components/palette-settings.tsx. Usage: node ios/scripts/gen-palettes.mjs [--check]
import { readFileSync, writeFileSync, existsSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, "..", "..")
const doc = readFileSync(join(here, "..", "docs", "WEB_PARITY_ANALYSIS.md"), "utf8")
const palettesTsx = readFileSync(join(root, "features/settings/components/palette-settings.tsx"), "utf8")
const out = join(here, "..", "Packages/CapoUI/Sources/CapoDesign/Generated/PaletteTables.swift")

const ids = ["catppuccin", "aura", "nord", "rose-pine", "dracula", "one-dark-pro", "tokyo-night", "gruvbox", "monokai", "night-owl", "horizon", "shades-of-purple"]
const camel = (s) => s.replace(/-(\w)/g, (_, c) => c.toUpperCase())

function table(heading) {
  const start = doc.indexOf(heading)
  const lines = doc.slice(start).split("\n").slice(1)
  const rows = {}
  let seen = false
  for (const line of lines) {
    if (!line.startsWith("|")) { if (seen) break; else continue }
    seen = true
    const cells = line.split("|").slice(1, -1).map((c) => c.trim())
    const m = cells[0].match(/^`([^`]+)`$/)
    if (!m) continue
    rows[m[1]] = cells.slice(1).map((c) => c.replace("*", ""))
  }
  return rows
}
const light = table("#### Light mode (rendered sRGB hex)")
const dark = table("#### Dark mode (rendered sRGB hex)")

function oklchHex(L, C, H) {
  const r = (H * Math.PI) / 180, a = C * Math.cos(r), b = C * Math.sin(r)
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
  const s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
  const lin = [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s]
  const enc = (v) => { v = Math.min(Math.max(v, 0), 1); return v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055 }
  return "#" + lin.map((v) => Math.round(enc(v) * 255).toString(16).padStart(2, "0")).join("")
}

// Default section accents (globals.css:1067-1122) rendered, as already in CapoPalette.catppuccin.
const baseAccents = {
  light: { verse: "#005fb2", chorus: "#624bbc", bridge: "#a13170", comment: "#008687", repeat: "#9e4800", tab: "#626369", grid: "#626369", intro: "#1b7e2a", outro: "#007982", pre_chorus: "#7d45a2" },
  dark: { verse: "#45a4f6", chorus: "#a192ff", bridge: "#e670ac", comment: "#00afaf", repeat: "#f29520", tab: "#8e8f95", grid: "#8e8f95", intro: "#67bb6b", outro: "#00b6be", pre_chorus: "#bf8ae6" }
}
// Parse the Rosé Pine overrides straight from the CSS so they cannot drift.
const css = readFileSync(join(root, "app/globals.css"), "utf8")
const rose = { light: {}, dark: {} }
for (const m of css.matchAll(/html\[data-palette="rose-pine"\](\.dark)? \.section-repeat\[data-section-type="(\w+)"\]\s*\{ --section-accent: oklch\(([\d.]+) ([\d.]+) ([\d.]+)\)/g)) {
  rose[m[1] ? "dark" : "light"][m[2]] = oklchHex(+m[3], +m[4], +m[5])
}

// Picker preview colours and labels.
const preview = {}
for (const m of palettesTsx.matchAll(/id: "([\w-]+)",\s*light: \{ bg: "(#\w+)", primary: "(#\w+)", accent1: "(#\w+)", accent2: "(#\w+)" \},\s*dark: \{ bg: "(#\w+)", primary: "(#\w+)", accent1: "(#\w+)", accent2: "(#\w+)" \}/g)) {
  preview[m[1]] = { light: m.slice(2, 6), dark: m.slice(6, 10) }
}
const labels = {}
for (const m of palettesTsx.matchAll(/"?([\w-]+)"?: \{ name: "([^"]+)", desc: "([^"]+)" \}/g)) labels[m[1]] = { name: m[2], desc: m[3] }

const tokenMap = [
  ["background", "background"], ["foreground", "foreground"], ["card", "card"], ["popover", "popover"],
  ["primary", "primary"], ["primaryForeground", "primary-foreground"], ["secondary", "secondary"],
  ["muted", "muted"], ["mutedForeground", "muted-foreground"], ["accent", "accent"],
  ["destructive", "destructive"], ["border", "border"], ["input", "input"], ["ring", "ring"],
  ["chord", "chord"], ["accentSongs", "accent-songs"], ["accentPlaylists", "accent-playlists"],
  ["accentActivity", "accent-activity"], ["sidebar", "sidebar"], ["sidebarAccent", "sidebar-accent"],
  ["sidebarBorder", "sidebar-border"]
]
const q = (s) => `"${s}"`

function tokens(mode, idx, id) {
  const src = mode === "light" ? light : dark
  const fields = tokenMap.map(([swift, key]) => {
    const v = src[key]?.[idx]
    if (!v || !/^#[0-9a-f]{6}$/.test(v)) throw new Error(`missing ${key} for ${id}/${mode}`)
    return `${swift}: ${q(v)}`
  })
  const accents = { ...baseAccents[mode], ...(id === "rose-pine" ? rose[mode] : {}) }
  const accentLit = Object.entries(accents).map(([k, v]) => `${q(k)}: ${q(v)}`).join(", ")
  const extra = mode === "light"
    ? `comment: "#008687", note: "#ae6700", warning: "#e17100"`
    : `comment: "#00afaf", note: "#eca760", warning: "#ffb900"`
  const lines = []
  for (let i = 0; i < fields.length; i += 4) lines.push("      " + fields.slice(i, i + 4).join(", "))
  return `Tokens(\n${lines.join(",\n")},\n      sectionAccents: [${accentLit}],\n      ${extra})`
}

let swift = `// Generated by ios/scripts/gen-palettes.mjs. Do not edit by hand.
// Source: ios/docs/WEB_PARITY_ANALYSIS.md section 5.4 (rendered values of app/globals.css) and
// features/settings/components/palette-settings.tsx.

extension CapoPalette {
`
ids.forEach((id, idx) => {
  const lab = labels[id], pv = preview[id]
  if (!lab || !pv) throw new Error(`missing label/preview for ${id}`)
  const pvLit = (p) => `Preview(background: ${q(p[0])}, primary: ${q(p[1])}, accent1: ${q(p[2])}, accent2: ${q(p[3])})`
  swift += `  public nonisolated static let ${camel(id)} = CapoPalette(
    id: ${q(id)}, name: ${q(lab.name)}, summary: ${q(lab.desc)},
    preview: (light: ${pvLit(pv.light)}, dark: ${pvLit(pv.dark)}),
    light: ${tokens("light", idx, id)},
    dark: ${tokens("dark", idx, id)})

`
})
swift += `  /// The twelve web palettes in \`lib/palette.ts\` order.
  public nonisolated static let all: [CapoPalette] = [
    ${ids.map(camel).map((c) => "." + c).join(", ")}
  ]
}
`
if (process.argv.includes("--check")) {
  if (!existsSync(out) || readFileSync(out, "utf8") !== swift) { console.error("PaletteTables.swift is stale"); process.exit(1) }
} else writeFileSync(out, swift)
