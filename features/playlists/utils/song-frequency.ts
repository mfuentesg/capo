import { formatCompactRelativeTime } from "@/lib/format-relative-time"

/**
 * How often a song has appeared across playlists in the current context,
 * and when it was last played.
 */
export interface SongFrequency {
  count: number
  lastPlayedDate: string | null
}

export interface SongFrequencySourceRow {
  songId: string
  date: string | null
  createdAt: string
}

/**
 * Aggregates raw playlist_songs/playlists rows into a per-song play count
 * and last-played date. Uses the playlist's own date field when set,
 * falling back to when the song was added (created_at) otherwise.
 */
export function computeSongFrequencies(
  rows: SongFrequencySourceRow[]
): Map<string, SongFrequency> {
  const result = new Map<string, SongFrequency>()

  for (const row of rows) {
    const playedDate = row.date ?? row.createdAt
    const existing = result.get(row.songId)

    if (!existing) {
      result.set(row.songId, { count: 1, lastPlayedDate: playedDate })
      continue
    }

    existing.count += 1
    if (!existing.lastPlayedDate || playedDate > existing.lastPlayedDate) {
      existing.lastPlayedDate = playedDate
    }
  }

  return result
}

/** Songs repeated within this many days of the reference date get flagged. */
export const SONG_REPETITION_WINDOW_DAYS = 14

/**
 * Whether a song was played recently enough to flag as a likely repeat,
 * relative to referenceDate (defaults to now).
 */
export function isRecentlyPlayed(
  lastPlayedDate: string | null,
  referenceDate: Date = new Date(),
  windowDays: number = SONG_REPETITION_WINDOW_DAYS
): boolean {
  if (!lastPlayedDate) return false

  const diffDays =
    (referenceDate.getTime() - new Date(lastPlayedDate).getTime()) / (1000 * 60 * 60 * 24)

  return diffDays >= 0 && diffDays <= windowDays
}

/** Ready-to-render badge info for a song, or undefined if it's never been played. */
export interface SongFrequencyBadgeInfo {
  count: number
  isRecentlyPlayed: boolean
  lastPlayedLabel: string
}

/**
 * Looks up a song's frequency data and formats it for display in a badge.
 */
export function getFrequencyBadgeInfo(
  songId: string,
  frequencies: Map<string, SongFrequency>,
  referenceDate: Date = new Date()
): SongFrequencyBadgeInfo | undefined {
  const frequency = frequencies.get(songId)
  if (!frequency || !frequency.lastPlayedDate) return undefined

  return {
    count: frequency.count,
    isRecentlyPlayed: isRecentlyPlayed(frequency.lastPlayedDate, referenceDate),
    lastPlayedLabel: formatCompactRelativeTime(frequency.lastPlayedDate, referenceDate)
  }
}
