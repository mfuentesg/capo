"use client"

import { Volume2, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import { useLocale } from "@/features/settings"
import { useChordAudio } from "../hooks/use-chord-audio"

interface ChordPlayButtonProps {
  midiNotes: number[] | undefined
  className?: string
}

export function ChordPlayButton({ midiNotes, className }: ChordPlayButtonProps) {
  const { play, isLoading, isPlaying } = useChordAudio()
  const { t } = useLocale()

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
      disabled={isLoading || isPlaying}
      aria-label={t.chords.playChord}
    >
      {isLoading ? (
        <Loader2 className="h-4 w-4 animate-spin" />
      ) : (
        <Volume2 className={cn("h-4 w-4 transition-transform duration-150", isPlaying && "scale-110")} />
      )}
    </Button>
  )
}
