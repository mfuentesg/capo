import React from "react"
import { render } from "@testing-library/react"
import { RenderedSong } from "../rendered-song"

jest.mock("next/dynamic", () => (() => {
  return () => null
}))

// jsdom does not implement ResizeObserver
global.ResizeObserver = class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
}

jest.mock("@/features/settings", () => ({
  useLocale: () => ({
    t: {
      songs: { noLyrics: "No lyrics", addLyricsDescription: "" },
      songSections: {
        chorus: "Chorus",
        verse: "Verse",
        bridge: "Bridge",
        tab: "Tab",
        grid: "Grid",
        intro: "Intro",
        outro: "Outro",
        pre_chorus: "Pre-Chorus",
        comment: "Comment"
      },
      chords: { notFound: "not found" }
    }
  })
}))

const INLINE_REPEAT_LYRICS = `{soi: Intro}
[A]- -  [E/A][D/A]        [D/A][E/A][A]
{eoi}

{sov: Verse 1}
Amazing [G]grace
{eov}

{repeat: Intro, inline, 2}`

const STACKED_REPEAT_LYRICS = `{soi: Intro}
[A]- -  [E/A][D/A]
{eoi}

{repeat: Intro, 2}`

const CUSTOM_LABEL_LYRICS = `{soi: Intro}
[A]- -  [E/A][D/A]
{eoi}

{repeat: Intro, label: Strophe, 2}`

const QUOTED_LABEL_LYRICS = `{soi: Intro}
[A]- -  [E/A][D/A]
{eoi}

{repeat: Intro, label: "My Intro", 2}`

describe("RenderedSong — {repeat} inline flag", () => {
  it("renders repeat section with inline chord layout when inline flag present", () => {
    const { container } = render(
      <RenderedSong
        lyrics={INLINE_REPEAT_LYRICS}
        transpose={0}
        capo={0}
        fontSize={1}
        columns={1}
      />
    )

    const repeatBlocks = container.querySelectorAll('[data-section-type="intro"]')
    // Should have two blocks: the original section + the repeat
    expect(repeatBlocks.length).toBe(2)

    // The repeat block should NOT contain .clp-pair (stacked layout marker)
    const repeatBlock = repeatBlocks[1]
    expect(repeatBlock.querySelector(".clp-pair")).toBeNull()

    // The repeat block SHOULD contain .chord spans (chords present inline)
    expect(repeatBlock.querySelector(".chord")).not.toBeNull()
  })

  it("renders repeat section with stacked chord layout when inline flag absent", () => {
    const { container } = render(
      <RenderedSong
        lyrics={STACKED_REPEAT_LYRICS}
        transpose={0}
        capo={0}
        fontSize={1}
        columns={1}
      />
    )

    const repeatBlocks = container.querySelectorAll('[data-section-type="intro"]')
    expect(repeatBlocks.length).toBe(2)

    // Stacked layout produces .clp-pair wrappers
    const repeatBlock = repeatBlocks[1]
    expect(repeatBlock.querySelector(".clp-pair")).not.toBeNull()
  })

  it("uses custom label from label: token in the section header", () => {
    const { container } = render(
      <RenderedSong
        lyrics={CUSTOM_LABEL_LYRICS}
        transpose={0}
        capo={0}
        fontSize={1}
        columns={1}
      />
    )

    const repeatBlocks = container.querySelectorAll('[data-section-type="intro"]')
    expect(repeatBlocks.length).toBe(2)

    const repeatHeader = repeatBlocks[1].querySelector(".section-repeat > button, .section-repeat > div")
    expect(repeatHeader?.textContent).toContain("Strophe")
    expect(repeatHeader?.textContent).toContain("× 2")
  })

  it("strips quotes from label: token value", () => {
    const { container } = render(
      <RenderedSong
        lyrics={QUOTED_LABEL_LYRICS}
        transpose={0}
        capo={0}
        fontSize={1}
        columns={1}
      />
    )

    const repeatBlocks = container.querySelectorAll('[data-section-type="intro"]')
    expect(repeatBlocks.length).toBe(2)

    const repeatHeader = repeatBlocks[1].querySelector(".section-repeat > button, .section-repeat > div")
    expect(repeatHeader?.textContent).toContain("My Intro")
    expect(repeatHeader?.textContent).not.toContain('"')
  })
})
