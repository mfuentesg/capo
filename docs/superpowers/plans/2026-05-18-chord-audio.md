# Chord Audio Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a play button to the chord detail sheet (glossary) and chord diagram dialog (lyrics editor) that plays the current chord voicing using acoustic guitar samples.

**Architecture:** New `features/chord-audio` feature — a `midiToNote` utility, a `useChordAudio` hook with a module-level Tone.js Sampler singleton (lazy-loaded on first play, shared across all instances), and a `ChordPlayButton` component. Integrated into two existing components: `chord-detail-sheet.tsx` and `chord-diagram.tsx`.

**Tech Stack:** `tone` (Sampler), guitar-acoustic samples from `https://nbrosowsky.github.io/tonejs-instruments/samples/guitar-acoustic/`, React, Lucide icons

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `features/chord-audio/utils/midi-to-note.ts` | Create | Pure function: MIDI number → Tone.js note name |
| `features/chord-audio/__tests__/midi-to-note.test.ts` | Create | Unit tests for midiToNote |
| `features/chord-audio/hooks/use-chord-audio.ts` | Create | Singleton Sampler init + play hook |
| `features/chord-audio/components/chord-play-button.tsx` | Create | Icon button with loading/playing states |
| `features/chord-audio/__tests__/chord-play-button.test.tsx` | Create | Render + interaction tests |
| `features/chord-audio/index.ts` | Create | Public API |
| `features/chords/components/chord-detail-sheet.tsx` | Modify | Add ChordPlayButton to SheetHeader |
| `features/lyrics-editor/components/chord-diagram.tsx` | Modify | Add ChordPlayButton to DialogHeader |

---

## Task 1: Install Tone.js

**Files:**
- Modify: `package.json` (via pnpm)

- [ ] **Step 1: Install the package**

```bash
pnpm add tone
```

Expected output: packages installed with no peer-dep errors.

- [ ] **Step 2: Verify TypeScript types are included**

```bash
node -e "require('tone'); console.log('ok')"
```

Expected: prints `ok` (Tone.js ships its own types, no `@types/` needed).

- [ ] **Step 3: Commit**

```bash
git add package.json pnpm-lock.yaml
git commit -m "chore: add tone.js for chord audio playback"
```

---

## Task 2: midiToNote utility (TDD)

**Files:**
- Create: `features/chord-audio/utils/midi-to-note.ts`
- Create: `features/chord-audio/__tests__/midi-to-note.test.ts`

- [ ] **Step 1: Write the failing test**

Create `features/chord-audio/__tests__/midi-to-note.test.ts`:

```typescript
import { midiToNote } from "../utils/midi-to-note"

describe("midiToNote", () => {
  it("converts middle C (60) to C4", () => {
    expect(midiToNote(60)).toBe("C4")
  })

  it("converts E2 (40) to E2", () => {
    expect(midiToNote(40)).toBe("E2")
  })

  it("converts A4 (69) to A4", () => {
    expect(midiToNote(69)).toBe("A4")
  })

  it("maps an Am chord midi array to correct note names", () => {
    // Am position 0 from @tombatossals/chords-db: [45, 52, 57, 60, 64]
    expect([45, 52, 57, 60, 64].map(midiToNote)).toEqual(["A2", "E3", "A3", "C4", "E4"])
  })

  it("handles sharps correctly", () => {
    expect(midiToNote(61)).toBe("C#4")
    expect(midiToNote(63)).toBe("D#4")
    expect(midiToNote(66)).toBe("F#4")
  })
})
```

- [ ] **Step 2: Run to confirm it fails**

```bash
pnpm test -- --testPathPattern=features/chord-audio/__tests__/midi-to-note.test.ts
```

Expected: `FAIL` — `Cannot find module '../utils/midi-to-note'`

- [ ] **Step 3: Create the utility**

Create `features/chord-audio/utils/midi-to-note.ts`:

```typescript
const NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"] as const

export function midiToNote(midi: number): string {
  return NOTE_NAMES[midi % 12] + String(Math.floor(midi / 12) - 1)
}
```

- [ ] **Step 4: Run to confirm it passes**

```bash
pnpm test -- --testPathPattern=features/chord-audio/__tests__/midi-to-note.test.ts
```

Expected: `PASS` — 5 tests passing.

- [ ] **Step 5: Commit**

```bash
git add features/chord-audio/utils/midi-to-note.ts features/chord-audio/__tests__/midi-to-note.test.ts
git commit -m "feat(chord-audio): add midiToNote utility"
```

---

## Task 3: useChordAudio hook + feature scaffold

**Files:**
- Create: `features/chord-audio/hooks/use-chord-audio.ts`
- Create: `features/chord-audio/index.ts`

- [ ] **Step 1: Create the hook**

Create `features/chord-audio/hooks/use-chord-audio.ts`:

```typescript
"use client"

import { useState, useCallback } from "react"
import { midiToNote } from "../utils/midi-to-note"

// Module-level singleton — one Sampler shared across all hook instances
let samplerReady = false
let samplerLoading: Promise<void> | null = null
let sampler: import("tone").Sampler | null = null

async function loadSampler(): Promise<void> {
  if (samplerReady) return
  if (samplerLoading) return samplerLoading

  samplerLoading = new Promise<void>((resolve) => {
    import("tone").then(({ Sampler }) => {
      sampler = new Sampler(
        {
          A2: "A2.mp3",
          A3: "A3.mp3",
          A4: "A4.mp3",
          C3: "C3.mp3",
          C4: "C4.mp3",
          C5: "C5.mp3",
          E2: "E2.mp3",
          E3: "E3.mp3",
          E4: "E4.mp3",
          G3: "G3.mp3",
          G4: "G4.mp3",
        },
        {
          baseUrl: "https://nbrosowsky.github.io/tonejs-instruments/samples/guitar-acoustic/",
          onload: () => {
            samplerReady = true
            resolve()
          },
        }
      ).toDestination()
    })
  })
  return samplerLoading
}

export function useChordAudio() {
  const [isLoading, setIsLoading] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)

  const play = useCallback(async (midiNotes: number[]) => {
    if (!midiNotes.length) return

    if (!samplerReady) {
      setIsLoading(true)
      await loadSampler()
      setIsLoading(false)
    }

    if (!sampler) return

    const Tone = await import("tone")
    await Tone.start()

    setIsPlaying(true)
    const now = Tone.now()
    midiNotes.forEach((midi, i) => {
      sampler!.triggerAttack(midiToNote(midi), now + i * 0.025)
    })

    setTimeout(() => setIsPlaying(false), 800)
  }, [])

  return { play, isLoading, isPlaying }
}
```

- [ ] **Step 2: Create the public API**

Create `features/chord-audio/index.ts`:

```typescript
"use client"

export { ChordPlayButton } from "./components/chord-play-button"
export { useChordAudio } from "./hooks/use-chord-audio"
```

- [ ] **Step 3: Run typecheck**

```bash
pnpm typecheck 2>&1 | grep chord-audio || echo "no errors in chord-audio"
```

Expected: no type errors in `chord-audio`.

- [ ] **Step 4: Commit**

```bash
git add features/chord-audio/hooks/use-chord-audio.ts features/chord-audio/index.ts
git commit -m "feat(chord-audio): add useChordAudio hook with singleton Tone.js sampler"
```

---

## Task 4: ChordPlayButton component (TDD)

**Files:**
- Create: `features/chord-audio/components/chord-play-button.tsx`
- Create: `features/chord-audio/__tests__/chord-play-button.test.tsx`

- [ ] **Step 1: Write the failing test**

Create `features/chord-audio/__tests__/chord-play-button.test.tsx`:

```typescript
import { render, screen, fireEvent } from "@testing-library/react"
import { ChordPlayButton } from "../components/chord-play-button"
import * as chordAudioHook from "../hooks/use-chord-audio"

jest.mock("../hooks/use-chord-audio")

const mockPlay = jest.fn()
const mockUseChordAudio = chordAudioHook.useChordAudio as jest.Mock

describe("ChordPlayButton", () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseChordAudio.mockReturnValue({ play: mockPlay, isLoading: false, isPlaying: false })
  })

  it("renders nothing when midiNotes is undefined", () => {
    const { container } = render(<ChordPlayButton midiNotes={undefined} />)
    expect(container.firstChild).toBeNull()
  })

  it("renders nothing when midiNotes is empty", () => {
    const { container } = render(<ChordPlayButton midiNotes={[]} />)
    expect(container.firstChild).toBeNull()
  })

  it("renders a play button when midiNotes are provided", () => {
    render(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    expect(screen.getByRole("button", { name: "Play chord" })).toBeInTheDocument()
  })

  it("calls play with midiNotes when clicked", () => {
    render(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    fireEvent.click(screen.getByRole("button", { name: "Play chord" }))
    expect(mockPlay).toHaveBeenCalledWith([45, 52, 57, 60, 64])
  })

  it("disables the button while loading", () => {
    mockUseChordAudio.mockReturnValue({ play: mockPlay, isLoading: true, isPlaying: false })
    render(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    expect(screen.getByRole("button", { name: "Play chord" })).toBeDisabled()
  })
})
```

- [ ] **Step 2: Run to confirm it fails**

```bash
pnpm test -- --testPathPattern=features/chord-audio/__tests__/chord-play-button.test.tsx
```

Expected: `FAIL` — `Cannot find module '../components/chord-play-button'`

- [ ] **Step 3: Create the component**

Create `features/chord-audio/components/chord-play-button.tsx`:

```typescript
"use client"

import { Volume2, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { useChordAudio } from "../hooks/use-chord-audio"

interface ChordPlayButtonProps {
  midiNotes: number[] | undefined
  className?: string
}

export function ChordPlayButton({ midiNotes, className }: ChordPlayButtonProps) {
  const { play, isLoading, isPlaying } = useChordAudio()

  if (!midiNotes || midiNotes.length === 0) return null

  return (
    <Button
      type="button"
      variant="ghost"
      size="icon"
      className={cn(
        "h-8 w-8 shrink-0 text-muted-foreground hover:text-foreground",
        isPlaying && "text-primary",
        className
      )}
      onClick={() => play(midiNotes)}
      disabled={isLoading}
      aria-label="Play chord"
    >
      {isLoading ? (
        <Loader2 className="h-4 w-4 animate-spin" />
      ) : (
        <Volume2 className={cn("h-4 w-4 transition-transform duration-150", isPlaying && "scale-110")} />
      )}
    </Button>
  )
}
```

- [ ] **Step 4: Run to confirm it passes**

```bash
pnpm test -- --testPathPattern=features/chord-audio/__tests__/chord-play-button.test.tsx
```

Expected: `PASS` — 5 tests passing.

- [ ] **Step 5: Commit**

```bash
git add features/chord-audio/components/chord-play-button.tsx features/chord-audio/__tests__/chord-play-button.test.tsx
git commit -m "feat(chord-audio): add ChordPlayButton component"
```

---

## Task 5: Integrate into chord-detail-sheet

**Files:**
- Modify: `features/chords/components/chord-detail-sheet.tsx`

The `SheetHeader` currently contains a `<div>` with `<SheetTitle>` and an optional position counter paragraph. Add `ChordPlayButton` next to the title using a flex row wrapper.

`chord.positions[positionIndex].midi` is `number[] | undefined` (from `ChordPosition` in `chord-position-diagram.tsx`). `ChordPlayButton` renders nothing when undefined — no guard needed.

- [ ] **Step 1: Add import**

In `features/chords/components/chord-detail-sheet.tsx`, add to the imports block:

```typescript
import { ChordPlayButton } from "@/features/chord-audio"
```

- [ ] **Step 2: Replace SheetHeader content**

Find this block:

```tsx
        <SheetHeader className="mb-4">
          <div>
            <SheetTitle className="text-3xl font-black tracking-tighter">{displayName}</SheetTitle>
            {total > 1 && (
              <p className="text-xs text-muted-foreground uppercase tracking-widest mt-0.5">
                {t.chords.positionOf
                  .replace("{current}", String(positionIndex + 1))
                  .replace("{total}", String(total))}
              </p>
            )}
          </div>
        </SheetHeader>
```

Replace with:

```tsx
        <SheetHeader className="mb-4">
          <div>
            <div className="flex items-center gap-2">
              <SheetTitle className="text-3xl font-black tracking-tighter">{displayName}</SheetTitle>
              <ChordPlayButton midiNotes={chord.positions[positionIndex].midi} />
            </div>
            {total > 1 && (
              <p className="text-xs text-muted-foreground uppercase tracking-widest mt-0.5">
                {t.chords.positionOf
                  .replace("{current}", String(positionIndex + 1))
                  .replace("{total}", String(total))}
              </p>
            )}
          </div>
        </SheetHeader>
```

- [ ] **Step 3: Typecheck**

```bash
pnpm typecheck 2>&1 | grep chord-detail-sheet || echo "no errors"
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add features/chords/components/chord-detail-sheet.tsx
git commit -m "feat(chords): add chord play button to chord detail sheet"
```

---

## Task 6: Integrate into chord-diagram

**Files:**
- Modify: `features/lyrics-editor/components/chord-diagram.tsx`

`currentChord` is the `ChordPosition` at the current index. For DB-backed chords it has `midi?: number[]`. For algorithmic chords the generated `ChordPosition` objects have no `midi` field → `ChordPlayButton` renders nothing automatically.

- [ ] **Step 1: Add import**

In `features/lyrics-editor/components/chord-diagram.tsx`, add to the imports block:

```typescript
import { ChordPlayButton } from "@/features/chord-audio"
```

- [ ] **Step 2: Replace DialogHeader content**

Find this block:

```tsx
          <DialogHeader className="mb-8 sm:mb-6">
            <DialogTitle className="text-4xl sm:text-4xl font-black tracking-tight">
              {chordName}
            </DialogTitle>
            <div className="mt-1 font-medium text-muted-foreground uppercase tracking-widest text-[12px] sm:text-[10px]">
              {isAlgorithmic ? "Generated Diagram" : "Verified Shape"}
            </div>
          </DialogHeader>
```

Replace with:

```tsx
          <DialogHeader className="mb-8 sm:mb-6">
            <div className="flex items-center gap-2">
              <DialogTitle className="text-4xl sm:text-4xl font-black tracking-tight">
                {chordName}
              </DialogTitle>
              <ChordPlayButton midiNotes={currentChord.midi} />
            </div>
            <div className="mt-1 font-medium text-muted-foreground uppercase tracking-widest text-[12px] sm:text-[10px]">
              {isAlgorithmic ? "Generated Diagram" : "Verified Shape"}
            </div>
          </DialogHeader>
```

- [ ] **Step 3: Typecheck + full test suite**

```bash
pnpm typecheck && pnpm test
```

Expected: no type errors, all tests passing.

- [ ] **Step 4: Commit**

```bash
git add features/lyrics-editor/components/chord-diagram.tsx
git commit -m "feat(lyrics-editor): add chord play button to chord diagram dialog"
```

---

## Task 7: Manual smoke test

- [ ] **Step 1: Start dev server**

```bash
pnpm dev
```

- [ ] **Step 2: Test chord detail sheet (glossary)**

Navigate to the Chords page → Glossary tab. Click any chord card. The detail sheet opens. Verify:
- Speaker icon appears next to chord name
- Tapping it shows a loading spinner briefly (first time only, samples downloading)
- After load, plays recognizable guitar chord sound
- Swiping to a different voicing (if chord has multiple) and pressing play again → hears different voicing

- [ ] **Step 3: Test chord diagram dialog (lyrics editor)**

Open any song with chords. Tap a chord token in the lyrics. The chord diagram dialog opens. Verify:
- Speaker icon appears next to chord name for DB-backed chords
- No speaker icon for "Generated Diagram" chords (algorithmic fallback)
- Sound plays correctly

- [ ] **Step 4: Test second play (cached)**

Press play a second time on any chord. Verify: no loading spinner (sampler already ready), plays immediately.
