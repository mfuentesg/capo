/** Single source of truth for BPM tiers: slow < 90, medium 90–120, fast > 120. */
export const BPM_SLOW_BELOW = 90
export const BPM_FAST_ABOVE = 120

export type BpmTier = "slow" | "medium" | "fast"

export function getBpmTier(bpm: number): BpmTier {
  if (bpm < BPM_SLOW_BELOW) return "slow"
  if (bpm <= BPM_FAST_ABOVE) return "medium"
  return "fast"
}
