import { renderHook, act } from "@testing-library/react"
import type { ReactNode } from "react"
import {
  PlaylistDraftProvider,
  usePlaylistDraft
} from "@/features/playlist-draft/contexts/draft.context"
import type { Song } from "@/features/songs"

const makeSong = (id: string, title = `Song ${id}`): Song => ({
  id,
  title,
  artist: "Artist",
  key: "C",
  bpm: 120
})

const wrapper = ({ children }: { children: ReactNode }) => (
  <PlaylistDraftProvider>{children}</PlaylistDraftProvider>
)

describe("usePlaylistDraft", () => {
  it("throws when used outside of PlaylistDraftProvider", () => {
    const consoleError = jest.spyOn(console, "error").mockImplementation(() => {})
    expect(() => renderHook(() => usePlaylistDraft())).toThrow(
      "usePlaylistDraft must be used within a PlaylistDraftProvider"
    )
    consoleError.mockRestore()
  })

  it("starts with an empty, closed draft", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })
    expect(result.current.playlistDraft).toEqual([])
    expect(result.current.isDraftOpen).toBe(false)
  })

  it("toggleSongInDraft adds a song that is not in the draft", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })
    const song = makeSong("a")

    act(() => result.current.toggleSongInDraft(song))

    expect(result.current.playlistDraft).toEqual([song])
    expect(result.current.isSongInDraft("a")).toBe(true)
  })

  it("toggleSongInDraft removes a song that is already in the draft", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })
    const song = makeSong("a")

    act(() => result.current.toggleSongInDraft(song))
    act(() => result.current.toggleSongInDraft(song))

    expect(result.current.playlistDraft).toEqual([])
    expect(result.current.isSongInDraft("a")).toBe(false)
  })

  it("preserves insertion order when adding multiple songs", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })

    act(() => result.current.toggleSongInDraft(makeSong("a")))
    act(() => result.current.toggleSongInDraft(makeSong("b")))
    act(() => result.current.toggleSongInDraft(makeSong("c")))

    expect(result.current.playlistDraft.map((s) => s.id)).toEqual(["a", "b", "c"])
  })

  it("removeFromDraft removes only the matching song", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })

    act(() => result.current.toggleSongInDraft(makeSong("a")))
    act(() => result.current.toggleSongInDraft(makeSong("b")))
    act(() => result.current.removeFromDraft("a"))

    expect(result.current.playlistDraft.map((s) => s.id)).toEqual(["b"])
    expect(result.current.isSongInDraft("a")).toBe(false)
    expect(result.current.isSongInDraft("b")).toBe(true)
  })

  it("clearDraft empties the draft", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })

    act(() => result.current.toggleSongInDraft(makeSong("a")))
    act(() => result.current.toggleSongInDraft(makeSong("b")))
    act(() => result.current.clearDraft())

    expect(result.current.playlistDraft).toEqual([])
  })

  it("reorderDraft moves a song from source to destination index", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })

    act(() => result.current.toggleSongInDraft(makeSong("a")))
    act(() => result.current.toggleSongInDraft(makeSong("b")))
    act(() => result.current.toggleSongInDraft(makeSong("c")))

    act(() => result.current.reorderDraft(0, 2))

    expect(result.current.playlistDraft.map((s) => s.id)).toEqual(["b", "c", "a"])
  })

  it("setIsDraftOpen toggles the open state", () => {
    const { result } = renderHook(() => usePlaylistDraft(), { wrapper })

    act(() => result.current.setIsDraftOpen(true))
    expect(result.current.isDraftOpen).toBe(true)

    act(() => result.current.setIsDraftOpen(false))
    expect(result.current.isDraftOpen).toBe(false)
  })
})
