import { chordProToVisualAST } from "../chordpro-to-visual-ast"
import { visualASTToChordPro } from "../visual-ast-to-chordpro"
import { isVoltaGroup } from "../../types/visual-song-ast"
import type { LyricLine, VisualSongAST, VoltaGroup } from "../../types/visual-song-ast"

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
    const line = block.lines[0] as LyricLine
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
    expect((ast.blocks[0].lines[0] as LyricLine).text).toBe("Lyric line")
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

  it("parses a volta group inside a verse", () => {
    const input = `{sov: Verse 1}
[G]Normal line
{sovt: 1st time}
[D]First ending
{eovt}
{sovt: 2nd time}
[Em]Second ending
{eovt}
{eov}`
    const ast = chordProToVisualAST(input)
    expect(ast.blocks).toHaveLength(1)
    const block = ast.blocks[0]
    // 1 normal lyric line + 2 volta groups
    expect(block.lines).toHaveLength(3)
    expect(isVoltaGroup(block.lines[0])).toBe(false)
    expect(isVoltaGroup(block.lines[1])).toBe(true)
    expect(isVoltaGroup(block.lines[2])).toBe(true)

    const volta1 = block.lines[1] as VoltaGroup
    expect(volta1.label).toBe("1st time")
    expect(volta1.lines).toHaveLength(1)
    expect(volta1.lines[0].chords[0].chord).toBe("D")

    const volta2 = block.lines[2] as VoltaGroup
    expect(volta2.label).toBe("2nd time")
    expect(volta2.lines[0].chords[0].chord).toBe("Em")
  })

  it("parses volta with shorthand sovt/eovt", () => {
    const input = `{soc}
Main chorus line
{sovt: D.C.}
Da capo ending
{eovt}
{eoc}`
    const ast = chordProToVisualAST(input)
    const block = ast.blocks[0]
    expect(block.lines).toHaveLength(2)
    const volta = block.lines[1] as VoltaGroup
    expect(isVoltaGroup(volta)).toBe(true)
    expect(volta.label).toBe("D.C.")
    expect((volta.lines[0] as LyricLine).text).toBe("Da capo ending")
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
    expect(output).toContain("[G]")
  })

  it("compiles volta groups with {sovt}…{eovt}", () => {
    const ast: VisualSongAST = {
      blocks: [
        {
          id: "b1",
          type: "verse",
          lines: [
            { id: "l1", text: "Normal line", chords: [] },
            {
              id: "v1",
              label: "1st time",
              lines: [{ id: "vl1", text: "First ending", chords: [{ id: "c1", chord: "D", offset: 0 }] }]
            } as VoltaGroup,
            {
              id: "v2",
              label: "2nd time",
              lines: [{ id: "vl2", text: "Second ending", chords: [] }]
            } as VoltaGroup
          ]
        }
      ]
    }
    const output = visualASTToChordPro(ast)
    expect(output).toContain("{sovt: 1st time}")
    expect(output).toContain("[D]First ending")
    expect(output).toContain("{eovt}")
    expect(output).toContain("{sovt: 2nd time}")
    expect(output).toContain("Second ending")
  })
})

describe("round-trip", () => {
  it("parse → compile → parse produces equivalent blocks (no volta)", () => {
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
      block.lines.forEach((sl, j) => {
        if (!isVoltaGroup(sl)) {
          const line = sl as LyricLine
          const line2 = ast2.blocks[i].lines[j] as LyricLine
          expect(line2.text).toBe(line.text)
          expect(line2.chords.map((c) => c.chord)).toEqual(line.chords.map((c) => c.chord))
          expect(line2.chords.map((c) => c.offset)).toEqual(line.chords.map((c) => c.offset))
        }
      })
    })
  })

  it("parse → compile → parse preserves volta groups", () => {
    const input = `{sov: Verse 1}
[G]Normal line
{sovt: 1st time}
[D]First ending
{eovt}
{sovt: 2nd time}
[Em]Second ending
{eovt}
{eov}`

    const ast1 = chordProToVisualAST(input)
    const compiled = visualASTToChordPro(ast1)
    const ast2 = chordProToVisualAST(compiled)

    expect(ast2.blocks).toHaveLength(1)
    const block1 = ast1.blocks[0]
    const block2 = ast2.blocks[0]
    expect(block2.lines).toHaveLength(block1.lines.length)

    const volta1 = block1.lines[1] as VoltaGroup
    const volta1r = block2.lines[1] as VoltaGroup
    expect(isVoltaGroup(volta1r)).toBe(true)
    expect(volta1r.label).toBe(volta1.label)
    expect(volta1r.lines[0].text).toBe(volta1.lines[0].text)
    expect(volta1r.lines[0].chords[0].chord).toBe(volta1.lines[0].chords[0].chord)
  })
})
