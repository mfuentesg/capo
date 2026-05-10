"use client"

import { useState } from "react"
import { PlusCircle } from "lucide-react"
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent
} from "@dnd-kit/core"
import { restrictToVerticalAxis } from "@dnd-kit/modifiers"
import { SortableContext, verticalListSortingStrategy, arrayMove } from "@dnd-kit/sortable"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import { blockNextDocumentClick } from "@/lib/dnd"
import { useTranslation } from "@/hooks/use-translation"
import { cn } from "@/lib/utils"
import type { SongBlock, SongBlockType, VisualSongAST } from "../types/visual-song-ast"
import { isVoltaGroup } from "../types/visual-song-ast"
import { VisualSongBlock } from "./visual-song-block"

const SECTION_TYPES: SongBlockType[] = [
  "verse",
  "chorus",
  "bridge",
  "intro",
  "outro",
  "pre-chorus"
]

interface InsertButtonProps {
  onInsert: (type: SongBlockType) => void
  label: string
  sectionTypeLabels: Record<string, string>
}

function InsertButton({ onInsert, label, sectionTypeLabels }: InsertButtonProps) {
  const [open, setOpen] = useState(false)

  return (
    <div
      className={cn(
        "flex items-center gap-2 group/insert",
        "opacity-0 hover:opacity-100 focus-within:opacity-100 transition-opacity"
      )}
    >
      <div className="flex-1 h-px bg-border/50 group-hover/insert:bg-border transition-colors" />
      <DropdownMenu open={open} onOpenChange={setOpen}>
        <DropdownMenuTrigger asChild>
          <button
            className={cn(
              "flex items-center gap-1 text-xs text-muted-foreground/60 hover:text-primary",
              "rounded-full border border-dashed border-border/60 hover:border-primary/60",
              "px-2 py-0.5 transition-colors shrink-0"
            )}
            aria-label={label}
          >
            <PlusCircle className="h-3 w-3" />
            <span>{label}</span>
          </button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="center" side="bottom" className="min-w-32">
          {SECTION_TYPES.map((type) => (
            <DropdownMenuItem key={type} onClick={() => onInsert(type)}>
              {sectionTypeLabels[type] ?? type}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>
      <div className="flex-1 h-px bg-border/50 group-hover/insert:bg-border transition-colors" />
    </div>
  )
}

interface VisualSongEditorProps {
  ast: VisualSongAST
  songKey?: string
  onChange: (ast: VisualSongAST) => void
}

export function VisualSongEditor({ ast, songKey, onChange }: VisualSongEditorProps) {
  const { t } = useTranslation()

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: { delay: 200, tolerance: 5 }
    })
  )

  function updateBlocks(blocks: SongBlock[]) {
    onChange({ ...ast, blocks })
  }

  function handleBlockChange(index: number, updated: SongBlock) {
    const blocks = [...ast.blocks]
    blocks[index] = updated
    updateBlocks(blocks)
  }

  function handleBlockDelete(index: number) {
    updateBlocks(ast.blocks.filter((_, i) => i !== index))
  }

  function handleBlockDuplicate(index: number) {
    const source = ast.blocks[index]
    const duplicate: SongBlock = {
      ...source,
      id: crypto.randomUUID(),
      lines: source.lines.map((sl) => {
        if (isVoltaGroup(sl)) {
          return {
            ...sl,
            id: crypto.randomUUID(),
            lines: sl.lines.map((l) => ({
              ...l,
              id: crypto.randomUUID(),
              chords: l.chords.map((c) => ({ ...c, id: crypto.randomUUID() }))
            }))
          }
        }
        return {
          ...sl,
          id: crypto.randomUUID(),
          chords: sl.chords.map((c) => ({ ...c, id: crypto.randomUUID() }))
        }
      })
    }
    const blocks = [...ast.blocks]
    blocks.splice(index + 1, 0, duplicate)
    updateBlocks(blocks)
  }

  function handleInsertAt(index: number, type: SongBlockType) {
    const newBlock: SongBlock = {
      id: crypto.randomUUID(),
      type,
      lines: [{ id: crypto.randomUUID(), text: "", chords: [] }]
    }
    const blocks = [...ast.blocks]
    blocks.splice(index, 0, newBlock)
    updateBlocks(blocks)
  }

  function handleDragEnd(event: DragEndEvent) {
    blockNextDocumentClick()
    const { active, over } = event
    if (!over || active.id === over.id) return
    const oldIndex = ast.blocks.findIndex((b) => b.id === active.id)
    const newIndex = ast.blocks.findIndex((b) => b.id === over.id)
    if (oldIndex !== -1 && newIndex !== -1) {
      updateBlocks(arrayMove(ast.blocks, oldIndex, newIndex))
    }
  }

  const insertLabel = t.songs.lyrics.visual.insertSection
  const sectionTypeLabels = t.songs.lyrics.visual.sectionTypes as Record<string, string>

  if (ast.blocks.length === 0) {
    return (
      <div className="rounded-lg border bg-card p-8 text-center text-sm text-muted-foreground">
        {t.songs.lyrics.visual.emptyState}
      </div>
    )
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      modifiers={[restrictToVerticalAxis]}
      onDragEnd={handleDragEnd}
      onDragCancel={blockNextDocumentClick}
    >
      <SortableContext items={ast.blocks.map((b) => b.id)} strategy={verticalListSortingStrategy}>
        <div className="space-y-1">
          {/* Insert button before first block */}
          <InsertButton
            onInsert={(type) => handleInsertAt(0, type)}
            label={insertLabel}
            sectionTypeLabels={sectionTypeLabels}
          />

          {ast.blocks.map((block, index) => (
            <div key={block.id} className="space-y-1">
              <VisualSongBlock
                block={block}
                songKey={songKey}
                onChange={(updated) => handleBlockChange(index, updated)}
                onDelete={() => handleBlockDelete(index)}
                onDuplicate={() => handleBlockDuplicate(index)}
              />
              {/* Insert button after each block */}
              <InsertButton
                onInsert={(type) => handleInsertAt(index + 1, type)}
                label={insertLabel}
                sectionTypeLabels={sectionTypeLabels}
              />
            </div>
          ))}
        </div>
      </SortableContext>
    </DndContext>
  )
}
