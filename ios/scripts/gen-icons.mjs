#!/usr/bin/env node
// Generates ios/Packages/CapoUI/Sources/CapoIcons/CapoIconName+Generated.swift and ios/docs/ICON_MAP.md
// from the lucide-react package the web uses. Icon set = every lucide icon imported anywhere in the
// web source plus the team icon picker (components/ui/icon-picker.tsx).
// Usage: node ios/scripts/gen-icons.mjs [--check]
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..")
const check = process.argv.includes("--check")
const lucideDir = path.join(root, "node_modules/lucide-react/dist/esm")
const lucideVersion = JSON.parse(
  fs.readFileSync(path.join(root, "node_modules/lucide-react/package.json"), "utf8")
).version

// ---- 1. Which icons does the web use? ----
const SKIP_DIRS = new Set(["node_modules", "ios", "out", "dist", "build", "coverage"])
const used = new Set()
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name.startsWith(".") || SKIP_DIRS.has(e.name)) continue
    const p = path.join(dir, e.name)
    if (e.isDirectory()) walk(p)
    else if (/\.(tsx?|jsx?|mjs)$/.test(e.name)) {
      const src = fs.readFileSync(p, "utf8")
      for (const m of src.matchAll(/import\s*(?:type\s*)?\{([^}]*)\}\s*from\s*["']lucide-react["']/g)) {
        for (const raw of m[1].split(",")) {
          const n = raw.trim().split(/\s+as\s+/)[0]
          if (n && n !== "LucideIcon" && n !== "LucideProps") used.add(n)
        }
      }
    }
  }
}
walk(root)

const exportsSrc = fs.readFileSync(path.join(lucideDir, "lucide-react.js"), "utf8")
const fileFor = new Map() // export name -> icon file
for (const m of exportsSrc.matchAll(/export \{([^}]*)\} from '\.\/icons\/([^']+)\.js'/g)) {
  for (const part of m[1].split(",")) {
    const [, alias] = part.trim().split(/\s+as\s+/)
    if (alias) fileFor.set(alias.trim(), m[2])
  }
}

// Canonical web name: strip the `Icon` suffix alias (CheckIcon -> Check).
const canonical = (n) => (fileFor.has(n) || !n.endsWith("Icon") ? n : n)
const webNames = new Set()
for (const n of used) {
  if (fileFor.has(n) && !(n.endsWith("Icon") && fileFor.has(n.slice(0, -4)))) webNames.add(n)
  else if (n.endsWith("Icon") && fileFor.has(n.slice(0, -4))) webNames.add(n.slice(0, -4))
  else throw new Error(`lucide export not found: ${n}`)
}

// ---- 2. Team icon picker order + groups ----
const picker = fs.readFileSync(path.join(root, "components/ui/icon-picker.tsx"), "utf8")
const body = picker.slice(picker.indexOf("export const TEAM_ICONS"))
const block = body.slice(body.indexOf("{") + 1, body.indexOf("\n}"))
const teamIcons = []
let group = ""
const teamGroup = {}
for (const line of block.split("\n")) {
  const c = line.match(/^\s*\/\/\s*(.+)$/)
  if (c) { group = c[1].trim(); continue }
  const n = line.match(/^\s*([A-Za-z0-9]+),?\s*$/)
  if (n) { teamIcons.push(n[1]); teamGroup[n[1]] = group }
}
for (const n of teamIcons) {
  if (!fileFor.has(n)) throw new Error(`team icon not in lucide: ${n}`)
  webNames.add(n)
}

// ---- 3. SVG node -> path data ----
const num = (v) => Number(v)
const f = (v) => String(Math.round(v * 1e4) / 1e4)
function nodeToPath([tag, a]) {
  switch (tag) {
    case "path": return a.d
    case "line": return `M${a.x1} ${a.y1}L${a.x2} ${a.y2}`
    case "polyline":
    case "polygon": {
      const pts = a.points.trim().split(/[\s,]+/).map(num)
      let d = `M${pts[0]} ${pts[1]}`
      for (let i = 2; i < pts.length; i += 2) d += `L${pts[i]} ${pts[i + 1]}`
      return tag === "polygon" ? d + "Z" : d
    }
    case "circle": case "ellipse": {
      const cx = num(a.cx), cy = num(a.cy)
      const rx = num(tag === "circle" ? a.r : a.rx), ry = num(tag === "circle" ? a.r : a.ry)
      return `M${f(cx - rx)} ${f(cy)}a${f(rx)} ${f(ry)} 0 1 0 ${f(2 * rx)} 0a${f(rx)} ${f(ry)} 0 1 0 ${f(-2 * rx)} 0Z`
    }
    case "rect": {
      const x = num(a.x ?? 0), y = num(a.y ?? 0), w = num(a.width), h = num(a.height)
      let rx = num(a.rx ?? a.ry ?? 0), ry = num(a.ry ?? a.rx ?? 0)
      rx = Math.min(rx, w / 2); ry = Math.min(ry, h / 2)
      if (!rx && !ry) return `M${x} ${y}H${f(x + w)}V${f(y + h)}H${x}Z`
      return `M${f(x + rx)} ${y}H${f(x + w - rx)}A${f(rx)} ${f(ry)} 0 0 1 ${f(x + w)} ${f(y + ry)}V${f(y + h - ry)}` +
        `A${f(rx)} ${f(ry)} 0 0 1 ${f(x + w - rx)} ${f(y + h)}H${f(x + rx)}A${f(rx)} ${f(ry)} 0 0 1 ${x} ${f(y + h - ry)}` +
        `V${f(y + ry)}A${f(rx)} ${f(ry)} 0 0 1 ${f(x + rx)} ${y}Z`
    }
    default: throw new Error(`unsupported svg tag ${tag}`)
  }
}

function loadNode(file) {
  const src = fs.readFileSync(path.join(lucideDir, "icons", `${file}.js`), "utf8")
  const alias = src.match(/export \{ default \} from '\.\/([^']+)\.js'/)
  if (alias) return loadNode(alias[1])
  const m = src.match(/const __iconNode = (\[[\s\S]*?\]);\n/)
  if (!m) throw new Error(`no __iconNode in ${file}`)
  return new Function(`return ${m[1]}`)()
}

const caseName = (n) => {
  const m = n.match(/^[A-Z]+(?![a-z])/) // leading acronym run is not expected, keep simple
  const s = n.charAt(0).toLowerCase() + n.slice(1)
  return m && m[0].length > 1 ? n.toLowerCase() : s
}
const swiftCase = (n) => {
  const c = caseName(n)
  return ["type", "default", "repeat", "switch", "case", "in", "is", "as"].includes(c) ? `\`${c}\`` : c
}

const names = [...webNames].sort((a, b) => a.localeCompare(b))
const entries = names.map((n) => {
  const file = fileFor.get(n)
  const d = loadNode(file).map(nodeToPath)
    // A leading relative `m` is absolute in its own element; reset the pen so it stays so once joined.
    .map((d) => (d.trimStart().startsWith("m") ? `M0 0${d}` : d))
    .join(" ")
  return { n, file, d, c: swiftCase(n) }
})

// ---- 4. Emit Swift ----
const swift = []
swift.push(`// GENERATED by ios/scripts/gen-icons.mjs from lucide-react ${lucideVersion} (ISC licence). Do not edit.
// swiftlint:disable all

public nonisolated enum CapoIconName: String, CaseIterable, Sendable {
${entries.map((e) => `  case ${e.c} = "${e.n}"`).join("\n")}
}

nonisolated extension CapoIconName {
  /// Lucide icon file this case was generated from (kebab-case).
  public var lucideFile: String {
    switch self {
${entries.map((e) => `    case .${e.c.replace(/`/g, "")}: "${e.file}"`).join("\n")}
    }
  }

  /// SVG path data on lucide's 24x24 grid (all sub-shapes joined, each starts with an absolute move).
  public var pathData: String {
    switch self {
${entries.map((e) => `    case .${e.c.replace(/`/g, "")}: ${JSON.stringify(e.d)}`).join("\n")}
    }
  }

  /// The ${teamIcons.length} icons selectable in the web team icon picker, in picker order.
  public static let teamIcons: [CapoIconName] = [
${teamIcons.map((n) => `    .${swiftCase(n)}`).join(",\n")}
  ]
}
`)
const swiftOut = swift.join("")
const outSwift = path.join(root, "ios/Packages/CapoUI/Sources/CapoIcons/CapoIconName+Generated.swift")

// ---- 5. Emit ICON_MAP.md ----
const md = []
md.push(`# Icon map (lucide-react ${lucideVersion} -> CapoIcon)

Generated by \`node ios/scripts/gen-icons.mjs\`. Do not edit by hand.

Usage: \`CapoIcon(.users, size: 16)\` or \`CapoIcon.named("Guitar", size: 20)\` for stored team icon names
(unknown names fall back to \`.users\`). Tint with \`.foregroundStyle(...)\`. Stroke is 2 on the 24 grid, scaled
with the size like the web (\`size-4\` = 1.33 px), round caps and joins.

## Web icons (${entries.length})

| Web (lucide) | CapoIconName case | Lucide file |
|---|---|---|
${entries.map((e) => `| \`${e.n}\` | \`.${e.c.replace(/`/g, "")}\` | \`${e.file}\` |`).join("\n")}

## Team icon picker (${teamIcons.length}, picker order)

| Group | Icons |
|---|---|
${[...new Set(teamIcons.map((n) => teamGroup[n]))].map((g) => `| ${g} | ${teamIcons.filter((n) => teamGroup[n] === g).map((n) => `\`${n}\``).join(", ")} |`).join("\n")}
`)
const outMd = path.join(root, "ios/docs/ICON_MAP.md")

if (check) {
  const same = fs.existsSync(outSwift) && fs.readFileSync(outSwift, "utf8") === swiftOut &&
    fs.existsSync(outMd) && fs.readFileSync(outMd, "utf8") === md.join("")
  if (!same) { console.error("icons out of date: run node ios/scripts/gen-icons.mjs"); process.exit(1) }
} else {
  fs.mkdirSync(path.dirname(outSwift), { recursive: true })
  fs.writeFileSync(outSwift, swiftOut)
  fs.writeFileSync(outMd, md.join(""))
  console.log(`icons: ${entries.length}, team icons: ${teamIcons.length}`)
}
