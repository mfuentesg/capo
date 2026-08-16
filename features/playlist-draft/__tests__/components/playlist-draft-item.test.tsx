import { render } from "@testing-library/react"
import { PlaylistDraftItem } from "@/features/playlist-draft/components/playlist-draft-item"

jest.mock("@/hooks/use-translation", () => ({
  useTranslation: () => ({
    t: {
      common: {
        removeSong: "Remove song"
      }
    }
  })
}))

const mockSong = {
  id: "1",
  title: "Amazing Grace",
  artist: "John Newton",
  key: "G",
  bpm: 80
}

it("renders no frequency badge when the song has never been played", () => {
  const { queryByText } = render(
    <PlaylistDraftItem song={mockSong} index={0} onRemove={jest.fn()} />
  )
  expect(queryByText(/ago/)).not.toBeInTheDocument()
})

it("renders a frequency badge with count and last-played label when provided", () => {
  const { getByText } = render(
    <PlaylistDraftItem
      song={mockSong}
      index={0}
      frequency={{ count: 2, isRecentlyPlayed: true, lastPlayedLabel: "3d ago" }}
      onRemove={jest.fn()}
    />
  )
  expect(getByText("2× · 3d ago")).toBeInTheDocument()
})

it("applies the warning style to the frequency badge when recently played", () => {
  const { getByText } = render(
    <PlaylistDraftItem
      song={mockSong}
      index={0}
      frequency={{ count: 2, isRecentlyPlayed: true, lastPlayedLabel: "3d ago" }}
      onRemove={jest.fn()}
    />
  )
  expect(getByText("2× · 3d ago").className).toContain("amber")
})
