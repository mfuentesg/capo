import { render, screen, fireEvent } from "@testing-library/react"
import { LocaleProvider } from "@/features/settings"
import { ChordPlayButton } from "../components/chord-play-button"
import * as chordAudioHook from "../hooks/use-chord-audio"

jest.mock("../hooks/use-chord-audio")

const mockPlay = jest.fn()
const mockUseChordAudio = chordAudioHook.useChordAudio as jest.Mock

function renderWithLocale(ui: React.ReactElement) {
  return render(<LocaleProvider>{ui}</LocaleProvider>)
}

describe("ChordPlayButton", () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseChordAudio.mockReturnValue({ play: mockPlay, stop: jest.fn(), isLoading: false, isPlaying: false })
  })

  it("renders nothing when midiNotes is undefined", () => {
    const { container } = renderWithLocale(<ChordPlayButton midiNotes={undefined} />)
    expect(container.firstChild).toBeNull()
  })

  it("renders nothing when midiNotes is empty", () => {
    const { container } = renderWithLocale(<ChordPlayButton midiNotes={[]} />)
    expect(container.firstChild).toBeNull()
  })

  it("renders a play button when midiNotes are provided", () => {
    renderWithLocale(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    expect(screen.getByRole("button", { name: "Play chord" })).toBeInTheDocument()
  })

  it("calls play with midiNotes when clicked", () => {
    renderWithLocale(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    fireEvent.click(screen.getByRole("button", { name: "Play chord" }))
    expect(mockPlay).toHaveBeenCalledWith([45, 52, 57, 60, 64])
  })

  it("disables the button while loading", () => {
    mockUseChordAudio.mockReturnValue({ play: mockPlay, stop: jest.fn(), isLoading: true, isPlaying: false })
    renderWithLocale(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    expect(screen.getByRole("button", { name: "Play chord" })).toBeDisabled()
  })
})
