import { createClient } from "@supabase/supabase-js"
import { NextResponse } from "next/server"
import { env } from "@/lib/env"
import type { Database } from "@/lib/supabase/database.types"
import { decodeCursor, encodeCursor, parseBearer } from "@/features/api-tokens"

const DEFAULT_LIMIT = 200
const MAX_LIMIT = 500
type ExportArgs = Database["public"]["Functions"]["export_songs_for_token"]["Args"]
const unauthorized = () => NextResponse.json({ error: "unauthorized" }, { status: 401 })
const badRequest = (msg: string) => NextResponse.json({ error: msg }, { status: 400 })

export async function GET(request: Request) {
  const token = parseBearer(request.headers.get("authorization"))
  if (!token) return unauthorized()

  const url = new URL(request.url)
  const rawLimit = url.searchParams.get("limit")
  let limit = DEFAULT_LIMIT
  if (rawLimit !== null) {
    limit = Number(rawLimit)
    if (!Number.isInteger(limit) || limit < 1) return badRequest("invalid_limit")
    limit = Math.min(limit, MAX_LIMIT)
  }

  const since = url.searchParams.get("updated_since")
  if (since !== null && Number.isNaN(Date.parse(since))) return badRequest("invalid_updated_since")

  const rawCursor = url.searchParams.get("cursor")
  const cursor = rawCursor === null ? null : decodeCursor(rawCursor)
  if (rawCursor !== null && !cursor) return badRequest("invalid_cursor")

  const supabase = createClient<Database>(env.required.supabaseUrl, env.required.supabasePublishableKey, {
    auth: { persistSession: false, autoRefreshToken: false }
  })
  // The generated Args types are non-null (the SQL function has no DEFAULTs), but the function
  // accepts NULL for the optional filters. Cast so we can pass null; cursor fields are always
  // passed together or not at all.
  // Read before the query so the client's next `updated_since` can never skip a row.
  const serverTime = new Date().toISOString()
  const { data, error } = await supabase.rpc("export_songs_for_token", {
    p_token: token,
    p_since: since,
    p_after_updated: cursor?.updatedAt ?? null,
    p_after_id: cursor?.id ?? null,
    p_limit: limit
  } as unknown as ExportArgs)

  if (error) {
    console.error("songs export failed:", error.message)
    return NextResponse.json({ error: "internal" }, { status: 500 })
  }
  const rows = (data ?? []) as unknown as Array<{
    id: string
    title: string
    artist: string | null
    key: string | null
    bpm: number | null
    lyrics: string | null
    status: string
    tags: string[] | null
    updated_at: string
    valid: boolean
  }>
  // Unknown/revoked token: the RPC returns exactly one all-null row with valid=false.
  if (rows.length === 1 && rows[0].valid === false) return unauthorized()

  const songs = rows
    .filter((r) => r.valid)
    .map(({ id, title, artist, key, bpm, lyrics, status, tags, updated_at }) => ({
      id,
      title,
      artist,
      key,
      bpm,
      lyrics,
      status,
      tags: tags ?? [],
      updated_at
    }))
  const last = songs[songs.length - 1]
  const nextCursor =
    songs.length === limit && last
      ? encodeCursor({ updatedAt: last.updated_at, id: last.id })
      : null

  return NextResponse.json({
    songs,
    next_cursor: nextCursor,
    server_time: serverTime
  })
}
