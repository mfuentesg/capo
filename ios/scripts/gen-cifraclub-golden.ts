// Generates ios/Fixtures/converter/cifraclub.json (web parseCifraClubHtml results):
//   npx tsx ios/scripts/gen-cifraclub-golden.ts
import { readFileSync, writeFileSync } from "node:fs"
import path from "node:path"
import { parseCifraClubHtml } from "../../features/songs/utils/cifraclub/parse-html"
import { validateCifraClubUrl } from "../../features/songs/utils/cifraclub/validate-url"

const root = path.resolve(__dirname, "../..")
const real = readFileSync(
  path.join(root, "features/songs/utils/cifraclub/__tests__/__fixtures__/cifraclub-eres-fiel.html"),
  "utf8"
)

function page(o: {
  jsonLd?: object
  og?: string
  h1?: string
  pres?: string[]
  tom?: string
  script?: string
} = {}): string {
  return `<!doctype html><html><head>${o.og ? `<meta property="og:title" content="${o.og}">` : ""}${
    o.jsonLd ? `<script type="application/ld+json">${JSON.stringify(o.jsonLd)}</script>` : ""
  }</head><body>${o.script ? `<script>${o.script}</script>` : ""}${o.h1 ? `<h1>${o.h1}</h1>` : ""}${
    o.tom ? `<div>${o.tom}</div>` : ""
  }${(o.pres ?? []).map((p) => `<pre>${p}</pre>`).join("\n")}</body></html>`
}

const sheet = [
  "[Intro] <b>Em</b>  <b>C</b>",
  "<b>Em</b>            <b>C</b>",
  "Tést lyric &amp; line one",
  "<b>G</b>             <b>D</b>",
  "Test lyric &#233; line &lt;two&gt;",
  "",
  "[Refrão]",
  "<b>Am</b>     <b>F</b>",
  "Segunda estrofe aqui"
].join("\n")

const cases: { url: string; html: string }[] = [
  { url: "https://www.cifraclub.com/israel-houghton/eres-fiel/", html: real },
  { url: "https://www.cifraclub.com.br/artista-um/musica-um/", html: page({ pres: [sheet], tom: "Tom: <b>Em</b>" }) },
  { url: "https://www.cifraclub.com/", html: page({ pres: [sheet], jsonLd: { "@type": "MusicComposition", name: "Eres Fiel", byArtist: { name: "Israel Houghton" } }, tom: "tom: d#m" }) },
  { url: "https://www.cifraclub.com/", html: page({ pres: [sheet], og: "Eres Fiel - Israel Houghton - Cifra Club", tom: "nothing" }) },
  { url: "https://www.cifraclub.com/", html: page({ pres: [sheet], h1: " Titulo H1 " , script: "var x='Tom: C'"}) },
  { url: "https://www.cifraclub.com/a-b/c-d/", html: page({ pres: ["short", sheet, "one\ntwo"] }) },
  { url: "https://www.cifraclub.com/a-b/c-d/", html: page({ pres: ["only one line"] }) },
  { url: "https://www.cifraclub.com/a-b/c-d/", html: page({}) },
  { url: "https://www.cifraclub.com/são-joão/á-é/", html: page({ pres: [sheet] }) }
]
const out = cases.map((c) => {
  const url = new URL(c.url)
  const r = parseCifraClubHtml(c.html, url)
  return { url: c.url, html: c.html, result: r }
})
const urls = [
  "https://www.cifraclub.com/a/b/", "https://cifraclub.com.br/a/b/", "http://www.cifraclub.com/a/", "https://cifraclub.com.evil.example/a/",
  "not a url", "https://WWW.CifraClub.com/x", "https://m.cifraclub.com/x", "ftp://cifraclub.com/x"
].map((u) => ({ url: u, result: validateCifraClubUrl(u).ok ? "ok" : (validateCifraClubUrl(u) as { error: string }).error }))
writeFileSync(path.join(root, "ios/Fixtures/converter/cifraclub.json"), JSON.stringify({ pages: out, urls }))
console.log(out.map((o) => (o.result.success ? "ok" : o.result.error)).join(","))
