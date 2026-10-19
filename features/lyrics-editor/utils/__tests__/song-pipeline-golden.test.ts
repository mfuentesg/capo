/**
 * Golden fixtures for the native iPad app's ChordPro port.
 *
 * Renders every ios/Fixtures/corpus/*.cho file across a transpose x capo grid and compares the
 * output with ios/Fixtures/golden/*.json. The Swift implementation must match these files.
 *
 * Regenerate after an intentional rendering change: UPDATE_GOLDEN=1 pnpm test -- song-pipeline-golden
 */
import fs from "fs"
import path from "path"
import { buildSectionMap, buildSegments } from "../song-pipeline"

const FIXTURES_DIR = path.resolve(__dirname, "../../../../ios/Fixtures")
const CORPUS_DIR = path.join(FIXTURES_DIR, "corpus")
const GOLDEN_DIR = path.join(FIXTURES_DIR, "golden")

const TRANSPOSES = [-6, -1, 0, 1, 6]
const CAPOS = [0, 2, 5]
const SECTION_LABELS = { chorus: "Chorus", verse: "Verse", bridge: "Bridge" }
const COMMENT_LABEL = "Note"

const files = fs.readdirSync(CORPUS_DIR).filter((f) => f.endsWith(".cho")).sort()

function render(lyrics: string, transpose: number, capo: number) {
  const sectionMap = buildSectionMap(lyrics)
  return buildSegments(lyrics, sectionMap, transpose, capo, SECTION_LABELS, COMMENT_LABEL)
}

describe("song-pipeline golden fixtures", () => {
  it("has a corpus", () => {
    expect(files.length).toBeGreaterThan(0)
  })

  it.each(files)("%s matches golden output", (file) => {
    const lyrics = fs.readFileSync(path.join(CORPUS_DIR, file), "utf8")
    const cases = TRANSPOSES.flatMap((transpose) =>
      CAPOS.map((capo) => ({ transpose, capo, segments: render(lyrics, transpose, capo) }))
    )
    const golden = {
      source: file,
      sectionLabels: SECTION_LABELS,
      commentLabel: COMMENT_LABEL,
      cases
    }
    const goldenPath = path.join(GOLDEN_DIR, file.replace(/\.cho$/, ".json"))

    if (process.env.UPDATE_GOLDEN) {
      fs.mkdirSync(GOLDEN_DIR, { recursive: true })
      fs.writeFileSync(goldenPath, JSON.stringify(golden, null, 2) + "\n")
      return
    }

    expect(fs.existsSync(goldenPath)).toBe(true)
    expect(golden).toEqual(JSON.parse(fs.readFileSync(goldenPath, "utf8")))
  })

  it("transposition and capo are applied to chords", () => {
    const [segment] = render("[G]hello [C]world", 2, 0)
    expect(segment.html).toContain(">A<")
    expect(segment.html).toContain(">D<")
    const [capoed] = render("[G]hello [C]world", 0, 2)
    expect(capoed.html).toContain(">F<")
    expect(capoed.html).toContain(">Bb<")
  })
})
