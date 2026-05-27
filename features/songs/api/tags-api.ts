import type { SupabaseClient } from "@supabase/supabase-js"
import type { AppContext } from "@/features/app-context"
import type { SongTag } from "@/features/songs/types"

function mapRow(row: { id: string; name: string; color: string | null }): SongTag {
  return { id: row.id, name: row.name, color: row.color }
}

/**
 * Fetch all tags accessible in the given context (personal or team).
 */
export async function getTagsForContext(
  supabase: SupabaseClient,
  context: AppContext
): Promise<SongTag[]> {
  const isTeam = context.type === "team"
  const query = supabase
    .from("song_tags")
    .select("id, name, color")
    .order("name", { ascending: true })

  const { data, error } = isTeam
    ? await query.eq("team_id", context.teamId)
    : await query.eq("user_id", context.userId)

  if (error) throw error
  return (data || []).map(mapRow)
}

/**
 * Fetch all tags for a specific user across all contexts (personal + all teams).
 */
export async function getTagsForUser(
  supabase: SupabaseClient,
  userId: string,
  teamIds: string[]
): Promise<SongTag[]> {
  const orParts = [`user_id.eq.${userId}`, ...teamIds.map((id) => `team_id.eq.${id}`)].join(",")

  const { data, error } = await supabase
    .from("song_tags")
    .select("id, name, color")
    .or(orParts)
    .order("name", { ascending: true })

  if (error) throw error
  return (data || []).map(mapRow)
}

/**
 * Fetch tag assignments for a batch of song IDs.
 * Returns a map of songId → SongTag[].
 */
export async function getTagAssignmentsForSongs(
  supabase: SupabaseClient,
  songIds: string[]
): Promise<Map<string, SongTag[]>> {
  if (songIds.length === 0) return new Map()

  const { data, error } = await supabase
    .from("song_tag_assignments")
    .select("song_id, song_tags(id, name, color)")
    .in("song_id", songIds)

  if (error) throw error

  type TagRow = { id: string; name: string; color: string | null }

  const map = new Map<string, SongTag[]>()
  for (const row of data || []) {
    // PostgREST returns the FK-joined row as a single object (not array)
    // but the untyped client may represent it differently — handle both
    const rawTag = row.song_tags as unknown as TagRow | TagRow[] | null
    if (!rawTag) continue
    const tag: TagRow = Array.isArray(rawTag) ? rawTag[0] : rawTag
    if (!tag) continue
    const existing = map.get(row.song_id) ?? []
    existing.push(mapRow(tag))
    map.set(row.song_id, existing)
  }
  return map
}

/**
 * Create a new tag in the given context.
 */
export async function createTag(
  supabase: SupabaseClient,
  name: string,
  color: string | null,
  context: AppContext
): Promise<SongTag> {
  const isTeam = context.type === "team"
  const insert = isTeam
    ? { name: name.trim(), color, team_id: context.teamId }
    : { name: name.trim(), color, user_id: context.userId }

  const { data, error } = await supabase
    .from("song_tags")
    .insert(insert)
    .select("id, name, color")
    .single()

  if (error) throw error
  return mapRow(data)
}

/**
 * Delete a tag by ID (cascade removes all assignments).
 */
export async function deleteTag(supabase: SupabaseClient, tagId: string): Promise<void> {
  const { error } = await supabase.from("song_tags").delete().eq("id", tagId)
  if (error) throw error
}

/**
 * Replace all tag assignments for a song with the given tag IDs.
 * Uses delete-then-insert (not transactional, but sufficient for UI usage).
 */
export async function setSongTags(
  supabase: SupabaseClient,
  songId: string,
  tagIds: string[]
): Promise<void> {
  const { error: deleteError } = await supabase
    .from("song_tag_assignments")
    .delete()
    .eq("song_id", songId)

  if (deleteError) throw deleteError

  if (tagIds.length === 0) return

  const { error: insertError } = await supabase
    .from("song_tag_assignments")
    .insert(tagIds.map((tag_id) => ({ song_id: songId, tag_id })))

  if (insertError) throw insertError
}
