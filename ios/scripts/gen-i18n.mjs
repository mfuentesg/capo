#!/usr/bin/env node
// Generates Localizable.xcstrings and L10n.swift for CapoDesign from the web locale files
// (lib/i18n/locales/{en,es}.json) plus the iOS-only strings (ios/i18n/ios.{en,es}.json).
//
//   node ios/scripts/gen-i18n.mjs            write the generated files
//   node ios/scripts/gen-i18n.mjs --check    exit 1 when the generated files are stale
//   node ios/scripts/gen-i18n.mjs --out DIR  write/check DIR/Localizable.xcstrings and DIR/L10n.swift
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..")
const designDir = path.join(root, "ios/Packages/CapoUI/Sources/CapoDesign")
const LANGS = ["en", "es"]

const args = process.argv.slice(2)
const check = args.includes("--check")
const outIdx = args.indexOf("--out")
const outDir = outIdx >= 0 ? path.resolve(args[outIdx + 1]) : null
const xcstringsPath = outDir
  ? path.join(outDir, "Localizable.xcstrings")
  : path.join(designDir, "Resources/Localizable.xcstrings")
const swiftPath = outDir ? path.join(outDir, "L10n.swift") : path.join(designDir, "Generated/L10n.swift")

const SWIFT_KEYWORDS = new Set(
  (
    "associatedtype class deinit enum extension fileprivate func import init inout internal let " +
    "open operator private precedencegroup protocol public rethrows static struct subscript " +
    "typealias var break case catch continue default defer do else fallthrough for guard if in " +
    "repeat return throw switch where while Any as await false is nil self Self super throws " +
    "true try Type Protocol"
  ).split(" ")
)

const fail = (msg) => {
  console.error(`gen-i18n: ${msg}`)
  process.exit(2)
}

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"))
}

function flatten(obj, prefix = "", out = {}) {
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k
    if (v !== null && typeof v === "object") flatten(v, key, out)
    else if (typeof v === "string") out[key] = v
    else fail(`non-string value at ${key}`)
  }
  return out
}

const placeholderRe = /\{([A-Za-z_][A-Za-z0-9_]*)\}/g
const placeholders = (s) => [...s.matchAll(placeholderRe)].map((m) => m[1])
const uniq = (a) => [...new Set(a)]

// ---- load ----
const tables = {}
for (const lang of LANGS) {
  const web = flatten(readJSON(path.join(root, `lib/i18n/locales/${lang}.json`)))
  const ios = flatten(readJSON(path.join(root, `ios/i18n/ios.${lang}.json`)))
  for (const k of Object.keys(ios)) {
    if (!k.startsWith("ios.")) fail(`ios.${lang}.json key "${k}" must live under the "ios." namespace`)
    if (k in web) fail(`ios.${lang}.json key "${k}" collides with a web key`)
  }
  tables[lang] = { ...web, ...ios }
}

const keys = Object.keys(tables.en).sort()
for (const lang of LANGS.slice(1)) {
  const missing = keys.filter((k) => !(k in tables[lang]))
  const extra = Object.keys(tables[lang]).filter((k) => !(k in tables.en))
  if (missing.length || extra.length) {
    fail(`${lang} keys differ from en (missing: ${missing.slice(0, 5)}, extra: ${extra.slice(0, 5)})`)
  }
}

// Placeholder names (by first appearance in English) define positional indices for every language.
const params = {}
for (const key of keys) {
  params[key] = uniq(placeholders(tables.en[key]))
  for (const lang of LANGS.slice(1)) {
    const names = uniq(placeholders(tables[lang][key])).sort().join(",")
    if (names !== [...params[key]].sort().join(",")) fail(`placeholder mismatch for ${key} (${lang})`)
  }
}

// ---- xcstrings ----
function toFormat(key, text) {
  const names = params[key]
  const occurrences = placeholders(text).length
  const positional = names.length > 1 || occurrences > 1
  let out = ""
  let last = 0
  for (const m of text.matchAll(placeholderRe)) {
    out += text.slice(last, m.index).replaceAll("%", "%%")
    out += positional ? `%${names.indexOf(m[1]) + 1}$@` : "%@"
    last = m.index + m[0].length
  }
  return out + text.slice(last).replaceAll("%", "%%")
}

const xcstrings = {
  sourceLanguage: "en",
  strings: Object.fromEntries(
    keys.map((key) => [
      key,
      {
        extractionState: "manual",
        localizations: Object.fromEntries(
          LANGS.map((lang) => [lang, { stringUnit: { state: "translated", value: toFormat(key, tables[lang][key]) } }])
        )
      }
    ])
  ),
  version: "1.0"
}

// Xcode style: two-space indent, " : " between key and value, no trailing newline.
function xcodeJSON(value, indent = "") {
  const next = indent + "  "
  if (Array.isArray(value)) {
    return value.length ? `[\n${value.map((v) => next + xcodeJSON(v, next)).join(",\n")}\n${indent}]` : "[]"
  }
  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value)
    if (!entries.length) return "{\n\n" + indent + "}"
    return `{\n${entries.map(([k, v]) => `${next}${JSON.stringify(k)} : ${xcodeJSON(v, next)}`).join(",\n")}\n${indent}}`
  }
  return JSON.stringify(value)
}
const xcstringsText = xcodeJSON(xcstrings) + "\n"

// ---- L10n.swift ----
const upperFirst = (s) => s[0].toUpperCase() + s.slice(1)
const ident = (s) => (SWIFT_KEYWORDS.has(s) ? `\`${s}\`` : s)

const tree = {}
for (const key of keys) {
  const segs = key.split(".")
  let node = tree
  segs.slice(0, -1).forEach((s) => {
    const name = upperFirst(s)
    if (typeof node[name] === "string") fail(`key ${key} nests under a leaf`)
    node = node[name] ??= {}
  })
  const leaf = segs.at(-1)
  if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(leaf) || segs.some((s) => !/^[A-Za-z_][A-Za-z0-9_]*$/.test(s))) {
    fail(`key ${key} is not a valid Swift identifier path`)
  }
  if (leaf in node) fail(`duplicate member ${leaf} for ${key}`)
  node[leaf] = key
}

const docLine = (text) => text.replace(/\s*\n\s*/g, " ")

function emit(node, indent) {
  const pad = "  ".repeat(indent)
  const lines = []
  const members = Object.keys(node).sort()
  for (const name of members) {
    const value = node[name]
    if (typeof value === "string") {
      const key = value
      lines.push(`${pad}/// ${docLine(tables.en[key])}`)
      const names = params[key]
      const lookup = `String(localized: "${key}", bundle: .module)`
      if (!names.length) {
        lines.push(`${pad}public static var ${ident(name)}: String { ${lookup} }`)
      } else {
        const sig = names.map((n) => `${ident(n)}: String`).join(", ")
        const call = names.map((n) => ident(n)).join(", ")
        lines.push(`${pad}public static func ${ident(name)}(${sig}) -> String {`)
        lines.push(`${pad}  String(format: ${lookup}, ${call})`)
        lines.push(`${pad}}`)
      }
    } else {
      lines.push(`${pad}public nonisolated enum ${ident(name)} {`)
      lines.push(emit(value, indent + 1))
      lines.push(`${pad}}`)
    }
  }
  return lines.join("\n")
}

const swiftText = `// Generated by ios/scripts/gen-i18n.mjs from lib/i18n/locales/*.json and ios/i18n/ios.*.json.
// Do not edit by hand; run \`node ios/scripts/gen-i18n.mjs\` instead.

import Foundation

public nonisolated enum L10n {
${emit(tree, 1)}
}
`

// ---- write / check ----
const outputs = [
  [xcstringsPath, xcstringsText],
  [swiftPath, swiftText]
]

if (check) {
  const stale = outputs.filter(([file, text]) => !fs.existsSync(file) || fs.readFileSync(file, "utf8") !== text)
  if (stale.length) {
    console.error(`gen-i18n: stale output (run node ios/scripts/gen-i18n.mjs):\n${stale.map(([f]) => "  " + path.relative(root, f)).join("\n")}`)
    process.exit(1)
  }
  console.log(`gen-i18n: up to date (${keys.length} keys)`)
} else {
  for (const [file, text] of outputs) {
    fs.mkdirSync(path.dirname(file), { recursive: true })
    fs.writeFileSync(file, text)
  }
  console.log(`gen-i18n: wrote ${keys.length} keys`)
}
