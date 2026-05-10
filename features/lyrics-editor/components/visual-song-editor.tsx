"use client"

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
import { blockNextDocumentClick } from "@/lib/dnd"
import { useTranslation } from "@/hooks/use-translation"
import type { SongBlock, VisualSongAST } from "../types/visual-song-ast"
import { VisualSongBlock } from "./visual-song-block"

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
      lines: source.lines.map((line) => ({
        ...line,
        id: crypto.randomUUID(),
        chords: line.chords.map((chord) => ({ ...chord, id: crypto.randomUUID() }))
      }))
    }
    const blocks = [...ast.blocks]
    blocks.splice(index + 1, 0, duplicate)
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
      <SortableContext
        items={ast.blocks.map((b) => b.id)}
        strategy={verticalListSortingStrategy}
      >
        <div className="space-y-3">
          {ast.blocks.map((block, index) => (
            <VisualSongBlock
              key={block.id}
              block={block}
              songKey={songKey}
              onChange={(updated) => handleBlockChange(index, updated)}
              onDelete={() => handleBlockDelete(index)}
              onDuplicate={() => handleBlockDuplicate(index)}
            />
          ))}
        </div>
      </SortableContext>
    </DndContext>
  )
}
