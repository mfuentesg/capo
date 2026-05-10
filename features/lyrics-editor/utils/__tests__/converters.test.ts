import { chordProToVisualAST } from "../chordpro-to-visual-ast"
import { visualASTToChordPro } from "../visual-ast-to-chordpro"
import type { VisualSongAST } from "../../types/visual-song-ast"

// crypto.randomUUID is not available in jsdom — stub it
beforeAll(() => {
  if (!globalThis.crypto?.randomUUID) {
    Object.defineProperty(globalThis, "crypto", {
      value: {
        randomUUID: () => Math.random().toString(36).slice(2)
      }
    })
  }
})

describe("chordProToVisualAST", () => {
  it("parses a simple verse block", () => {
    const input = `{sov: Verse 1}
[G]Amazing grace [D]how sweet the sound
{eov}`
    const ast = chordProToVisualAST(input)
    expect(ast.blocks).toHaveLength(1)
    const block = ast.blocks[0]
    expect(block.type).toBe("verse")
    expect(block.label).toBe("Verse 1")
    expect(block.lines).toHaveLength(1)
    const line = block.lines[0]
    expect(line.text).toBe("Amazing grace how sweet the sound")
    expect(line.chords).toHaveLength(2)
    expect(line.chords[0].chord).toBe("G")
    expect(line.chords[0].offset).toBe(0)
    expect(line.chords[1].chord).toBe("D")
    expect(line.chords[1].offset).toBe(14)
  })

  it("parses multiple section types", () => {
    const input = `{sov}
Verse line
{eov}

{soc: Chorus}
Chorus line
{eoc}

{sob}
Bridge line
{eob}`
    const ast = chordProToVisualAST(input)
    expect(ast.blocks).toHaveLength(3)
    expect(ast.blocks[0].type).toBe("verse")
    expect(ast.blocks[1].type).toBe("chorus")
    expect(ast.blocks[1].label).toBe("Chorus")
    expect(ast.blocks[2].type).toBe("bridge")
  })

  it("groups unsectioned lines into an implicit verse block", () => {
    const input = `Hello world
Second line`
    const ast = chordProToVisualAST(input)
    expect(ast.blocks).toHaveLength(1)
    expect(ast.blocks[0].type).toBe("verse")
    expect(ast.blocks[0].lines).toHaveLength(2)
  })

  it("ignores other directives", () => {
    const input = `{title: My Song}
{key: G}
{sov}
Lyric line
{eov}`
    const ast = chordProToVisualAST(input)
    expect(ast.blocks).toHaveLength(1)
    expect(ast.blocks[0].lines[0].text).toBe("Lyric line")
  })

  it("handles intro, outro, pre-chorus shorthands", () => {
    const input = `{soi}
Intro line
{eoi}
{soo}
Outro line
{eoo}
{sopc}
Pre-chorus line
{eopc}`
    const ast = chordProToVisualAST(input)
    expect(ast.blocks[0].type).toBe("intro")
    expect(ast.blocks[1].type).toBe("outro")
    expect(ast.blocks[2].type).toBe("pre-chorus")
  })

  it("returns empty blocks for empty input", () => {
    expect(chordProToVisualAST("").blocks).toHaveLength(0)
    expect(chordProToVisualAST("   \n  \n").blocks).toHaveLength(0)
  })
})

describe("visualASTToChordPro", () => {
  it("compiles a single block with chords", () => {
    const ast: VisualSongAST = {
      blocks: [
        {
          id: "b1",
          type: "verse",
          label: "Verse 1",
          lines: [
            {
              id: "l1",
              text: "Amazing grace how sweet",
              chords: [
                { id: "c1", chord: "G", offset: 0 },
                { id: "c2", chord: "D", offset: 14 }
              ]
            }
          ]
        }
      ]
    }
    const output = visualASTToChordPro(ast)
    expect(output).toContain("{sov: Verse 1}")
    expect(output).toContain("[G]Amazing grace [D]how sweet")
    expect(output).toContain("{eov}")
  })

  it("compiles multiple blocks separated by blank lines", () => {
    const ast: VisualSongAST = {
      blocks: [
        { id: "b1", type: "verse", lines: [{ id: "l1", text: "Line A", chords: [] }] },
        { id: "b2", type: "chorus", lines: [{ id: "l2", text: "Line B", chords: [] }] }
      ]
    }
    const output = visualASTToChordPro(ast)
    expect(output).toContain("{sov}")
    expect(output).toContain("{eov}")
    expect(output).toContain("{soc}")
    expect(output).toContain("{eoc}")
    const sections = output.split("\n\n")
    expect(sections).toHaveLength(2)
  })

  it("omits label colon when no label", () => {
    const ast: VisualSongAST = {
      blocks: [{ id: "b1", type: "chorus", lines: [{ id: "l1", text: "Sing", chords: [] }] }]
    }
    const output = visualASTToChordPro(ast)
    expect(output).toContain("{soc}")
    expect(output).not.toContain("{soc:")
  })

  it("clamps chord offsets beyond text length", () => {
    const ast: VisualSongAST = {
      blocks: [
        {
          id: "b1",
          type: "verse",
          lines: [
            {
              id: "l1",
              text: "Short",
              chords: [{ id: "c1", chord: "G", offset: 100 }]
            }
          ]
        }
      ]
    }
    const output = visualASTToChordPro(ast)
    // Chord should be appended at end, not crash
    expect(output).toContain("[G]")
  })
})

describe("round-trip", () => {
  it("parse → compile → parse produces equivalent blocks", () => {
    const input = `{sov: Verse 1}
[G]Amazing grace [D]how sweet the sound
That saved a wretch like me
{eov}

{soc}
[C]How precious [G]did that grace appear
{eoc}`

    const ast1 = chordProToVisualAST(input)
    const compiled = visualASTToChordPro(ast1)
    const ast2 = chordProToVisualAST(compiled)

    expect(ast2.blocks).toHaveLength(ast1.blocks.length)
    ast1.blocks.forEach((block, i) => {
      expect(ast2.blocks[i].type).toBe(block.type)
      expect(ast2.blocks[i].lines).toHaveLength(block.lines.length)
      block.lines.forEach((line, j) => {
        expect(ast2.blocks[i].lines[j].text).toBe(line.text)
        expect(ast2.blocks[i].lines[j].chords.map((c) => c.chord)).toEqual(
          line.chords.map((c) => c.chord)
        )
        expect(ast2.blocks[i].lines[j].chords.map((c) => c.offset)).toEqual(
          line.chords.map((c) => c.offset)
        )
      })
    })
  })
})
