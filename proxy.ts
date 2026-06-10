import { NextResponse, type NextRequest } from "next/server"
import { createServerClient, type CookieMethodsServer } from "@supabase/ssr"
import { DEFAULT_REDIRECT_PATH, LOGIN_PATH } from "@/lib/supabase/constants"

interface SupabaseEnvVars {
  supabaseUrl: string
  supabasePublishableKey: string
}

type CookieToSet = {
  name: string
  value: string
  options: Partial<{
    httpOnly?: boolean
    secure?: boolean
    sameSite?: boolean | "strict" | "lax" | "none"
    maxAge?: number
    path?: string
    domain?: string
    expires?: Date
  }>
}

function validateEnvVars(): SupabaseEnvVars | null {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabasePublishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY

  if (!supabaseUrl || !supabasePublishableKey) {
    return null
  }

  return { supabaseUrl, supabasePublishableKey }
}

function createSupabaseClient(
  request: NextRequest,
  envVars: SupabaseEnvVars,
  cookiesToSet: CookieToSet[]
) {
  const cookies: CookieMethodsServer = {
    getAll() {
      return request.cookies.getAll()
    },
    setAll(cookiesToSetFromSupabase) {
      cookiesToSetFromSupabase.forEach(({ name, value, options }) => {
        request.cookies.set(name, value)
        cookiesToSet.push({ name, value, options })
      })
    }
  }

  return createServerClient(envVars.supabaseUrl, envVars.supabasePublishableKey, {
    cookies
  })
}

function applyCookiesToResponse(response: NextResponse, cookiesToSet: CookieToSet[]): void {
  cookiesToSet.forEach(({ name, value, options }) => {
    response.cookies.set(name, value, {
      ...options,
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax"
    })
  })
}

function shouldRedirectToDashboard(claims: unknown): boolean {
  return !!claims
}

function shouldRedirectToLogin(claims: unknown, error: unknown): boolean {
  return !!error || !claims
}

function extractInvitationToken(request: NextRequest): string | null {
  const url = new URL(request.url)
  return url.searchParams.get("token")
}

function isLegacyPublicSharePath(pathname: string): boolean {
  return /^\/dashboard\/playlists\/[^/]+\/?$/.test(pathname)
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl
  const envVars = validateEnvVars()

  if (!envVars) {
    return NextResponse.next()
  }

  try {
    const cookiesToSet: CookieToSet[] = []
    const supabase = createSupabaseClient(request, envVars, cookiesToSet)

    // getClaims verifies the JWT locally (against cached JWKS) instead of
    // calling the Supabase Auth server on every request like getUser does.
    // Expired sessions are still refreshed automatically before verification.
    const { data, error } = await supabase.auth.getClaims()
    const claims = data?.claims ?? null

    let response: NextResponse = NextResponse.next()

    if (
      (pathname === "/" || pathname === "/login") &&
      shouldRedirectToDashboard(claims)
    ) {
      response = NextResponse.redirect(new URL(DEFAULT_REDIRECT_PATH, request.url))
    } else if (
      pathname.startsWith("/dashboard") &&
      shouldRedirectToLogin(claims, error) &&
      !isLegacyPublicSharePath(pathname)
    ) {
      response = NextResponse.redirect(new URL(LOGIN_PATH, request.url))
    } else if (
      pathname.startsWith("/teams/accept-invitation") &&
      shouldRedirectToLogin(claims, error)
    ) {
      // Unauthenticated user accessing invitation link
      const token = extractInvitationToken(request)
      const redirectUrl = new URL(LOGIN_PATH, request.url)

      if (token) {
        // Store invitation token for retrieval after authentication
        cookiesToSet.push({
          name: "_invitation_token",
          value: token,
          options: { path: "/" }
        })
      }

      response = NextResponse.redirect(redirectUrl)
    }

    applyCookiesToResponse(response, cookiesToSet)
    return response
  } catch (error) {
    console.error("Error in proxy:", error)
    return NextResponse.next()
  }
}

export const config = {
  matcher: ["/", "/login", "/dashboard/:path*", "/teams/accept-invitation/:path*"]
}
