"use client"

import { SECTION_TYPES } from "../utils/section-wrap"
import type { SectionType } from "../utils/section-wrap"
import { cn } from "@/lib/utils"

interface SectionWrapToolbarProps {
  visible: boolean
  onWrap: (type: SectionType) => void
  className?: string
}

export function SectionWrapToolbar({ visible, onWrap, className }: SectionWrapToolbarProps) {
  if (!visible) return null

  return (
    <div
      className={cn(
        "flex items-center gap-1.5 px-3 py-2 border-b bg-muted/30 flex-wrap animate-in slide-in-from-top-1 fade-in-0 duration-150",
        className
      )}
    >
      <span className="text-xs text-muted-foreground shrink-0 mr-0.5">Wrap as</span>
      {SECTION_TYPES.map((type) => (
        <button
          key={type.key}
          type="button"
          className="inline-flex items-center rounded-md border bg-background px-2 py-0.5 text-xs font-medium hover:bg-muted transition-colors cursor-pointer"
          onMouseDown={(e) => {
            // Prevent editor focus loss so the selection is preserved
            e.preventDefault()
          }}
          onClick={() => onWrap(type)}
        >
          {type.label}
        </button>
      ))}
    </div>
  )
}
