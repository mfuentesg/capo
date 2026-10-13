export interface SongCursor { updatedAt: string; id: string }

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function encodeCursor(c: SongCursor): string {
  return Buffer.from(JSON.stringify(c)).toString("base64url")
}

export function decodeCursor(raw: string): SongCursor | null {
  try {
    const v = JSON.parse(Buffer.from(raw, "base64url").toString("utf8")) as Partial<SongCursor> | null
    if (typeof v?.updatedAt !== "string" || Number.isNaN(Date.parse(v.updatedAt))) return null
    if (typeof v?.id !== "string" || !UUID.test(v.id)) return null
    return { updatedAt: v.updatedAt, id: v.id }
  } catch {
    return null
  }
}
