import { render, screen } from "@testing-library/react"
import { PlaylistItem } from "@/features/playlists/components/playlist-item/playlist-item"

jest.mock("@/hooks/use-translation", () => ({
  useTranslation: () => ({
    t: {
      playlists: {},
      playlistItem: {
        privatePlaylist: "Private",
        publicGuestEditing: "Public (guest editing)",
        publicViewOnly: "Public (view only)"
      }
    }
  })
}))

jest.mock("@/lib/ui/stable-overlay-ids", () => ({
  createOverlayIds: () => ({ triggerId: "trigger", contentId: "content" })
}))

const mockPlaylist = {
  id: "p1",
  name: "Sunday Set",
  songs: [],
  createdAt: "",
  updatedAt: ""
}

it("renders ownership chip when bucketColor and ownershipLabel are provided", () => {
  const { container } = render(
    <PlaylistItem
      playlist={mockPlaylist}
      isSelected={false}
      bucketColor="#6366f1"
      ownershipLabel="Worship"
      onSelect={jest.fn()}
    />
  )
  expect(screen.getByText("Worship")).toBeInTheDocument()
  const dot = container.querySelector("[data-testid='ownership-dot']")
  expect(dot).toBeInTheDocument()
})

it("renders no chip when bucketColor is not provided", () => {
  render(
    <PlaylistItem
      playlist={mockPlaylist}
      isSelected={false}
      onSelect={jest.fn()}
    />
  )
  expect(screen.queryByTestId("ownership-dot")).not.toBeInTheDocument()
})
