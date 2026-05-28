import { X } from "lucide-react"
import { cn } from "@/lib/utils"
import { Badge } from "@/components/ui/badge"
import type { SongTag } from "@/features/songs/types"

interface TagBadgeProps {
  tag: SongTag
  onRemove?: () => void
  className?: string
}

export function TagBadge({ tag, onRemove, className }: TagBadgeProps) {
  const color = tag.color ?? "#6b7280"

  return (
    <Badge
      className={cn("text-[11px] select-none", onRemove && "pr-1", className)}
      style={{
        color,
        background: `color-mix(in oklch, ${color} 18%, transparent)`,
        borderColor: `color-mix(in oklch, ${color} 30%, transparent)`
      }}
    >
      <span className="opacity-60">#</span>
      {tag.name}
      {onRemove && (
        <button
          onClick={onRemove}
          className="ml-0.5 rounded-full p-0.5 opacity-60 hover:opacity-100"
          aria-label={`Remove ${tag.name} tag`}
        >
          <X className="h-2.5 w-2.5" />
        </button>
      )}
    </Badge>
  )
}
