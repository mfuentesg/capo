import type React from "react"
import { cookies } from "next/headers"
import { QueryProvider } from "@/components/providers/query-provider"
import { AuthStateProvider } from "@/features/auth"
import { AppContextProvider } from "@/features/app-context"
import { LocaleProvider, ChordHandProvider, PaletteProvider, FontProvider } from "@/features/settings"
import type { ChordHand } from "@/lib/actions/chord-hand"
import { getInitialAppContextData } from "@/features/app-context/server"
import { defaultLocale, isValidLocale } from "@/lib/i18n/config"
import type { Locale } from "@/lib/i18n/config"
import { isValidPalette, DEFAULT_PALETTE } from "@/lib/palette"
import { isValidUIFont, DEFAULT_UI_FONT } from "@/lib/font"

export default async function AppLayout({
  children
}: Readonly<{ children: React.ReactNode }>) {
  const appContextData = await getInitialAppContextData()

  const cookieStore = await cookies()

  // DB locale takes priority; cookie is fallback for unauthenticated edge cases
  const dbLocale = appContextData.preferences?.locale
  let initialLocale: Locale
  if (dbLocale && isValidLocale(dbLocale)) {
    initialLocale = dbLocale
  } else {
    const localeCookie = cookieStore.get("NEXT_LOCALE")
    initialLocale =
      localeCookie && isValidLocale(localeCookie.value) ? localeCookie.value : defaultLocale
  }

  // Chord hand: DB takes priority, then cookie, then default ("left")
  const dbChordHand = appContextData.preferences?.chordHand
  let initialChordHand: ChordHand
  if (dbChordHand === "right" || dbChordHand === "left") {
    initialChordHand = dbChordHand
  } else {
    const chordHandCookie = cookieStore.get("NEXT_CHORD_HAND")
    initialChordHand = chordHandCookie?.value === "right" ? "right" : "left"
  }

  // Palette: cookie (DB sync is write-only via action)
  const paletteCookie = cookieStore.get("NEXT_PALETTE")
  const initialPalette = isValidPalette(paletteCookie?.value) ? paletteCookie.value : DEFAULT_PALETTE

  // Font: cookie (DB sync is write-only via action)
  const fontCookie = cookieStore.get("NEXT_UI_FONT")
  const initialFont = isValidUIFont(fontCookie?.value) ? fontCookie.value : DEFAULT_UI_FONT

  return (
    <QueryProvider initialUser={appContextData.user}>
      <AuthStateProvider>
        <AppContextProvider
          initialSelectedTeamId={appContextData.initialSelectedTeamId}
          initialTeams={appContextData.teams}
          initialUser={appContextData.user}
          initialViewFilter={appContextData.initialViewFilter}
        >
          <LocaleProvider initialLocale={initialLocale}>
            <ChordHandProvider initialChordHand={initialChordHand}>
              <PaletteProvider initialPalette={initialPalette}>
                <FontProvider initialFont={initialFont}>{children}</FontProvider>
              </PaletteProvider>
            </ChordHandProvider>
          </LocaleProvider>
        </AppContextProvider>
      </AuthStateProvider>
    </QueryProvider>
  )
}
