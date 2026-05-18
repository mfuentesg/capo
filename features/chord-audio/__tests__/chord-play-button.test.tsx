import { render, screen, fireEvent } from "@testing-library/react"
import { ChordPlayButton } from "../components/chord-play-button"
import * as chordAudioHook from "../hooks/use-chord-audio"

jest.mock("../hooks/use-chord-audio")

const mockPlay = jest.fn()
const mockUseChordAudio = chordAudioHook.useChordAudio as jest.Mock

describe("ChordPlayButton", () => {
  beforeEach(() => {
    jest.clearAllMocks()
    mockUseChordAudio.mockReturnValue({ play: mockPlay, isLoading: false, isPlaying: false })
  })

  it("renders nothing when midiNotes is undefined", () => {
    const { container } = render(<ChordPlayButton midiNotes={undefined} />)
    expect(container.firstChild).toBeNull()
  })

  it("renders nothing when midiNotes is empty", () => {
    const { container } = render(<ChordPlayButton midiNotes={[]} />)
    expect(container.firstChild).toBeNull()
  })

  it("renders a play button when midiNotes are provided", () => {
    render(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    expect(screen.getByRole("button", { name: "Play chord" })).toBeInTheDocument()
  })

  it("calls play with midiNotes when clicked", () => {
    render(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    fireEvent.click(screen.getByRole("button", { name: "Play chord" }))
    expect(mockPlay).toHaveBeenCalledWith([45, 52, 57, 60, 64])
  })

  it("disables the button while loading", () => {
    mockUseChordAudio.mockReturnValue({ play: mockPlay, isLoading: true, isPlaying: false })
    render(<ChordPlayButton midiNotes={[45, 52, 57, 60, 64]} />)
    expect(screen.getByRole("button", { name: "Play chord" })).toBeDisabled()
  })
})
