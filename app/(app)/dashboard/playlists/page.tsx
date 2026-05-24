import type { Metadata } from "next"
import { redirect } from "next/navigation"
import { cookies } from "next/headers"
import { createClient } from "@/lib/supabase/server"
import { PlaylistsClient, rawApi as playlistsApi } from "@/features/playlists"
import { getTranslations } from "@/lib/i18n/translations"
import { defaultLocale, isValidLocale } from "@/lib/i18n/config"
import { getInitialAppContextData } from "@/features/app-context/server"

export const metadata: Metadata = {
  title: "Playlists",
  robots: { index: false, follow: false }
}

export default async function PlaylistsPage() {
  // getInitialAppContextData is React.cache()'d — returns the same result already
  // computed by the app layout, so no extra auth or DB round-trips happen here.
  const [cookieStore, appContextData] = await Promise.all([cookies(), getInitialAppContextData()])

  if (!appContextData.user) {
    redirect("/")
  }

  const { user, teams, preferences } = appContextData

  // Locale: DB value takes priority over the cookie (consistent with the layout)
  const dbLocale = preferences?.locale
  const localeCookie = cookieStore.get("NEXT_LOCALE")
  const locale =
    dbLocale && isValidLocale(dbLocale)
      ? dbLocale
      : localeCookie && isValidLocale(localeCookie.value)
        ? localeCookie.value
        : defaultLocale

  const teamIds = teams.map((t) => t.id)
  const supabase = await createClient()

  // Fetch playlists + translations in parallel now that teams are already available
  const [initialPlaylists, t] = await Promise.all([
    playlistsApi.getPlaylistsAllBuckets(supabase, user.id, teamIds).catch(() => []),
    getTranslations(locale)
  ])

  return <PlaylistsClient initialPlaylists={initialPlaylists} t={t} />
}
