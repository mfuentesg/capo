import { fireEvent, render, screen, waitFor } from "@testing-library/react"
import { LocaleProvider } from "@/features/settings"
import { ApiTokensSettings } from "../components/api-tokens-settings"
import {
  createApiTokenAction,
  revokeApiTokenAction,
  listApiTokensAction
} from "../api/actions"

jest.mock("../api/actions", () => ({
  createApiTokenAction: jest.fn(),
  revokeApiTokenAction: jest.fn(),
  listApiTokensAction: jest.fn()
}))

const list = listApiTokensAction as jest.Mock
const create = createApiTokenAction as jest.Mock
const revoke = revokeApiTokenAction as jest.Mock

const active = {
  id: "1",
  name: "laptop",
  created_at: "2026-01-02T00:00:00Z",
  last_used_at: null,
  revoked_at: null
}
const dead = {
  id: "2",
  name: "old phone",
  created_at: "2026-01-01T00:00:00Z",
  last_used_at: "2026-01-03T00:00:00Z",
  revoked_at: "2026-01-04T00:00:00Z"
}

const renderIt = () =>
  render(
    <LocaleProvider>
      <ApiTokensSettings />
    </LocaleProvider>
  )

describe("ApiTokensSettings", () => {
  beforeEach(() => {
    jest.clearAllMocks()
    list.mockResolvedValue([active, dead])
  })

  it("lists tokens; revoked ones show a badge and no revoke button", async () => {
    renderIt()
    expect(await screen.findByText("laptop")).toBeInTheDocument()
    expect(screen.getByText("old phone")).toBeInTheDocument()
    expect(screen.getByText(/Never used/)).toBeInTheDocument()
    expect(screen.getByText("Revoked")).toBeInTheDocument()
    expect(screen.getByRole("button", { name: /revoke token laptop/i })).toBeInTheDocument()
    expect(screen.queryByRole("button", { name: /revoke token old phone/i })).toBeNull()
  })

  it("shows the plaintext token once in a read-only field, refreshes, and clears on close", async () => {
    create.mockResolvedValue({ id: "3", token: "capo_secret123" })
    renderIt()
    await screen.findByText("laptop")

    fireEvent.change(screen.getByLabelText("Token name"), { target: { value: "ci" } })
    fireEvent.click(screen.getByRole("button", { name: "Create token" }))

    const field = await screen.findByDisplayValue("capo_secret123")
    expect(field).toHaveAttribute("readonly")
    expect(screen.getByText(/will not be shown again/i)).toBeInTheDocument()
    expect(screen.getByRole("button", { name: "Copy" })).toBeInTheDocument()
    expect(create).toHaveBeenCalledWith("ci")
    await waitFor(() => expect(list).toHaveBeenCalledTimes(2))

    fireEvent.click(screen.getByRole("button", { name: "Close" }))
    expect(screen.queryByDisplayValue("capo_secret123")).toBeNull()
    expect(document.body.textContent).not.toContain("capo_secret123")
  })

  it("revokes a token", async () => {
    revoke.mockResolvedValue(undefined)
    renderIt()
    fireEvent.click(await screen.findByRole("button", { name: /revoke token laptop/i }))
    expect(revoke).toHaveBeenCalledWith("1")
    await waitFor(() => expect(list).toHaveBeenCalledTimes(2))
  })
})
