"use client"

import * as React from "react"
import { Button } from "@/components/ui/button"
import { ChordPositionDiagram, type ChordPosition } from "@/components/chord-position-diagram"
import { useChordAnalyzer } from "../hooks/use-chord-analyzer"
import { FretboardInput } from "./fretboard-input"
import { getChordsByKey } from "../utils/chord-db-helpers"
import { useLocale } from "@/features/settings"
import { RotateCcw } from "lucide-react"
import { cn } from "@/lib/utils"
import { useChordOrientation } from "@/hooks/use-chord-orientation"

// Maps note names (including enharmonic equivalents) to chord-db keys
const NOTE_TO_DB_KEY: Record<string, string> = {
  C: "C",
  "C#": "Csharp",
  Db: "Csharp",
  D: "D",
  "D#": "Eb",
  Eb: "Eb",
  E: "E",
  F: "F",
  "F#": "Fsharp",
  Gb: "Fsharp",
  G: "G",
  "G#": "Ab",
  Ab: "Ab",
  A: "A",
  "A#": "Bb",
  Bb: "Bb",
  B: "B",
}

function findDbPosition(root: string, suffix: string): ChordPosition | null {
  const dbKey = NOTE_TO_DB_KEY[root]
  if (!dbKey) return null
  const entries = getChordsByKey(dbKey)
  const match = entries.find((c) => c.suffix === suffix)
  return (match?.positions[0] as ChordPosition | undefined) ?? null
}

export function ChordAnalyzer() {
  const { t } = useLocale()
  const { mirror } = useChordOrientation()
  const {
    frets,
    baseFret,
    results,
    notes,
    setStringFret,
    reset,
    incrementBaseFret,
    decrementBaseFret,
    MIN_BASE_FRET,
    MAX_BASE_FRET,
  } = useChordAnalyzer()

  const hasInput = frets.some((f) => f >= 0)

  return (
    <div className="space-y-6">
      {/* Header row */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">{t.chords.analyzer.instructionsDiagram}</p>
        <Button variant="outline" size="sm" onClick={reset} className="gap-2 shrink-0">
          <RotateCcw className="h-3.5 w-3.5" />
          {t.chords.analyzer.reset}
        </Button>
      </div>

      {/* Interactive fretboard */}
      <FretboardInput
        frets={frets}
        baseFret={baseFret}
        onStringFretChange={setStringFret}
        onIncrementBaseFret={incrementBaseFret}
        onDecrementBaseFret={decrementBaseFret}
        minBaseFret={MIN_BASE_FRET}
        maxBaseFret={MAX_BASE_FRET}
      />

      {/* Notes being played */}
      {notes.length > 0 && (
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
            {t.chords.analyzer.notes}:
          </span>
          {notes.map((note) => (
            <span
              key={note}
              className="rounded-full bg-muted px-2 py-0.5 text-xs font-semibold text-foreground"
            >
              {note}
            </span>
          ))}
        </div>
      )}

      {/* Results */}
      {hasInput && results.length === 0 && (
        <div className="py-6 text-center">
          <p className="text-sm font-semibold text-foreground">{t.chords.analyzer.noMatchTitle}</p>
          <p className="text-xs text-muted-foreground mt-1">{t.chords.analyzer.noMatch}</p>
        </div>
      )}

      {hasInput && results.length > 0 && (
        <div className="space-y-3">
          <h3 className="text-sm font-semibold text-foreground">{t.chords.analyzer.matches}</h3>

          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 md:grid-cols-4">
            {results.slice(0, 8).map((result) => {
                const dbPosition = findDbPosition(result.root, result.suffix)
                return (
                  <div
                    key={result.name}
                    className={cn(
                      "flex flex-col items-center gap-2 rounded-xl border p-3",
                      result.confidence === "exact"
                        ? "border-primary/30 bg-primary/5"
                        : "border-border bg-card"
                    )}
                  >
                    <div className="flex w-full items-start justify-between">
                      <span className="text-base font-bold tracking-tight leading-none">
                        {result.name}
                      </span>
                      {result.confidence === "exact" && (
                        <span className="rounded-full bg-primary/10 px-1.5 py-0.5 text-[10px] font-semibold text-primary uppercase">
                          {t.chords.analyzer.exact}
                        </span>
                      )}
                    </div>

                    {dbPosition && (
                      <div className="w-full overflow-hidden rounded-lg bg-white dark:bg-zinc-950 p-1">
                        <ChordPositionDiagram
                          position={dbPosition}
                          mirror={mirror}
                        />
                      </div>
                    )}

                    {result.missingNotes > 0 && (
                      <p className="text-[10px] text-muted-foreground">
                        {t.chords.analyzer.missingNotes.replace("{count}", String(result.missingNotes))}
                      </p>
                    )}
                  </div>
                )
              })}
          </div>
        </div>
      )}

      {!hasInput && (
        <div className="py-6 text-center">
          <p className="text-sm font-semibold text-foreground">{t.chords.analyzer.emptyStateTitle}</p>
          <p className="text-xs text-muted-foreground mt-1">{t.chords.analyzer.emptyState}</p>
        </div>
      )}
    </div>
  )
}
