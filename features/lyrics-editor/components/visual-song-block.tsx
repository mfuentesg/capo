"use client"

import { useState } from "react"
import { GripVertical, Trash2, Copy, Plus } from "lucide-react"
import { useSortable } from "@dnd-kit/sortable"
import { CSS } from "@dnd-kit/utilities"
import { Button } from "@/components/ui/button"
import { useTranslation } from "@/hooks/use-translation"
import { cn } from "@/lib/utils"
import type { LyricLine, SongBlock, SongBlockType, SongLine, VoltaGroup } from "../types/visual-song-ast"
import { isVoltaGroup } from "../types/visual-song-ast"
import { VisualLyricLine } from "./visual-lyric-line"
import { VisualVoltaGroup } from "./visual-volta-group"

const BLOCK_TYPE_COLORS: Record<SongBlockType, string> = {
  verse: "bg-blue-500/10 text-blue-700 dark:text-blue-300 border-blue-500/20",
  chorus: "bg-purple-500/10 text-purple-700 dark:text-purple-300 border-purple-500/20",
  bridge: "bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/20",
  intro: "bg-green-500/10 text-green-700 dark:text-green-300 border-green-500/20",
  outro: "bg-red-500/10 text-red-700 dark:text-red-300 border-red-500/20",
  "pre-chorus": "bg-indigo-500/10 text-indigo-700 dark:text-indigo-300 border-indigo-500/20",
  tab: "bg-orange-500/10 text-orange-700 dark:text-orange-300 border-orange-500/20",
  custom: "bg-muted text-muted-foreground border-border"
}

interface VisualSongBlockProps {
  block: SongBlock
  songKey?: string
  onChange: (updated: SongBlock) => void
  onDelete: () => void
  onDuplicate: () => void
}

export function VisualSongBlock({
  block,
  songKey,
  onChange,
  onDelete,
  onDuplicate
}: VisualSongBlockProps) {
  const { t } = useTranslation()
  const [isEditingLabel, setIsEditingLabel] = useState(false)
  const [labelDraft, setLabelDraft] = useState(block.label ?? "")

  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({
    id: block.id
  })

  const sortStyle = {
    transform: CSS.Transform.toString(transform),
    transition
  }

  const blockTypeLabel = t.songs.lyrics.visual.sectionTypes[block.type] ?? block.type
  const displayLabel = block.label || blockTypeLabel
  const colorClass = BLOCK_TYPE_COLORS[block.type]

  function updateLines(lines: SongLine[]) {
    onChange({ ...block, lines })
  }

  function handleSongLineChange(index: number, updated: SongLine) {
    const lines = [...block.lines]
    lines[index] = updated
    updateLines(lines)
  }

  function handleSongLineDelete(index: number) {
    if (block.lines.length <= 1) return
    updateLines(block.lines.filter((_, i) => i !== index))
  }

  function handleAddLine() {
    const newLine: LyricLine = { id: crypto.randomUUID(), text: "", chords: [] }
    updateLines([...block.lines, newLine])
  }

  function handleAddVolta() {
    const newVolta: VoltaGroup = {
      id: crypto.randomUUID(),
      lines: [{ id: crypto.randomUUID(), text: "", chords: [] }]
    }
    updateLines([...block.lines, newVolta])
  }

  function handleLabelSubmit() {
    onChange({ ...block, label: labelDraft.trim() || undefined })
    setIsEditingLabel(false)
  }

  // Count only non-volta lines for minimum enforcement
  const lyricLineCount = block.lines.filter((l) => !isVoltaGroup(l)).length

  return (
    <div
      ref={setNodeRef}
      style={sortStyle}
      {...attributes}
      className={cn("rounded-lg border bg-card", isDragging && "opacity-60 shadow-lg z-50")}
    >
      {/* Block header */}
      <div className={cn("flex items-center gap-2 px-3 py-2 rounded-t-lg border-b", colorClass)}>
        {/* Drag handle */}
        <div
          {...listeners}
          className="cursor-grab touch-none shrink-0 text-current opacity-40 hover:opacity-70"
          aria-label={t.songs.lyrics.visual.dragToReorder}
        >
          <GripVertical className="h-4 w-4" />
        </div>

        {/* Label */}
        {isEditingLabel ? (
          <input
            autoFocus
            className="flex-1 text-xs font-semibold uppercase tracking-wider bg-transparent border-b border-current/30 outline-none"
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
            className="flex-1 text-left text-xs font-semibold uppercase tracking-wider hover:opacity-70 transition-opacity"
            onClick={() => {
              setLabelDraft(block.label ?? "")
              setIsEditingLabel(true)
            }}
            title={t.songs.lyrics.visual.clickToEditLabel}
          >
            {displayLabel}
          </button>
        )}

        {/* Actions */}
        <div className="flex items-center gap-0.5 shrink-0">
          <Button
            variant="ghost"
            size="icon"
            className="h-6 w-6 text-current opacity-50 hover:opacity-100 hover:bg-transparent"
            onClick={onDuplicate}
            title={t.songs.lyrics.visual.duplicateSection}
            aria-label={t.songs.lyrics.visual.duplicateSection}
          >
            <Copy className="h-3 w-3" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            className="h-6 w-6 text-current opacity-50 hover:opacity-100 hover:bg-transparent hover:text-destructive"
            onClick={onDelete}
            title={t.songs.lyrics.visual.deleteSection}
            aria-label={t.songs.lyrics.visual.deleteSection}
          >
            <Trash2 className="h-3 w-3" />
          </Button>
        </div>
      </div>

      {/* Lines */}
      <div className="p-3 space-y-2" data-vaul-no-drag>
        {block.lines.map((songLine, index) =>
          isVoltaGroup(songLine) ? (
            <VisualVoltaGroup
              key={songLine.id}
              group={songLine}
              songKey={songKey}
              onChange={(updated) => handleSongLineChange(index, updated)}
              onDelete={() => handleSongLineDelete(index)}
            />
          ) : (
            <VisualLyricLine
              key={songLine.id}
              line={songLine}
              songKey={songKey}
              onChange={(updated) => handleSongLineChange(index, updated)}
              onDelete={() => {
                if (lyricLineCount > 1) handleSongLineDelete(index)
              }}
              isLast={index === block.lines.length - 1}
            />
          )
        )}

        {/* Footer actions */}
        <div className="flex items-center gap-3 pt-1">
          <button
            className="flex items-center gap-1 text-xs text-muted-foreground/50 hover:text-muted-foreground transition-colors"
            onClick={handleAddLine}
          >
            <Plus className="h-3 w-3" />
            {t.songs.lyrics.visual.addLine}
          </button>
          <button
            className="flex items-center gap-1 text-xs text-muted-foreground/50 hover:text-muted-foreground transition-colors"
            onClick={handleAddVolta}
          >
            <Plus className="h-3 w-3" />
            {t.songs.lyrics.visual.addVolta}
          </button>
        </div>
      </div>
    </div>
  )
}
