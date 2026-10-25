import { upsertUserPreferences } from "../user-preferences-api"
import type { SupabaseClient } from "@supabase/supabase-js"
import type { Database } from "@/lib/supabase/database.types"

function makeClient(result: unknown, error: unknown = null) {
  const rpc = jest.fn().mockResolvedValue({ data: result, error })
  return { client: { rpc } as unknown as SupabaseClient<Database>, rpc }
}

describe("upsertUserPreferences", () => {
  it("sends only the changed keys to the atomic merge RPC", async () => {
    const { client, rpc } = makeClient({ lyricsColumns: 1, palette: "ocean", theme: "dark" })
    const result = await upsertUserPreferences(client, { lyricsColumns: 1 })
    expect(rpc).toHaveBeenCalledWith("merge_user_preferences", { p_patch: { lyricsColumns: 1 } })
    expect(result.lyricsColumns).toBe(1)
  })

  it("drops undefined values so stored keys are never erased", async () => {
    const { client, rpc } = makeClient({ lyricsColumns: 2, locale: "es" })
    const result = await upsertUserPreferences(client, { lyricsColumns: 2, locale: undefined })
    expect(rpc).toHaveBeenCalledWith("merge_user_preferences", { p_patch: { lyricsColumns: 2 } })
    expect(result.locale).toBe("es")
  })

  it("tolerates a non-object result", async () => {
    const { client } = makeClient(null)
    expect(await upsertUserPreferences(client, { lyricsColumns: 1 })).toEqual({ lyricsColumns: 2 })
  })

  it("throws RPC errors", async () => {
    const { client } = makeClient(null, new Error("boom"))
    await expect(upsertUserPreferences(client, { lyricsColumns: 1 })).rejects.toThrow("boom")
  })
})
