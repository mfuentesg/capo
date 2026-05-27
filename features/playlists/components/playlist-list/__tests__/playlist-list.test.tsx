import { fireEvent, render, screen } from "@testing-library/react"
import { LocaleProvider } from "@/features/settings"
import { PlaylistList } from "../playlist-list"
import type { Playlist } from "@/features/playlists/types"

jest.mock("@/features/app-context", () => ({
  useAppContext: () => ({ teams: [] }),
  useViewFilter: () => ({ viewFilter: { type: "all" } })
}))

jest.mock("@/features/songs", () => ({
  getBucketColor: () => "var(--accent-songs)"
}))

const playlists: Playlist[] = [
  {
    id: "playlist-1",
    name: "Morning Set",
    songs: ["song-1"],
    createdAt: "2026-02-01T00:00:00.000Z",
    updatedAt: "2026-02-01T00:00:00.000Z",
    visibility: "private"
  },
  {
    id: "playlist-2",
    name: "Night Set",
    songs: ["song-2", "song-3"],
    createdAt: "2026-02-02T00:00:00.000Z",
    updatedAt: "2026-02-02T00:00:00.000Z",
    visibility: "public"
  }
]

function renderPlaylistList(selectedPlaylistId?: string | null, onSelectPlaylist = jest.fn()) {
  return render(
    <LocaleProvider>
      <PlaylistList
        playlists={playlists}
        searchQuery=""
        filterVisibility="all"
        selectedPlaylistId={selectedPlaylistId}
        onSelectPlaylist={onSelectPlaylist}
      />
    </LocaleProvider>
  )
}

function getPlaylistRow(name: string) {
  return screen.getByText(name).closest("div.cursor-pointer")
}

describe("PlaylistList", () => {
  it("should use selectedPlaylistId as the single source of truth for selected state", () => {
    const { rerender } = renderPlaylistList("playlist-1")

    expect(getPlaylistRow("Morning Set")).toHaveClass("bg-accent-playlists/10")
    expect(getPlaylistRow("Night Set")).not.toHaveClass("bg-accent-playlists/10")

    rerender(
      <LocaleProvider>
        <PlaylistList
          playlists={playlists}
          searchQuery=""
          filterVisibility="all"
          selectedPlaylistId="playlist-2"
          onSelectPlaylist={jest.fn()}
        />
      </LocaleProvider>
    )

    expect(getPlaylistRow("Morning Set")).not.toHaveClass("bg-accent-playlists/10")
    expect(getPlaylistRow("Night Set")).toHaveClass("bg-accent-playlists/10")
  })

  it("should call onSelectPlaylist when a playlist is clicked", () => {
    const onSelectPlaylist = jest.fn()
    renderPlaylistList(null, onSelectPlaylist)

    const nightSetRow = getPlaylistRow("Night Set")
    expect(nightSetRow).toBeInTheDocument()

    fireEvent.click(nightSetRow!)

    expect(onSelectPlaylist).toHaveBeenCalledWith(playlists[1])
  })
})
