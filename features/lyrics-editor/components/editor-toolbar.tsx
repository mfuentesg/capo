"use client"

import { Code, Eye, BookOpen, PlusCircle } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import { Separator } from "@/components/ui/separator"
import { useTranslation } from "@/hooks/use-translation"
import { cn } from "@/lib/utils"
import type { SongBlockType } from "../types/visual-song-ast"

export type EditorMode = "code" | "visual"

const SECTION_TYPES: SongBlockType[] = [
  "verse",
  "chorus",
  "bridge",
  "intro",
  "outro",
  "pre-chorus"
]

interface EditorToolbarProps {
  mode: EditorMode
  onModeChange: (mode: EditorMode) => void
  onAddSection?: (type: SongBlockType) => void
  onOpenReference?: () => void
}

export function EditorToolbar({
  mode,
  onModeChange,
  onAddSection,
  onOpenReference
}: EditorToolbarProps) {
  const { t } = useTranslation()

  return (
    <div className="sticky top-[4.5rem] z-10 flex items-center gap-2 border-b bg-muted/40 px-4 py-1.5 backdrop-blur-sm">
      {/* Mode toggle */}
      <div className="flex items-center rounded-md border bg-background p-0.5">
        <Button
          variant={mode === "code" ? "secondary" : "ghost"}
          size="sm"
          className={cn("h-7 gap-1.5 px-2.5 text-xs", mode === "code" && "shadow-sm")}
          onClick={() => onModeChange("code")}
          aria-pressed={mode === "code"}
        >
          <Code className="h-3 w-3" />
          {t.songs.lyrics.visual.modeCode}
        </Button>
        <Button
          variant={mode === "visual" ? "secondary" : "ghost"}
          size="sm"
          className={cn("h-7 gap-1.5 px-2.5 text-xs", mode === "visual" && "shadow-sm")}
          onClick={() => onModeChange("visual")}
          aria-pressed={mode === "visual"}
        >
          <Eye className="h-3 w-3" />
          {t.songs.lyrics.visual.modeVisual}
        </Button>
      </div>

      <div className="flex-1" />

      {/* Right side — contextual actions */}
      {mode === "visual" && onAddSection && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" size="sm" className="h-7 gap-1.5 px-2.5 text-xs">
              <PlusCircle className="h-3 w-3" />
              {t.songs.lyrics.visual.addSection}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {SECTION_TYPES.map((type) => (
              <DropdownMenuItem key={type} onClick={() => onAddSection(type)}>
                {t.songs.lyrics.visual.sectionTypes[type]}
              </DropdownMenuItem>
            ))}
          </DropdownMenuContent>
        </DropdownMenu>
      )}

      {mode === "code" && onOpenReference && (
        <>
          <Separator orientation="vertical" className="h-4" />
          <Button
            variant="ghost"
            size="sm"
            className="h-7 gap-1.5 px-2 text-xs text-muted-foreground"
            onClick={onOpenReference}
          >
            <BookOpen className="h-3 w-3" />
            {t.songs.lyrics.docs}
          </Button>
        </>
      )}
    </div>
  )
}
