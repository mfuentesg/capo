"use client"

import * as React from "react"
import { Chord as ChordJS } from "chordsheetjs"
import guitarDataRaw from "@tombatossals/chords-db/lib/guitar.json"
import { keyLabel, toDbKey } from "@/features/chords"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog"
import { ChevronLeft, ChevronRight, Info } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useLocale } from "@/features/settings"
import { useChordOrientation } from "@/hooks/use-chord-orientation"
// @ts-expect-error - no types for this library
import { findGuitarChord as findGuitarChordRaw } from "chord-fingering"
import { cn } from "@/lib/utils"
import { ChordPositionDiagram } from "@/components/chord-position-diagram"
import { ChordPlayButton, useChordAudio } from "@/features/chord-audio"

interface ChordPosition {
  frets: number[]
  fingers: number[]
  baseFret: number
  barres: number[]
  capo?: boolean
  midi?: number[]
}

interface ChordVariation {
  key: string
  suffix: string
  positions: ChordPosition[]
}

interface GuitarData {
  main: {
    strings: number
    fretsOnChord: number
    name: string
    numberOfChords: number
  }
  tunings: {
    standard: string[]
  }
  keys: string[]
  suffixes: string[]
  chords: Record<string, ChordVariation[]>
}

const guitarData = guitarDataRaw as unknown as GuitarData

interface ChordDiagramProps {
  chordName: string | null
  onClose: () => void
}

interface GeneratedPosition {
  stringIndex: number
  fret: number
}

interface GeneratedFingering {
  positions: GeneratedPosition[]
  barre: { fret: number } | null
}

interface GeneratedChord {
  fingerings: GeneratedFingering[]
}

const findGuitarChord = findGuitarChordRaw as (chordName: string) => GeneratedChord

// Transform chord-fingering output to react-chords format
function transformGeneratedChord(generated: GeneratedChord): ChordPosition[] {
  if (!generated || !generated.fingerings) return []

  return generated.fingerings.map((f) => {
    const frets = [-1, -1, -1, -1, -1, -1]
    f.positions.forEach((p) => {
      if (p.stringIndex >= 0 && p.stringIndex < 6) {
        frets[p.stringIndex] = p.fret
      }
    })

    const activeFrets = frets.filter((fr) => fr > 0)
    let baseFret = 1

    if (activeFrets.length > 0) {
      const maxFret = Math.max(...activeFrets)
      if (maxFret > 4) {
        baseFret = Math.min(...activeFrets)
      }
    }

    const relativeFrets = frets.map((fr) => {
      if (fr <= 0) return fr
      return fr - baseFret + 1
    })

    const barres: number[] = []
    if (f.barre) {
      barres.push(f.barre.fret - baseFret + 1)
    }

    return {
      frets: relativeFrets,
      fingers: [0, 0, 0, 0, 0, 0],
      baseFret: baseFret,
      barres: barres,
      capo: false,
    }
  })
}

// Map any musical note name to the standard keys used in chords-db
function getStandardNote(rootName: string): string {
  const normalizedRoot = rootName.charAt(0).toUpperCase() + rootName.slice(1)
  
  const keyMap: Record<string, string> = {
    "A#": "Bb",
    "Db": "C#",
    "D#": "Eb",
    "Gb": "F#",
    "G#": "Ab",
  }
  
  const standardRoot = keyMap[normalizedRoot] || normalizedRoot
  
  return toDbKey(standardRoot)
}

// Normalize chord names to the database
function parseChord(
  chordName: string,
  options: { allowBaseFallback?: boolean } = { allowBaseFallback: true }
): { key: string; suffix: string } | null {
  if (!chordName) return null

  // 1. Pre-normalization
  const normalizedInput = chordName
    .replace(/ø/g, "m7b5")
    .replace(/°/g, "dim")
    .replace(/Δ/g, "maj7")
    .replace(/6\/9/g, "69")

  let parsed: ChordJS | null = null
  try {
    parsed = ChordJS.parse(normalizedInput)
  } catch {
    const basicMatch = normalizedInput.match(/^([A-G][#b]?)(.*)$/i)
    if (basicMatch) {
      return { key: getStandardNote(basicMatch[1]), suffix: basicMatch[2] || "major" }
    }
    return null
  }

  if (!parsed || !parsed.root || parsed.root.type !== "symbol") {
    const basicMatch = normalizedInput.match(/^([A-G][#b]?)(.*)$/i)
    if (basicMatch) {
      const rootName = basicMatch[1]
      const suffix = basicMatch[2] || "major"
      return { key: getStandardNote(rootName), suffix }
    }
    return null
  }

  const normalizeSuffix = (rawSuffix: string | null, isMinor: boolean) => {
    const suffix = (rawSuffix || "").trim().replace(/[()]/g, "")

    const minorPrefixes = ["m", "min", "minor", "mi", "-"]
    const looksMinor = isMinor || minorPrefixes.includes(suffix.toLowerCase())

    if (suffix === "" || suffix === "major") return looksMinor ? "minor" : "major"
    if (minorPrefixes.includes(suffix.toLowerCase())) return "minor"

    if (suffix === "ø" || suffix === "ø7" || suffix === "m7b5" || suffix === "-7b5") return "m7b5"
    if (suffix === "o7" || suffix === "dim7" || suffix === "°7") return "dim7"
    if (suffix === "o" || suffix === "dim" || suffix === "°") return "dim"
    if (suffix === "+" || suffix === "aug" || suffix === "+5" || suffix === "#5") return "aug"
    if (suffix === "sus" || suffix === "sus4") return "sus4"
    if (suffix === "sus2") return "sus2"
    if (suffix === "7sus4" || suffix === "7sus") return "7sus4"
    if (suffix === "6/9" || suffix === "69") return "69"
    if (suffix === "7" || suffix === "dom7") return "7"
    if (suffix === "M7" || suffix === "maj7" || suffix === "ma7" || suffix === "Δ" || suffix === "Δ7")
      return "maj7"
    if (suffix === "m7" || suffix === "min7" || suffix === "mi7" || suffix === "-7") return "m7"
    if (suffix === "mM7" || suffix === "m(maj7)" || suffix === "mmaj7" || suffix === "-Δ7")
      return "mmaj7"
    if (suffix === "9") return "9"
    if (suffix === "M9" || suffix === "maj9") return "maj9"
    if (suffix === "m9" || suffix === "min9" || suffix === "-9") return "m9"
    if (suffix === "add9" || suffix === "add2" || suffix === "2") return "add9"
    if (suffix === "11") return "11"
    if (suffix === "13") return "13"

    const exactMap: Record<string, string> = {
      "7b9": "7b9",
      "7#9": "7#9",
      "7+9": "7#9",
      m11: "m11",
      maj13: "maj13",
      "6": "6",
      m6: "m6",
      "-6": "m6",
    }
    return exactMap[suffix] || suffix
  }

  const lookupKey = getStandardNote((parsed.root.originalKeyString || "") + (parsed.root.modifier || ""))

  // 1. Try slash chord lookup if applicable
  if (parsed.bass && parsed.bass.type === "symbol") {
    // Note: Bass note also needs to be normalized to database standard (e.g. /Gb -> /F#)
    const rawBassNote = parsed.bass.originalKeyString + (parsed.bass.modifier || "")
    const standardBass = keyLabel(getStandardNote(rawBassNote))
    
    let baseSuffix = (parsed.suffix || "").trim()

    if (baseSuffix === "m" || baseSuffix === "min" || baseSuffix === "minor") baseSuffix = "m"
    else if (baseSuffix === "" || baseSuffix === "maj" || baseSuffix === "major") baseSuffix = ""

    const dbSlashSuffix = (baseSuffix + "/" + standardBass).trim()
    const exists = guitarData.chords[lookupKey]?.some((c) => c.suffix === dbSlashSuffix)
    if (exists) return { key: lookupKey, suffix: dbSlashSuffix }

    if (!options.allowBaseFallback) return null
  }

  // 2. Fallback to base chord normalization
  const normalized = normalizeSuffix(parsed.suffix, parsed.root.minor)
  return { key: lookupKey, suffix: normalized }
}

export function ChordDiagram({ chordName, onClose }: ChordDiagramProps) {
  const [positionIndex, setPositionIndex] = React.useState(0)
  const [animKey, setAnimKey] = React.useState(0)
  const [slideDir, setSlideDir] = React.useState<"left" | "right">("left")
  const touchStartX = React.useRef(0)
  const { t } = useLocale()
  const { mirror } = useChordOrientation()
  const { stop } = useChordAudio()

  React.useEffect(() => {
    setPositionIndex(0)
    if (!chordName) stop()
  }, [chordName, stop])

  const { positions, totalPositions, isAlgorithmic } = React.useMemo(() => {
    if (!chordName) return { positions: [], totalPositions: 0, isAlgorithmic: false }

    // First try finding the EXACT chord in DB (including slash)
    const exactParsed = parseChord(chordName, { allowBaseFallback: false })
    let foundPositions: ChordPosition[] = []

    if (exactParsed) {
      const { key, suffix } = exactParsed
      const chordVariations = guitarData.chords[key]?.find((c) => c.suffix === suffix)
      if (chordVariations) {
        foundPositions = chordVariations.positions
      }
    }

    // Algorithmic fallback if not found in DB exactly
    if (foundPositions.length === 0) {
      try {
        const generated = findGuitarChord(chordName)
        if (generated && generated.fingerings && generated.fingerings.length > 0) {
          return { positions: transformGeneratedChord(generated), totalPositions: generated.fingerings.length, isAlgorithmic: true }
        }
      } catch {
        // Fallback silently if generation fails
      }
    }

    // Final fallback: try finding the BASE chord in DB (ignore bass note)
    if (foundPositions.length === 0) {
      const baseParsed = parseChord(chordName, { allowBaseFallback: true })
      if (baseParsed) {
        const { key, suffix } = baseParsed
        const chordVariations = guitarData.chords[key]?.find((c) => c.suffix === suffix)
        if (chordVariations) {
          foundPositions = chordVariations.positions
        }
      }
    }

    return { positions: foundPositions, totalPositions: foundPositions.length, isAlgorithmic: false }
  }, [chordName])

  if (!chordName) return null

  if (totalPositions === 0) {
    return (
      <Dialog open={!!chordName} onOpenChange={(open) => !open && onClose()}>
        <DialogContent className="sm:max-w-[400px]">
          <DialogHeader>
            <DialogTitle className="text-xl">{chordName}</DialogTitle>
            <div className="pt-4 flex flex-col items-center text-center">
              <div className="w-12 h-12 rounded-full bg-muted flex items-center justify-center mb-4">
                <Info className="w-6 h-6 text-muted-foreground" />
              </div>
              <DialogDescription>{t.chords.noDiagram}</DialogDescription>
            </div>
          </DialogHeader>
        </DialogContent>
      </Dialog>
    )
  }

  const currentChord = positions[positionIndex]

  const navigate = (dir: "left" | "right", next: number) => {
    setSlideDir(dir)
    setAnimKey((k) => k + 1)
    setPositionIndex(next)
  }

  const handlePrev = () =>
    navigate("right", positionIndex > 0 ? positionIndex - 1 : totalPositions - 1)

  const handleNext = () =>
    navigate("left", positionIndex < totalPositions - 1 ? positionIndex + 1 : 0)

  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX
  }
  const handleTouchEnd = (e: React.TouchEvent) => {
    const dx = e.changedTouches[0].clientX - touchStartX.current
    if (Math.abs(dx) > 40) {
      if (dx > 0) handlePrev()
      else handleNext()
    }
  }

  return (
    <Dialog open={!!chordName} onOpenChange={(open) => !open && onClose()}>
      <style>{`
        @keyframes slideFromRight { from { transform: translateX(48px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
        @keyframes slideFromLeft  { from { transform: translateX(-48px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
      `}</style>
      <DialogContent
        fancy
        className="w-full h-full max-w-none sm:h-auto sm:max-w-[450px] flex flex-col justify-center max-sm:bg-background"
      >
        <div className="p-5 sm:p-8 flex-1 sm:flex-initial flex flex-col justify-center sm:block">
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

          <div
            className="flex flex-col items-center relative group py-8 sm:py-0 gap-5"
            onTouchStart={totalPositions > 1 ? handleTouchStart : undefined}
            onTouchEnd={totalPositions > 1 ? handleTouchEnd : undefined}
          >
            <div
              key={animKey}
              className="relative w-full bg-white dark:bg-zinc-950 rounded-2xl sm:rounded-3xl px-4 py-5 sm:p-8 shadow-[0_20px_50px_rgba(0,0,0,0.1)] dark:shadow-[0_20px_50px_rgba(0,0,0,0.3)] border border-border/50 overflow-hidden transition-transform duration-500 group-hover:scale-[1.02]"
              style={{
                animation: animKey > 0
                  ? `${slideDir === "left" ? "slideFromRight" : "slideFromLeft"} 0.25s ease-out`
                  : undefined,
              }}
            >
              <ChordPositionDiagram
                position={currentChord}
                mirror={mirror}
              />
            </div>

            {totalPositions > 1 && (
              <div className="flex gap-1.5 mt-10 sm:mt-8 mb-2">
                {Array.from({ length: totalPositions }).map((_, i) => (
                  <button 
                    key={i} 
                    type="button"
                    className={cn(
                      "h-1.5 rounded-full transition-transform duration-300",
                      i === positionIndex ? "w-6 bg-primary" : "w-1.5 bg-muted-foreground/30 hover:bg-muted-foreground/50 cursor-pointer"
                    )}
                    onClick={() => navigate(i > positionIndex ? "left" : "right", i)}
                    aria-label={`Go to variation ${i + 1}`}
                  />
                ))}
              </div>
            )}
          </div>
        </div>

        {totalPositions > 1 && (
          <div className="grid grid-cols-2 border-t border-border bg-muted/30">
            <Button 
              variant="ghost" 
              className="h-12 rounded-none border-r border-border hover:bg-background transition-colors font-semibold gap-2 group text-xs sm:text-sm" 
              onClick={handlePrev}
            >
              <ChevronLeft className="h-4 w-4 transition-transform group-hover:-translate-x-1" />
              {t.common?.previous || "Previous"}
            </Button>
            <Button 
              variant="ghost" 
              className="h-12 rounded-none hover:bg-background transition-colors font-semibold gap-2 group text-primary text-xs sm:text-sm" 
              onClick={handleNext}
            >
              {t.common?.next || "Next"}
              <ChevronRight className="h-4 w-4 transition-transform group-hover:translate-x-1" />
            </Button>
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
