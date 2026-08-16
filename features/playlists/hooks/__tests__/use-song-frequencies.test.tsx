import React from "react"
import { renderHook, waitFor } from "@testing-library/react"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { useSongFrequencies } from "@/features/playlists/hooks/use-song-frequencies"
import { getSongFrequenciesAction } from "@/features/playlists/api/actions"
import { useAppContext } from "@/features/app-context"

jest.mock("@/features/playlists/api/actions", () => ({
  getSongFrequenciesAction: jest.fn()
}))

jest.mock("@/features/app-context", () => ({
  useAppContext: jest.fn()
}))

const mockUseAppContext = useAppContext as jest.Mock
const mockGetSongFrequenciesAction = getSongFrequenciesAction as jest.Mock

const context = { type: "personal" as const, userId: "user-1" }

describe("useSongFrequencies", () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } }
    })
    mockUseAppContext.mockReturnValue({ context })
    jest.clearAllMocks()
  })

  afterEach(() => {
    queryClient.clear()
  })

  const wrapper = ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )

  it("fetches song frequencies for the current app context", async () => {
    const frequencies = new Map([["song-1", { count: 3, lastPlayedDate: "2026-01-15" }]])
    mockGetSongFrequenciesAction.mockResolvedValue(frequencies)

    const { result } = renderHook(() => useSongFrequencies(), { wrapper })

    await waitFor(() => expect(result.current.data).toEqual(frequencies))
    expect(mockGetSongFrequenciesAction).toHaveBeenCalledWith(context)
  })
})
