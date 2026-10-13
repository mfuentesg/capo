import { decodeCursor, encodeCursor } from "../lib/cursor"

describe("cursor", () => {
  it("round-trips", () => {
    const c = { updatedAt: "2026-01-02T03:04:05.000Z", id: "11111111-1111-1111-1111-111111111111" }
    expect(decodeCursor(encodeCursor(c))).toEqual(c)
  })
  it.each(["", "not-base64!!", Buffer.from("{}").toString("base64url"),
           Buffer.from('{"updatedAt":"x","id":"y"}').toString("base64url")])(
    "rejects %p", (raw) => expect(decodeCursor(raw)).toBeNull())
})
