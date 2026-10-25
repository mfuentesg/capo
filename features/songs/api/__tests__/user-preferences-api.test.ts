import { upsertUserPreferences } from "../user-preferences-api"
import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database } from "@/lib/supabase/database.types"

function makeClient(stored: unknown) {
  const update = jest.fn<void, [{ preferences: Record<string, unknown> }]>()
  const chain = (result: unknown) => {
    const c: Record<string, unknown> = {}
    c.select = () => c
    c.eq = () => c
    c.single = () => Promise.resolve({ data: result, error: null })
    return c
  }
  const client = {
    from: () => ({
      select: () => chain({ preferences: stored }),
      update: (payload: { preferences: Record<string, unknown> }) => {
        update(payload)
        return chain({ preferences: payload.preferences })
      }
    })
  }
  return { client: client as unknown as SupabaseClient<Database>, update }
}

describe("upsertUserPreferences", () => {
  it("keeps palette, uiFont and chordHand when only lyricsColumns changes", async () => {
    const { client, update } = makeClient({
      lyricsColumns: 2,
      palette: "ocean",
      uiFont: "geist",
      chordHand: "right",
      theme: "dark"
    })
    await upsertUserPreferences(client, "u1", { lyricsColumns: 1 })
    expect(update.mock.calls[0][0].preferences).toEqual({
      lyricsColumns: 1,
      palette: "ocean",
      uiFont: "geist",
      chordHand: "right",
      theme: "dark"
    })
  })

  it("does not erase stored keys with undefined values", async () => {
    const { client, update } = makeClient({ lyricsColumns: 2, locale: "es" })
    await upsertUserPreferences(client, "u1", { lyricsColumns: 2, locale: undefined })
    expect(update.mock.calls[0][0].preferences.locale).toBe("es")
  })

  it("tolerates a null stored value", async () => {
    const { client, update } = makeClient(null)
    await upsertUserPreferences(client, "u1", { lyricsColumns: 1 })
    expect(update.mock.calls[0][0].preferences).toEqual({ lyricsColumns: 1 })
  })
})
