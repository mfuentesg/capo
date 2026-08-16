/**
 * Formats a past date as a compact relative label ("3d ago", "2w ago") for
 * space-constrained UI like badges. Always treats dateStr as in the past.
 */
export function formatCompactRelativeTime(
  dateStr: string,
  referenceDate: Date = new Date()
): string {
  const diffDays = Math.floor(
    (referenceDate.getTime() - new Date(dateStr).getTime()) / (1000 * 60 * 60 * 24)
  )

  if (diffDays <= 0) return "today"
  if (diffDays < 7) return `${diffDays}d ago`
  if (diffDays < 30) return `${Math.floor(diffDays / 7)}w ago`
  if (diffDays < 365) return `${Math.floor(diffDays / 30)}mo ago`
  return `${Math.floor(diffDays / 365)}y ago`
}
