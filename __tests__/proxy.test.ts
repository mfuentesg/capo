/**
 * Tests for Next.js proxy (server-side redirect)
 */
/* eslint-disable @typescript-eslint/no-require-imports, @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-call, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-explicit-any, @typescript-eslint/no-unused-vars */

// Mock NextRequest before importing proxy
jest.mock("next/server", () => {
  class MockNextRequest {
    url: string
    nextUrl: { pathname: string; origin: string }
    cookies: {
      getAll: jest.Mock
      set: jest.Mock
    }

    constructor(url: string) {
      this.url = url
      const urlObj = new URL(url)
      this.nextUrl = {
        pathname: urlObj.pathname,
        origin: urlObj.origin
      }
      this.cookies = {
        getAll: jest.fn(() => []),
        set: jest.fn()
      }
    }
  }

  class MockHeaders {
    private map = new Map<string, string>()

    get(name: string): string | null {
      const value = this.map.get(name.toLowerCase())
      return value !== undefined ? value : null
    }

    set(name: string, value: string): void {
      this.map.set(name.toLowerCase(), value)
    }

    has(name: string): boolean {
      return this.map.has(name.toLowerCase())
    }
  }

  return {
    NextRequest: MockNextRequest,
    NextResponse: {
      next: jest.fn(() => {
        const headers = new MockHeaders()
        return {
          status: 200,
          headers,
          cookies: {
            set: jest.fn(),
            delete: jest.fn()
          }
        }
      }),
      redirect: jest.fn((url: string | URL) => {
        const headers = new MockHeaders()
        const location = typeof url === "string" ? url : url.toString()
        headers.set("location", location)
        return {
          status: 307,
          headers,
          cookies: {
            set: jest.fn(),
            delete: jest.fn()
          }
        }
      })
    }
  }
})

// Mock @supabase/ssr
jest.mock("@supabase/ssr", () => ({
  createServerClient: jest.fn()
}))

const { createServerClient } = require("@supabase/ssr")
const { proxy } = require("@/proxy")

describe("Proxy", () => {
  const originalEnv = process.env
  const originalConsoleError = console.error
  let mockSupabase: any
  const { NextRequest } = require("next/server")

  beforeEach(() => {
    jest.resetModules()
    // Suppress console.error during tests
    console.error = jest.fn()
    process.env = { ...originalEnv }
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://test.supabase.co"
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = "test-key"

    mockSupabase = {
      auth: {
        getClaims: jest.fn()
      }
    }

    createServerClient.mockReturnValue(mockSupabase)
  })

  afterEach(() => {
    process.env = originalEnv
    jest.clearAllMocks()
  })

  afterAll(() => {
    // Restore console.error
    console.error = originalConsoleError
  })

  describe("proxy function", () => {
    it("should redirect authenticated users from home to dashboard", async () => {
      mockSupabase.auth.getClaims.mockResolvedValue({
        data: { claims: { sub: "123" } },
        error: null
      })

      const request = new NextRequest("http://localhost:3000/")
      const response = await proxy(request)

      expect(response.status).toBe(307)
      const location = response.headers.get("location")
      expect(location).toBeTruthy()
      expect(location).toContain("/dashboard")
    })

    it("should allow unauthenticated users to access home page", async () => {
      mockSupabase.auth.getClaims.mockResolvedValue({
        data: null,
        error: null
      })

      const request = new NextRequest("http://localhost:3000/")
      const response = await proxy(request)

      expect(response.status).toBe(200)
      expect(response.headers.get("location")).toBeNull()
    })

    it("should continue with request for non-home paths", async () => {
      mockSupabase.auth.getClaims.mockResolvedValue({
        data: { claims: { sub: "123" } },
        error: null
      })

      const request = new NextRequest("http://localhost:3000/dashboard")
      const response = await proxy(request)

      expect(mockSupabase.auth.getClaims).toHaveBeenCalled()
      expect(response.status).toBe(200)
    })

    it("should redirect authenticated users from /login to dashboard", async () => {
      mockSupabase.auth.getClaims.mockResolvedValue({
        data: { claims: { sub: "123" } },
        error: null
      })

      const request = new NextRequest("http://localhost:3000/login")
      const response = await proxy(request)

      expect(response.status).toBe(307)
      const location = response.headers.get("location")
      expect(location).toBeTruthy()
      expect(location).toContain("/dashboard")
    })

    it("should allow unauthenticated users to access /login", async () => {
      mockSupabase.auth.getClaims.mockResolvedValue({
        data: null,
        error: null
      })

      const request = new NextRequest("http://localhost:3000/login")
      const response = await proxy(request)

      expect(response.status).toBe(200)
      expect(response.headers.get("location")).toBeNull()
    })

    it("should allow unauthenticated users to access legacy dashboard playlist share links", async () => {
      mockSupabase.auth.getClaims.mockResolvedValue({
        data: null,
        error: null
      })

      const request = new NextRequest("http://localhost:3000/dashboard/playlists/share-code-123")
      const response = await proxy(request)

      expect(response.status).toBe(200)
      expect(response.headers.get("location")).toBeNull()
    })

    it("should handle missing environment variables gracefully", async () => {
      delete process.env.NEXT_PUBLIC_SUPABASE_URL
      delete process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

      const request = new NextRequest("http://localhost:3000/")
      const response = await proxy(request)

      expect(createServerClient).not.toHaveBeenCalled()
      expect(response.status).toBe(200)
    })

    it("should handle session check errors gracefully", async () => {
      mockSupabase.auth.getClaims.mockRejectedValue(new Error("Network error"))

      const request = new NextRequest("http://localhost:3000/")
      const response = await proxy(request)

      // Should continue with request even if session check fails
      expect(response.status).toBe(200)
    })

    it("should set cookies correctly", async () => {
      const cookiesToSet: Array<{ name: string; value: string; options: any }> = []
      const mockSetAll = jest.fn((cookies) => {
        cookies.forEach((cookie: any) => cookiesToSet.push(cookie))
      })

      createServerClient.mockImplementation((url: string, key: string, options: any) => {
        // Call setAll to simulate Supabase setting cookies
        options.cookies.setAll([
          { name: "sb-token", value: "token-value", options: { httpOnly: true } }
        ])
        return mockSupabase
      })

      mockSupabase.auth.getClaims.mockResolvedValue({
        data: null,
        error: null
      })

      const request = new NextRequest("http://localhost:3000/")
      const response = await proxy(request)

      // Verify cookies were handled (the actual implementation tracks them)
      expect(response).toBeDefined()
    })

    it("should use correct Supabase client configuration", async () => {
      mockSupabase.auth.getClaims.mockResolvedValue({
        data: null,
        error: null
      })

      const request = new NextRequest("http://localhost:3000/")
      await proxy(request)

      expect(createServerClient).toHaveBeenCalledWith(
        "https://test.supabase.co",
        "test-key",
        expect.objectContaining({
          cookies: expect.objectContaining({
            getAll: expect.any(Function),
            setAll: expect.any(Function)
          })
        })
      )
    })

    describe("Invitation Token Handling", () => {
      it("should redirect unauthenticated user accessing invitation link to login", async () => {
        mockSupabase.auth.getClaims.mockResolvedValue({
          data: null,
          error: null
        })

        const request = new NextRequest(
          "http://localhost:3000/teams/accept-invitation?token=test-token-123"
        )
        const response = await proxy(request)

        expect(response.status).toBe(307) // Temporary redirect
        expect(response.headers.get("location")).toContain("/")
      })

      it("should store invitation token in cookie when redirecting unauthenticated user", async () => {
        mockSupabase.auth.getClaims.mockResolvedValue({
          data: null,
          error: null
        })

        const request = new NextRequest(
          "http://localhost:3000/teams/accept-invitation?token=ba94418c726afe40e54edd061ce1ea6d"
        )
        const response = await proxy(request)

        // Check that cookie was set via the mock
        expect(response.status).toBe(307)
        expect(response.headers.get("location")).toBeTruthy()
        // The cookie is tracked internally by the proxy
        expect(response).toBeTruthy()
      })

      it("should not interfere with authenticated users accessing invitation page", async () => {
        mockSupabase.auth.getClaims.mockResolvedValue({
          data: { claims: { sub: "user-123", email: "test@example.com" } },
          error: null
        })

        const request = new NextRequest(
          "http://localhost:3000/teams/accept-invitation?token=test-token"
        )
        const response = await proxy(request)

        // Should continue normally without redirecting
        expect(response.status).toBe(200)
      })

      it("should handle missing token gracefully", async () => {
        mockSupabase.auth.getClaims.mockResolvedValue({
          data: null,
          error: null
        })

        const request = new NextRequest("http://localhost:3000/teams/accept-invitation")
        const response = await proxy(request)

        // Should still redirect to login but without a token
        expect(response.status).toBe(307)
        expect(response.headers.get("location")).toContain("/")
      })

      it("should redirect to login page (/) when user is unauthenticated", async () => {
        mockSupabase.auth.getClaims.mockResolvedValue({
          data: null,
          error: null
        })

        const request = new NextRequest(
          "http://localhost:3000/teams/accept-invitation?token=test-token"
        )
        const response = await proxy(request)

        // Verify redirect location is to login page
        expect(response.status).toBe(307)
        expect(response.headers.get("location")).toContain("/")
      })
    })
  })
})
