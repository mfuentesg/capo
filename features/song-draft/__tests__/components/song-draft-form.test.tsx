import { render, screen, fireEvent, waitFor } from "@testing-library/react"
import { SongDraftForm } from "@/features/song-draft/components/song-draft-form"
import type { Song } from "@/types"

jest.mock("@/hooks/use-translation", () => ({
  useTranslation: () => ({
    t: {
      validation: {
        required: "{field} is required",
        songTitle: "Song title",
        artistName: "Artist name",
        key: "Key",
        minBpm: "BPM must be at least {min}",
        maxBpm: "BPM must be at most {max}"
      },
      songs: {
        createSong: "Create song",
        enterSongDetails: "Enter the song details",
        songTitle: "Title",
        songTitlePlaceholder: "Song title",
        artist: "Artist",
        artistPlaceholder: "Artist name",
        key: "Key",
        selectKey: "Select key",
        bpm: "BPM",
        bucket: "Bucket",
        songSettingsInfo: "You can adjust settings later"
      },
      common: {
        close: "Close",
        cancel: "Cancel",
        saving: "Saving...",
        submit: "Submit"
      }
    }
  })
}))

jest.mock("@/features/app-context", () => ({
  useAppContext: () => ({
    teams: [],
    context: { type: "personal", userId: "user-1" }
  }),
  BucketSelector: ({ label }: { label: string }) => <div data-testid="bucket-selector">{label}</div>
}))

jest.mock("@/features/songs", () => ({
  KeySelect: ({
    value,
    onValueChange,
    placeholder
  }: {
    value: string
    onValueChange: (value: string) => void
    placeholder: string
  }) => (
    <input
      aria-label="key-select"
      placeholder={placeholder}
      value={value}
      onChange={(e) => onValueChange(e.target.value)}
    />
  )
}))

const fillValidForm = () => {
  fireEvent.change(screen.getByPlaceholderText("Song title"), {
    target: { value: "Amazing Grace" }
  })
  fireEvent.change(screen.getByPlaceholderText("Artist name"), {
    target: { value: "John Newton" }
  })
  fireEvent.change(screen.getByLabelText("key-select"), { target: { value: "G" } })
  fireEvent.change(screen.getByPlaceholderText("120"), { target: { value: "80" } })
}

describe("SongDraftForm", () => {
  it("renders all form fields", () => {
    render(<SongDraftForm onClose={jest.fn()} onSave={jest.fn()} />)

    expect(screen.getByText("Create song")).toBeInTheDocument()
    expect(screen.getByPlaceholderText("Song title")).toBeInTheDocument()
    expect(screen.getByPlaceholderText("Artist name")).toBeInTheDocument()
    expect(screen.getByLabelText("key-select")).toBeInTheDocument()
    expect(screen.getByPlaceholderText("120")).toBeInTheDocument()
  })

  it("disables submit until the form is valid", async () => {
    render(<SongDraftForm onClose={jest.fn()} onSave={jest.fn()} />)

    expect(screen.getByRole("button", { name: "Submit" })).toBeDisabled()

    fillValidForm()

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Submit" })).toBeEnabled()
    })
  })

  it("submits the entered values via onSave", async () => {
    const onSave = jest.fn()
    render(<SongDraftForm onClose={jest.fn()} onSave={onSave} />)

    fillValidForm()
    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Submit" })).toBeEnabled()
    })
    fireEvent.click(screen.getByRole("button", { name: "Submit" }))

    await waitFor(() => {
      expect(onSave).toHaveBeenCalledWith(
        expect.objectContaining({
          title: "Amazing Grace",
          artist: "John Newton",
          key: "G",
          bpm: 80
        })
      )
    })
  })

  it("keeps the id of an existing song when saving", async () => {
    const onSave = jest.fn()
    const song: Song = { id: "existing-id", title: "Old", artist: "Old", key: "C", bpm: 100 }
    render(<SongDraftForm song={song} onClose={jest.fn()} onSave={onSave} />)

    await waitFor(() => {
      expect(screen.getByRole("button", { name: "Submit" })).toBeEnabled()
    })
    fireEvent.click(screen.getByRole("button", { name: "Submit" }))

    await waitFor(() => {
      expect(onSave).toHaveBeenCalledWith(expect.objectContaining({ id: "existing-id" }))
    })
  })

  it("calls onClose from the header close button and the cancel button", () => {
    const onClose = jest.fn()
    render(<SongDraftForm onClose={onClose} onSave={jest.fn()} />)

    fireEvent.click(screen.getByRole("button", { name: "Close" }))
    fireEvent.click(screen.getByRole("button", { name: "Cancel" }))

    expect(onClose).toHaveBeenCalledTimes(2)
  })

  it("notifies onChange with live field updates", async () => {
    const onChange = jest.fn()
    render(<SongDraftForm onClose={jest.fn()} onSave={jest.fn()} onChange={onChange} />)

    fireEvent.change(screen.getByPlaceholderText("Song title"), {
      target: { value: "New Title" }
    })

    await waitFor(() => {
      expect(onChange).toHaveBeenCalledWith(expect.objectContaining({ title: "New Title" }))
    })
  })

  it("renders the bucket selector only when onBucketChange is provided", () => {
    const { rerender } = render(<SongDraftForm onClose={jest.fn()} onSave={jest.fn()} />)
    expect(screen.queryByTestId("bucket-selector")).not.toBeInTheDocument()

    rerender(<SongDraftForm onClose={jest.fn()} onSave={jest.fn()} onBucketChange={jest.fn()} />)
    expect(screen.getByTestId("bucket-selector")).toBeInTheDocument()
  })
})
