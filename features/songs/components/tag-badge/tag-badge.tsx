import { X } from "lucide-react"
import { cn } from "@/lib/utils"
import type { SongTag } from "@/features/songs/types"

interface TagBadgeProps {
  tag: SongTag
  onRemove?: () => void
  className?: string
}

export function TagBadge({ tag, onRemove, className }: TagBadgeProps) {
  const color = tag.color ?? "#6b7280"

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-medium",
        onRemove ? "pr-1" : "",
        className
      )}
      style={{
        color,
        background: `color-mix(in oklch, ${color} 18%, transparent)`,
        border: `1px solid color-mix(in oklch, ${color} 30%, transparent)`
      }}
    >
      {tag.name}
      {onRemove && (
        <button
          onClick={onRemove}
          className="rounded-full p-0.5 opacity-60 hover:opacity-100 transition-opacity"
          aria-label={`Remove ${tag.name} tag`}
        >
          <X className="h-2.5 w-2.5" />
        </button>
      )}
    </span>
  )
}
