/** Single source of truth for BPM tiers: slow < 90, medium 90–120, fast > 120. */
export const BPM_SLOW_BELOW = 90
export const BPM_FAST_ABOVE = 120

/** Range a user can enter in the song form and the inline editor (the API accepts 0–400). */
export const BPM_MIN = 40
export const BPM_MAX = 300

export type BpmTier = "slow" | "medium" | "fast"

export function getBpmTier(bpm: number): BpmTier {
  if (bpm < BPM_SLOW_BELOW) return "slow"
  if (bpm <= BPM_FAST_ABOVE) return "medium"
  return "fast"
}

export function clampBpm(bpm: number): number {
  return Math.max(BPM_MIN, Math.min(bpm, BPM_MAX))
}
