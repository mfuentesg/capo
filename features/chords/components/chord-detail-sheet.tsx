"use client"

import * as React from "react"
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet"
import {
  ChordPositionDiagram,
  type ChordPosition,
} from "@/components/chord-position-diagram"
import { type ChordEntry } from "../utils/chord-db-helpers"
import { cn } from "@/lib/utils"
import { useLocale } from "@/features/settings"
import { useChordOrientation } from "@/hooks/use-chord-orientation"
import { ChordPlayButton, useChordAudio } from "@/features/chord-audio"

interface ChordDetailSheetProps {
  chord: ChordEntry | null
  onClose: () => void
}

export function ChordDetailSheet({ chord, onClose }: ChordDetailSheetProps) {
  const [positionIndex, setPositionIndex] = React.useState(0)
  const [animKey, setAnimKey] = React.useState(0)
  const [slideDir, setSlideDir] = React.useState<"left" | "right">("left")
  const { t } = useLocale()
  const { mirror } = useChordOrientation()
  const touchStartX = React.useRef(0)
  const { stop } = useChordAudio()

  React.useEffect(() => {
    setPositionIndex(0)
    if (!chord) stop()
  }, [chord, stop])


  if (!chord) return null

  const displayName = chord.name
  const total = chord.positions.length
  const current = chord.positions[positionIndex] as ChordPosition

  const navigate = (dir: "left" | "right", next: number) => {
    setSlideDir(dir)
    setAnimKey((k) => k + 1)
    setPositionIndex(next)
  }

  const goPrev = () => navigate("right", positionIndex > 0 ? positionIndex - 1 : total - 1)
  const goNext = () => navigate("left", positionIndex < total - 1 ? positionIndex + 1 : 0)

  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX
  }
  const handleTouchEnd = (e: React.TouchEvent) => {
    const dx = e.changedTouches[0].clientX - touchStartX.current
    if (Math.abs(dx) > 40) {
      if (dx > 0) goPrev()
      else goNext()
    }
  }

  return (
    <Sheet open={!!chord} onOpenChange={(open) => !open && onClose()}>
      <SheetContent side="bottom" className="h-auto max-h-[90dvh] rounded-t-2xl pb-safe">
        <style>{`
          @keyframes slideFromRight { from { transform: translateX(48px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
          @keyframes slideFromLeft  { from { transform: translateX(-48px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
        `}</style>

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

        <div
          className="flex flex-col items-center gap-4 overflow-hidden"
          onTouchStart={total > 1 ? handleTouchStart : undefined}
          onTouchEnd={total > 1 ? handleTouchEnd : undefined}
        >
          <div
            key={animKey}
            className="w-full rounded-2xl bg-white dark:bg-zinc-950 border border-border/50 px-4 py-5 shadow-md"
            style={{
              animation: animKey > 0
                ? `${slideDir === "left" ? "slideFromRight" : "slideFromLeft"} 0.25s ease-out`
                : undefined,
            }}
          >
            {current && (
              <ChordPositionDiagram
                position={current}
                mirror={mirror}
              />
            )}
          </div>

          {total > 1 && (
            <div className="flex gap-2">
              {chord.positions.map((_, i) => (
                <button
                  key={i}
                  type="button"
                  onClick={() => navigate(i > positionIndex ? "left" : "right", i)}
                  aria-label={`Variation ${i + 1}`}
                  className={cn(
                    "h-1.5 rounded-full transition-[width,background-color] duration-200",
                    i === positionIndex
                      ? "w-6 bg-primary"
                      : "w-1.5 bg-muted-foreground/30 hover:bg-muted-foreground/50"
                  )}
                />
              ))}
            </div>
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}
