"use client"

import { useState } from "react"
import { Trash2, Plus } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useTranslation } from "@/hooks/use-translation"
import { cn } from "@/lib/utils"
import type { LyricLine, VoltaGroup } from "../types/visual-song-ast"
import { VisualLyricLine } from "./visual-lyric-line"

interface VisualVoltaGroupProps {
  group: VoltaGroup
  songKey?: string
  onChange: (updated: VoltaGroup) => void
  onDelete: () => void
}

export function VisualVoltaGroup({ group, songKey, onChange, onDelete }: VisualVoltaGroupProps) {
  const { t } = useTranslation()
  const [isEditingLabel, setIsEditingLabel] = useState(false)
  const [labelDraft, setLabelDraft] = useState(group.label ?? "")

  function updateLines(lines: LyricLine[]) {
    onChange({ ...group, lines })
  }

  function handleLineChange(index: number, updated: LyricLine) {
    const lines = [...group.lines]
    lines[index] = updated
    updateLines(lines)
  }

  function handleLineDelete(index: number) {
    if (group.lines.length <= 1) return
    updateLines(group.lines.filter((_, i) => i !== index))
  }

  function handleAddLine() {
    updateLines([...group.lines, { id: crypto.randomUUID(), text: "", chords: [] }])
  }

  function handleLabelSubmit() {
    onChange({ ...group, label: labelDraft.trim() || undefined })
    setIsEditingLabel(false)
  }

  const displayLabel = group.label || t.songs.lyrics.visual.volta

  return (
    <div className={cn("rounded border border-dashed border-border/60 bg-muted/30 ml-2")}>
      {/* Volta header */}
      <div className="flex items-center gap-2 px-2 py-1 border-b border-dashed border-border/40">
        <span className="text-xs text-muted-foreground/60 font-medium shrink-0">
          {t.songs.lyrics.visual.voltaLabel}
        </span>

        {isEditingLabel ? (
          <input
            autoFocus
            className="flex-1 text-xs font-medium bg-transparent border-b border-muted-foreground/30 outline-none min-w-0"
            value={labelDraft}
            onChange={(e) => setLabelDraft(e.target.value)}
            onBlur={handleLabelSubmit}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleLabelSubmit()
              if (e.key === "Escape") setIsEditingLabel(false)
            }}
          />
        ) : (
          <button
            className="flex-1 text-left text-xs font-medium text-muted-foreground hover:text-foreground transition-colors truncate"
            onClick={() => {
              setLabelDraft(group.label ?? "")
              setIsEditingLabel(true)
            }}
            title={t.songs.lyrics.visual.clickToEditLabel}
          >
            {displayLabel}
          </button>
        )}

        <Button
          variant="ghost"
          size="icon"
          className="h-5 w-5 shrink-0 text-muted-foreground/40 hover:text-destructive hover:bg-transparent"
          onClick={onDelete}
          aria-label={t.songs.lyrics.visual.deleteVolta}
          title={t.songs.lyrics.visual.deleteVolta}
        >
          <Trash2 className="h-3 w-3" />
        </Button>
      </div>

      {/* Lines inside the volta group */}
      <div className="px-2 py-2 space-y-0" data-vaul-no-drag>
        {group.lines.map((line, index) => (
          <VisualLyricLine
            key={line.id}
            line={line}
            songKey={songKey}
            onChange={(updated) => handleLineChange(index, updated)}
            onDelete={() => handleLineDelete(index)}
            isLast={index === group.lines.length - 1}
          />
        ))}

        <button
          className="mt-1.5 flex items-center gap-1 text-xs text-muted-foreground/40 hover:text-muted-foreground transition-colors"
          onClick={handleAddLine}
        >
          <Plus className="h-3 w-3" />
          {t.songs.lyrics.visual.addLine}
        </button>
      </div>
    </div>
  )
}
