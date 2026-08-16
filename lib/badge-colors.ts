/**
 * Key badges use the songs accent color (blue) — semantic: song metadata.
 * Consistent across all keys — no rainbow, just a clean tinted style.
 */
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function getKeyColorClasses(_key: string): string {
  return "text-[var(--accent-songs)] bg-[color-mix(in_oklch,var(--accent-songs)_10%,transparent)] border-[color-mix(in_oklch,var(--accent-songs)_30%,transparent)]"
}

/**
 * BPM badges use three tiers — slow / medium / fast.
 * Slow: muted neutral. Medium: activity green (steady pace). Fast: rose (high energy).
 */
export function getBpmColorClasses(bpm: number): string {
  if (bpm < 90) return "text-muted-foreground bg-muted border-border"
  if (bpm <= 130)
    return "text-[var(--accent-activity)] bg-[color-mix(in_oklch,var(--accent-activity)_10%,transparent)] border-[color-mix(in_oklch,var(--accent-activity)_30%,transparent)]"
  return "text-rose-600 dark:text-rose-400 bg-rose-500/10 border-rose-500/30"
}

/**
 * Frequency badges flag songs played within the repetition window (amber)
 * vs. everything else (muted neutral).
 */
export function getFrequencyColorClasses(isRecentlyPlayed: boolean): string {
  if (isRecentlyPlayed) return "text-amber-600 dark:text-amber-400 bg-amber-500/10 border-amber-500/30"
  return "text-muted-foreground bg-muted border-border"
}
