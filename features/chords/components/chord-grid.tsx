"use client"

import * as React from "react"
import dynamic from "next/dynamic"
import { ChordCard } from "./chord-card"
import { keyLabel, type ChordEntry } from "../utils/chord-db-helpers"
import { useLocale } from "@/features/settings"

// Lazy-loaded: avoids pulling the lyrics-editor barrel (chordsheetjs etc.)
// into the chords page chunk — the diagram only renders once a card is tapped
const ChordDiagram = dynamic(
  () => import("@/features/lyrics-editor").then((m) => m.ChordDiagram),
  { ssr: false }
)

interface ChordGridProps {
  chords: ChordEntry[]
}

export function ChordGrid({ chords }: ChordGridProps) {
  const [selected, setSelected] = React.useState<ChordEntry | null>(null)
  const selectedName = selected
    ? selected.suffix === "major"
      ? keyLabel(selected.key)
      : `${keyLabel(selected.key)}${selected.suffix}`
    : null
  const { t } = useLocale()

  if (chords.length === 0) {
    return (
      <div className="py-10 px-2">
        <div className="h-0.5 w-8 rounded-full mb-4 bg-muted-foreground/30" />
        <p className="font-bold tracking-tight text-base leading-none mb-1">{t.chords.glossary.noResults}</p>
        <p className="text-xs text-muted-foreground">{t.common.tryDifferentSearch}</p>
      </div>
    )
  }

  return (
    <>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {chords.map((chord) => (
          <ChordCard key={`${chord.key}-${chord.suffix}`} chord={chord} onClick={() => setSelected(chord)} />
        ))}
      </div>

      <ChordDiagram chordName={selectedName} onClose={() => setSelected(null)} />
    </>
  )
}
