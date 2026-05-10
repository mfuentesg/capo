"use client"

import { useState, useRef } from "react"
import { X, Plus } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useTranslation } from "@/hooks/use-translation"
import { cn } from "@/lib/utils"
import type { ChordToken, LyricLine } from "../types/visual-song-ast"
import { ChordPicker } from "./chord-picker"

interface VisualLyricLineProps {
  line: LyricLine
  songKey?: string
  onChange: (updated: LyricLine) => void
  onDelete: () => void
  isLast?: boolean
}

export function VisualLyricLine({ line, songKey, onChange, onDelete, isLast }: VisualLyricLineProps) {
  const { t } = useTranslation()
  const [pickerOpen, setPickerOpen] = useState(false)
  const [editingChordId, setEditingChordId] = useState<string | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const sortedChords = [...line.chords].sort((a, b) => a.offset - b.offset)

  function updateChords(chords: ChordToken[]) {
    onChange({ ...line, chords })
  }

  function handleTextChange(text: string) {
    // Clamp existing chord offsets to new text length
    const chords = line.chords.map((c) => ({
      ...c,
      offset: Math.min(c.offset, text.length)
    }))
    onChange({ ...line, text, chords })
  }

  function handleAddChord(chord: string) {
    const offset = inputRef.current
      ? Math.min(
          inputRef.current.selectionStart ?? line.text.length,
          line.text.length
        )
      : line.text.length
    const newChord: ChordToken = { id: crypto.randomUUID(), chord, offset }
    updateChords([...line.chords, newChord])
    setPickerOpen(false)
  }

  function handleEditChord(id: string, chord: string) {
    updateChords(line.chords.map((c) => (c.id === id ? { ...c, chord } : c)))
    setEditingChordId(null)
  }

  function handleRemoveChord(id: string) {
    updateChords(line.chords.filter((c) => c.id !== id))
  }

  function shiftChord(id: string, direction: -1 | 1) {
    updateChords(
      line.chords.map((c) =>
        c.id === id
          ? { ...c, offset: Math.max(0, Math.min(c.offset + direction, line.text.length)) }
          : c
      )
    )
  }

  return (
    <div className="group/line relative">
      {/* Chord row */}
      <div className="flex items-center flex-wrap gap-1 min-h-6 mb-0.5 pl-0.5">
        {sortedChords.map((token) => (
          <ChordPicker
            key={token.id}
            open={editingChordId === token.id}
            onOpenChange={(open) => {
              if (!open) setEditingChordId(null)
            }}
            songKey={songKey}
            initialChord={token.chord}
            onConfirm={(chord) => handleEditChord(token.id, chord)}
            trigger={
              <div className="inline-flex items-center gap-0.5 group/chip">
                <button
                  className="font-mono text-xs font-semibold text-primary bg-primary/10 hover:bg-primary/20 rounded px-1.5 py-0.5 leading-none transition-colors"
                  onClick={() => setEditingChordId(token.id)}
                  title={t.songs.lyrics.visual.editChord}
                >
                  {token.chord}
                </button>
                <div className="hidden group-hover/chip:flex items-center gap-px">
                  <button
                    className="text-muted-foreground hover:text-foreground text-xs leading-none px-0.5 rounded"
                    onClick={() => shiftChord(token.id, -1)}
                    title={t.songs.lyrics.visual.moveChordLeft}
                    aria-label={t.songs.lyrics.visual.moveChordLeft}
                  >
                    ‹
                  </button>
                  <button
                    className="text-muted-foreground hover:text-foreground text-xs leading-none px-0.5 rounded"
                    onClick={() => shiftChord(token.id, 1)}
                    title={t.songs.lyrics.visual.moveChordRight}
                    aria-label={t.songs.lyrics.visual.moveChordRight}
                  >
                    ›
                  </button>
                  <button
                    className="text-muted-foreground hover:text-destructive text-xs leading-none px-0.5 rounded"
                    onClick={() => handleRemoveChord(token.id)}
                    title={t.songs.lyrics.visual.removeChord}
                    aria-label={t.songs.lyrics.visual.removeChord}
                  >
                    ×
                  </button>
                </div>
              </div>
            }
          />
        ))}

        {/* Add chord button */}
        <ChordPicker
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          songKey={songKey}
          onConfirm={handleAddChord}
          trigger={
            <button
              className={cn(
                "text-xs text-muted-foreground/40 hover:text-primary rounded px-1 leading-none transition-colors",
                "opacity-0 group-hover/line:opacity-100"
              )}
              onClick={() => setPickerOpen(true)}
              title={t.songs.lyrics.visual.addChord}
              aria-label={t.songs.lyrics.visual.addChord}
            >
              <Plus className="h-3 w-3" />
            </button>
          }
        />
      </div>

      {/* Lyric row */}
      <div className="flex items-center gap-1">
        <input
          ref={inputRef}
          type="text"
          value={line.text}
          onChange={(e) => handleTextChange(e.target.value)}
          className={cn(
            "flex-1 bg-transparent text-sm outline-none border-b border-transparent",
            "hover:border-border focus:border-primary transition-colors py-0.5",
            "placeholder:text-muted-foreground/40"
          )}
          placeholder={t.songs.lyrics.visual.linePlaceholder}
        />
        <Button
          variant="ghost"
          size="icon"
          className={cn(
            "h-6 w-6 shrink-0 text-muted-foreground/40 hover:text-destructive",
            "opacity-0 group-hover/line:opacity-100 transition-opacity"
          )}
          onClick={onDelete}
          aria-label={t.songs.lyrics.visual.deleteLine}
          title={t.songs.lyrics.visual.deleteLine}
        >
          <X className="h-3 w-3" />
        </Button>
      </div>

      {/* Line separator (not on last) */}
      {!isLast && <div className="my-2 border-t border-dashed border-border/40" />}
    </div>
  )
}
