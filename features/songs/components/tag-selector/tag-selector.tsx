"use client"

import { useState, useRef } from "react"
import { Plus, Tag, Trash2, Check, Loader2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import {
  Popover,
  PopoverContent,
  PopoverTrigger
} from "@/components/ui/popover"
import { cn } from "@/lib/utils"
import type { SongTag } from "@/features/songs/types"
import { TagBadge } from "../tag-badge"
import { useTranslation } from "@/hooks/use-translation"

const PRESET_COLORS = [
  "#ef4444",
  "#f97316",
  "#eab308",
  "#22c55e",
  "#06b6d4",
  "#3b82f6",
  "#8b5cf6",
  "#ec4899"
]

interface TagSelectorProps {
  selectedTags: SongTag[]
  availableTags: SongTag[]
  onTagsChange: (tags: SongTag[]) => void
  onCreateTag: (name: string, color: string) => Promise<SongTag>
  onDeleteTag?: (tagId: string) => void
  disabled?: boolean
}

export function TagSelector({
  selectedTags,
  availableTags,
  onTagsChange,
  onCreateTag,
  onDeleteTag,
  disabled = false
}: TagSelectorProps) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState("")
  const [creating, setCreating] = useState(false)
  const [selectedColor, setSelectedColor] = useState(PRESET_COLORS[5])
  const inputRef = useRef<HTMLInputElement>(null)

  const selectedIds = new Set(selectedTags.map((t) => t.id))

  const filtered = availableTags.filter((tag) =>
    tag.name.toLowerCase().includes(search.trim().toLowerCase())
  )

  const exactMatch = availableTags.some(
    (tag) => tag.name.toLowerCase() === search.trim().toLowerCase()
  )

  const canCreate = search.trim().length > 0 && !exactMatch

  const toggle = (tag: SongTag) => {
    if (selectedIds.has(tag.id)) {
      onTagsChange(selectedTags.filter((t) => t.id !== tag.id))
    } else {
      onTagsChange([...selectedTags, tag])
    }
  }

  const handleCreate = async () => {
    const name = search.trim()
    if (!name) return
    setCreating(true)
    try {
      const newTag = await onCreateTag(name, selectedColor)
      onTagsChange([...selectedTags, newTag])
      setSearch("")
    } finally {
      setCreating(false)
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter" && canCreate) {
      e.preventDefault()
      void handleCreate()
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-1.5">
      {selectedTags.map((tag) => (
        <TagBadge
          key={tag.id}
          tag={tag}
          onRemove={() => onTagsChange(selectedTags.filter((t) => t.id !== tag.id))}
        />
      ))}

      <Popover
        open={open}
        onOpenChange={(next) => {
          setOpen(next)
          if (next) setTimeout(() => inputRef.current?.focus(), 50)
          else setSearch("")
        }}
      >
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            disabled={disabled}
            className="h-6 gap-1 rounded-full px-2 text-[11px] border-dashed text-muted-foreground hover:text-foreground"
          >
            <Plus className="h-3 w-3" />
            {t.songs.tags.addTag}
          </Button>
        </PopoverTrigger>

        <PopoverContent
          className="w-64 p-0 data-[state=closed]:pointer-events-none"
          align="start"
        >
          <div className="p-2 border-b">
            <Input
              ref={inputRef}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t.songs.tags.searchOrCreate}
              className="h-7 text-xs shadow-none"
            />
          </div>

          <div className="max-h-48 overflow-y-auto p-1">
            {filtered.length === 0 && !canCreate && (
              <p className="py-4 text-center text-xs text-muted-foreground">
                {t.songs.tags.noTags}
              </p>
            )}

            {filtered.map((tag) => (
              <div
                key={tag.id}
                className="group flex items-center justify-between rounded-sm px-2 py-1.5 hover:bg-accent cursor-pointer"
                onClick={() => toggle(tag)}
              >
                <div className="flex items-center gap-2 min-w-0">
                  <span
                    className="h-2.5 w-2.5 rounded-full shrink-0"
                    style={{ background: tag.color ?? "#6b7280" }}
                  />
                  <span className="text-xs truncate">{tag.name}</span>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                  {selectedIds.has(tag.id) && (
                    <Check className="h-3.5 w-3.5 text-primary" />
                  )}
                  {onDeleteTag && (
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        onDeleteTag(tag.id)
                      }}
                      className="opacity-0 group-hover:opacity-60 hover:!opacity-100 transition-opacity p-0.5 rounded"
                      aria-label={`Delete ${tag.name} tag`}
                    >
                      <Trash2 className="h-3 w-3 text-destructive" />
                    </button>
                  )}
                </div>
              </div>
            ))}

            {canCreate && (
              <>
                {filtered.length > 0 && (
                  <div className="my-1 border-t" />
                )}
                <div className="px-2 py-1.5 space-y-2">
                  <p className="text-[11px] text-muted-foreground">
                    {t.songs.tags.createTag}:{" "}
                    <span className="font-medium text-foreground">&quot;{search.trim()}&quot;</span>
                  </p>
                  <div className="flex items-center gap-1">
                    {PRESET_COLORS.map((c) => (
                      <button
                        key={c}
                        onClick={() => setSelectedColor(c)}
                        className={cn(
                          "h-4 w-4 rounded-full transition ring-offset-background",
                          selectedColor === c ? "ring-2 ring-ring ring-offset-1" : ""
                        )}
                        style={{ background: c }}
                        aria-label={`Color ${c}`}
                      />
                    ))}
                  </div>
                  <Button
                    size="sm"
                    className="h-7 w-full text-xs gap-1.5"
                    onClick={handleCreate}
                    disabled={creating}
                  >
                    {creating ? (
                      <Loader2 className="h-3 w-3 animate-spin" />
                    ) : (
                      <Tag className="h-3 w-3" />
                    )}
                    {t.songs.tags.create}
                  </Button>
                </div>
              </>
            )}
          </div>
        </PopoverContent>
      </Popover>
    </div>
  )
}
