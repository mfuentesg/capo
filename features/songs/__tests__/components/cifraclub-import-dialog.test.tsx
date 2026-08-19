import { render, screen, fireEvent, waitFor } from "@testing-library/react"
import { CifraClubImportDialog } from "@/features/songs/components/cifraclub-import-dialog"
import { importSongFromCifraClubAction } from "@/features/songs/api/actions"

jest.mock("@/hooks/use-translation", () => ({
  useTranslation: () => ({
    t: {
      common: { cancel: "Cancel" },
      songs: {
        cifraImport: {
          dialogTitleCreate: "Import song from CifraClub",
          dialogTitleReplace: "Import lyrics from CifraClub",
          urlLabel: "CifraClub URL",
          urlPlaceholder: "https://www.cifraclub.com/artist/song/",
          importButton: "Import",
          importing: "Importing…",
          confirmReplaceTitle: "Replace lyrics",
          confirmReplaceDescription: "This will replace your current lyrics.",
          errors: {
            invalidUrl: "Enter a valid URL",
            unsupportedHost: "Only cifraclub.com URLs are supported",
            network: "Couldn't reach CifraClub. Please try again.",
            parseFailed: "Couldn't read this CifraClub page.",
            unknown: "Something went wrong."
          }
        }
      }
    }
  })
}))

jest.mock("@/features/songs/api/actions", () => ({
  importSongFromCifraClubAction: jest.fn()
}))

const mockImport = importSongFromCifraClubAction as jest.Mock
const CIFRACLUB_URL = "https://www.cifraclub.com/israel-houghton/eres-fiel/"

describe("CifraClubImportDialog", () => {
  beforeEach(() => {
    jest.clearAllMocks()
  })

  it("calls onImported with the parsed song on success (create mode)", async () => {
    const parsed = { title: "Eres Fiel", artist: "Israel Houghton", key: "Em", lyrics: "[Em]Lyrics", keyFound: true }
    mockImport.mockResolvedValue({ success: true, data: parsed })
    const onImported = jest.fn()

    render(
      <CifraClubImportDialog mode="create" open onOpenChange={jest.fn()} onImported={onImported} />
    )

    fireEvent.change(screen.getByLabelText("CifraClub URL"), { target: { value: CIFRACLUB_URL } })
    fireEvent.click(screen.getByRole("button", { name: "Import" }))

    await waitFor(() => expect(onImported).toHaveBeenCalledWith(parsed))
  })

  it("shows an error message when the import fails", async () => {
    mockImport.mockResolvedValue({ success: false, error: "no_chord_block" })

    render(
      <CifraClubImportDialog mode="create" open onOpenChange={jest.fn()} onImported={jest.fn()} />
    )

    fireEvent.change(screen.getByLabelText("CifraClub URL"), { target: { value: CIFRACLUB_URL } })
    fireEvent.click(screen.getByRole("button", { name: "Import" }))

    expect(await screen.findByText("Couldn't read this CifraClub page.")).toBeInTheDocument()
  })

  it("asks for confirmation before replacing existing lyrics", async () => {
    const parsed = { title: "Eres Fiel", artist: "Israel Houghton", key: "Em", lyrics: "[Em]Lyrics", keyFound: true }
    mockImport.mockResolvedValue({ success: true, data: parsed })
    const onImported = jest.fn()

    render(
      <CifraClubImportDialog
        mode="replace-lyrics"
        hasExistingLyrics
        open
        onOpenChange={jest.fn()}
        onImported={onImported}
      />
    )

    fireEvent.change(screen.getByLabelText("CifraClub URL"), { target: { value: CIFRACLUB_URL } })
    fireEvent.click(screen.getByRole("button", { name: "Import" }))

    expect(await screen.findByText("This will replace your current lyrics.")).toBeInTheDocument()
    expect(onImported).not.toHaveBeenCalled()

    fireEvent.click(screen.getByRole("button", { name: "Replace lyrics" }))
    expect(onImported).toHaveBeenCalledWith(parsed)
  })
})
