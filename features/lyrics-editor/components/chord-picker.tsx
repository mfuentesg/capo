"use client"

import { useState, useEffect, useRef, useMemo } from "react"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { searchChords, toDbKey, keyLabel } from "@/features/chords"
import { useTranslation } from "@/hooks/use-translation"
import { cn } from "@/lib/utils"

const DIATONIC_SUFFIXES = ["major", "minor", "7", "m7", "maj7", "sus2", "sus4"]

interface ChordPickerProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  songKey?: string
  initialChord?: string
  onConfirm: (chord: string) => void
  trigger: React.ReactNode
}

function buildSuggestions(songKey: string): string[] {
  const dbKey = toDbKey(songKey.replace(/m$/, ""))
  const results = searchChords(keyLabel(dbKey))
  const diatonic = results
    .filter((c) => DIATONIC_SUFFIXES.includes(c.suffix))
    .slice(0, 12)
    .map((c) => c.name)
  const root = songKey.replace(/m$/, "")
  const seen = new Set<string>()
  const unique: string[] = []
  for (const c of [root, ...diatonic]) {
    if (!seen.has(c)) {
      seen.add(c)
      unique.push(c)
    }
  }
  return unique
}

export function ChordPicker({
  open,
  onOpenChange,
  songKey,
  initialChord = "",
  onConfirm,
  trigger
}: ChordPickerProps) {
  const { t } = useTranslation()
  const [query, setQuery] = useState(initialChord)
  const [prevOpen, setPrevOpen] = useState(open)
  const inputRef = useRef<HTMLInputElement>(null)

  // Reset query to initialChord each time the popover opens (during render, not in an effect)
  if (open !== prevOpen) {
    setPrevOpen(open)
    if (open) setQuery(initialChord)
  }

  const suggestions = useMemo(() => {
    if (query.trim()) {
      return searchChords(query).slice(0, 16).map((c) => c.name)
    }
    if (songKey) return buildSuggestions(songKey)
    return []
  }, [query, songKey])

  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 0)
  }, [open])

  function handleConfirm(chord: string) {
    const trimmed = chord.trim()
    if (!trimmed) return
    onConfirm(trimmed)
    onOpenChange(false)
  }

  return (
    <Popover open={open} onOpenChange={onOpenChange}>
      <PopoverTrigger asChild>{trigger}</PopoverTrigger>
      <PopoverContent className="w-64 p-3" side="top" align="start">
        <div className="space-y-3">
          <div className="flex gap-2">
            <Input
              ref={inputRef}
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={t.songs.lyrics.visual.chordPlaceholder}
              className="h-8 text-sm"
              onKeyDown={(e) => {
                if (e.key === "Enter") handleConfirm(query)
                if (e.key === "Escape") onOpenChange(false)
              }}
            />
            <Button
              size="sm"
              className="h-8 shrink-0"
              onClick={() => handleConfirm(query)}
              disabled={!query.trim()}
            >
              {t.common.save}
            </Button>
          </div>

          {suggestions.length > 0 && (
            <div className="flex flex-wrap gap-1">
              {suggestions.map((chord) => (
                <button
                  key={chord}
                  onClick={() => handleConfirm(chord)}
                  className={cn(
                    "rounded px-2 py-0.5 text-xs font-medium border",
                    "transition-colors hover:bg-primary hover:text-primary-foreground hover:border-primary",
                    chord === query
                      ? "bg-primary text-primary-foreground border-primary"
                      : "bg-muted text-muted-foreground border-transparent"
                  )}
                >
                  {chord}
                </button>
              ))}
            </div>
          )}
        </div>
      </PopoverContent>
    </Popover>
  )
}
