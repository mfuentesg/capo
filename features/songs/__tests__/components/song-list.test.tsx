import { render } from "@testing-library/react"
import { SongList } from "@/features/songs/components/song-list/song-list"
import { useSongFrequencies } from "@/features/playlists"
import { getFrequencyBadgeInfo as realGetFrequencyBadgeInfo } from "@/features/playlists/utils/song-frequency"

jest.mock("@/features/playlist-draft", () => ({
  usePlaylistDraft: () => ({
    toggleSongInDraft: jest.fn(),
    isSongInDraft: () => false
  })
}))

jest.mock("@/hooks/use-translation", () => ({
  useTranslation: () => ({ t: { nav: { personal: "Personal" } } })
}))

jest.mock("@/features/app-context", () => ({
  useAppContext: () => ({ teams: [] }),
  useViewFilter: () => ({ viewFilter: { type: "personal" } })
}))

jest.mock("@/features/songs/utils", () => ({
  getBucketColor: () => undefined
}))

// Mock only the hook — reuse the real (already-unit-tested) getFrequencyBadgeInfo
// via its own module so this test doesn't re-evaluate the whole playlists barrel.
jest.mock("@/features/playlists", () => ({
  useSongFrequencies: jest.fn(),
  getFrequencyBadgeInfo: (...args: unknown[]) =>
    (realGetFrequencyBadgeInfo as (...args: unknown[]) => unknown)(...args)
}))

const mockUseSongFrequencies = useSongFrequencies as jest.Mock

const mockSong = {
  id: "song-1",
  title: "Amazing Grace",
  artist: "John Newton",
  key: "G",
  bpm: 80
}

const baseProps = {
  songs: [mockSong],
  groupBy: "none" as const,
  bpmRange: "all" as const,
  onSelectSong: jest.fn()
}

it("renders no frequency badge when the song has no recorded plays", () => {
  mockUseSongFrequencies.mockReturnValue({ data: new Map() })

  const { queryByText } = render(<SongList {...baseProps} />)

  expect(queryByText(/ago/)).not.toBeInTheDocument()
})

it("renders a frequency badge for a song with recorded plays", () => {
  mockUseSongFrequencies.mockReturnValue({
    data: new Map([["song-1", { count: 3, lastPlayedDate: new Date().toISOString() }]])
  })

  const { getByText } = render(<SongList {...baseProps} />)

  expect(getByText((content) => content.startsWith("3×"))).toBeInTheDocument()
})
