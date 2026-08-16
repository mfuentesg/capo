import { render } from "@testing-library/react"
import { SongItem } from "@/features/songs/components/song-item/song-item"

// ownership must be set so ownershipLabel is computed as non-null inside SongItem
const mockSong = {
  id: "1",
  title: "Amazing Grace",
  artist: "John Newton",
  key: "G",
  bpm: 80,
  ownership: { type: "team" as const, teamId: "t1", teamName: "Worship", teamIcon: null }
}

it("renders a colored chip with dot when bucketColor and ownershipLabel are provided", () => {
  const { container } = render(
    <SongItem
      song={mockSong}
      isSelected={false}
      isInCart={false}
      bucketColor="#6366f1"
      onSelect={jest.fn()}
      onToggleCart={jest.fn()}
    />
  )
  const dot = container.querySelector("[data-testid='ownership-dot']")
  expect(dot).toBeInTheDocument()
})

it("renders no left border style when bucketColor is provided", () => {
  const { container } = render(
    <SongItem
      song={mockSong}
      isSelected={false}
      isInCart={false}
      bucketColor="#6366f1"
      onSelect={jest.fn()}
      onToggleCart={jest.fn()}
    />
  )
  const outerDiv = container.firstChild as HTMLElement
  expect(outerDiv?.style.borderLeftColor).toBe("")
})

it("renders no frequency badge when the song has never been played", () => {
  const { queryByText } = render(
    <SongItem
      song={mockSong}
      isSelected={false}
      isInCart={false}
      onSelect={jest.fn()}
      onToggleCart={jest.fn()}
    />
  )
  expect(queryByText(/ago/)).not.toBeInTheDocument()
})

it("renders a frequency badge with count and last-played label when provided", () => {
  const { getByText } = render(
    <SongItem
      song={mockSong}
      isSelected={false}
      isInCart={false}
      frequency={{ count: 3, isRecentlyPlayed: false, lastPlayedLabel: "5w ago" }}
      onSelect={jest.fn()}
      onToggleCart={jest.fn()}
    />
  )
  expect(getByText("3× · 5w ago")).toBeInTheDocument()
})

it("applies the warning style to the frequency badge when recently played", () => {
  const { getByText } = render(
    <SongItem
      song={mockSong}
      isSelected={false}
      isInCart={false}
      frequency={{ count: 2, isRecentlyPlayed: true, lastPlayedLabel: "3d ago" }}
      onSelect={jest.fn()}
      onToggleCart={jest.fn()}
    />
  )
  expect(getByText("2× · 3d ago").className).toContain("amber")
})
