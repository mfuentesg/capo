import { render } from "@testing-library/react"
import { PlaylistDraft } from "@/features/playlist-draft/components/playlist-draft"
import { useSongFrequencies } from "@/features/playlists"
import { getFrequencyBadgeInfo as realGetFrequencyBadgeInfo } from "@/features/playlists/utils/song-frequency"

// Mock only the hook — reuse the real (already-unit-tested) getFrequencyBadgeInfo
// via its own module so this test doesn't re-evaluate the whole playlists barrel.
jest.mock("@/features/playlists", () => ({
  useSongFrequencies: jest.fn(),
  getFrequencyBadgeInfo: (...args: unknown[]) =>
    (realGetFrequencyBadgeInfo as (...args: unknown[]) => unknown)(...args)
}))

jest.mock("@/hooks/use-mobile", () => ({
  useIsMobile: () => false
}))

jest.mock("@/hooks/use-translation", () => ({
  useTranslation: () => ({
    t: {
      playlistDraft: {
        openDraft: "Open draft",
        addToPlaylist: "Add to playlist",
        songsSelected: "songs selected",
        clearButton: "Clear",
        addButton: "Add {count}",
        selectPlaylist: "Select playlist",
        selectNewPlaylist: "New playlist"
      },
      playlists: {
        playlistNamePlaceholder: "Playlist name"
      },
      common: {
        removeSong: "Remove song"
      }
    }
  })
}))

// Strip Radix portal/animation internals — focus this test on data wiring, not the dialog primitive.
jest.mock("@/components/ui/dialog", () => ({
  Dialog: ({ children, open }: { children: React.ReactNode; open: boolean }) =>
    open ? <div>{children}</div> : null,
  DialogTrigger: ({ children }: { children: React.ReactNode }) => <>{children}</>,
  DialogContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DialogHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DialogTitle: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DialogDescription: ({ children }: { children: React.ReactNode }) => <div>{children}</div>
}))

jest.mock("@/components/ui/drawer", () => ({
  Drawer: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DrawerTrigger: ({ children }: { children: React.ReactNode }) => <>{children}</>,
  DrawerContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DrawerHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DrawerTitle: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DrawerDescription: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DrawerScrollArea: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  DrawerFooter: ({ children }: { children: React.ReactNode }) => <div>{children}</div>
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
  playlists: [],
  isOpen: true,
  onOpenChange: jest.fn(),
  onClear: jest.fn(),
  onRemove: jest.fn(),
  onSubmit: jest.fn(),
}

it("renders no frequency badge when the song has no recorded plays", () => {
  mockUseSongFrequencies.mockReturnValue({ data: new Map() })

  const { queryByText } = render(<PlaylistDraft {...baseProps} />)

  expect(queryByText(/ago/)).not.toBeInTheDocument()
})

it("renders a frequency badge for a song with recorded plays", () => {
  mockUseSongFrequencies.mockReturnValue({
    data: new Map([["song-1", { count: 2, lastPlayedDate: new Date().toISOString() }]])
  })

  const { getByText } = render(<PlaylistDraft {...baseProps} />)

  expect(getByText((content) => content.startsWith("2×"))).toBeInTheDocument()
})
