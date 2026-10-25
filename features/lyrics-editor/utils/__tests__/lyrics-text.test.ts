import { normalizeLyricsText } from "../lyrics-text"

describe("normalizeLyricsText", () => {
  it("leaves ASCII untouched", () => {
    expect(normalizeLyricsText("[G]Amazing grace")).toBe("[G]Amazing grace")
  })

  it("composes decomposed accents", () => {
    expect(normalizeLyricsText("María")).toBe("María")
  })

  it("folds a spacing acute after a vowel into the accented letter", () => {
    expect(normalizeLyricsText("cora´zon")).toBe("corázon")
    expect(normalizeLyricsText("E´l")).toBe("Él")
  })

  it("keeps a spacing acute that does not follow a vowel", () => {
    expect(normalizeLyricsText("n´")).toBe("n´")
    expect(normalizeLyricsText("´a")).toBe("´a")
  })

  it("is idempotent", () => {
    const once = normalizeLyricsText("señor a´ é")
    expect(normalizeLyricsText(once)).toBe(once)
  })
})
