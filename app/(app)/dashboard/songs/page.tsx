import type { Metadata } from "next"
import { redirect } from "next/navigation"
import { cookies } from "next/headers"
import { SongsClient } from "@/features/songs"
import { getSongsAllBucketsAction } from "@/features/songs/api/actions"
import { getTranslations } from "@/lib/i18n/translations"
import { defaultLocale, isValidLocale } from "@/lib/i18n/config"
import { getInitialAppContextData } from "@/features/app-context/server"

export const metadata: Metadata = {
  title: "Songs",
  robots: { index: false, follow: false }
}

export default async function SongsPage() {
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
  const teamsMeta = teams.map((t) => ({ id: t.id, name: t.name, icon: t.icon ?? null }))

  // Fetch songs (with tags) + translations in parallel
  const [initialSongs, t] = await Promise.all([
    getSongsAllBucketsAction(user.id, teamIds, teamsMeta).catch(() => []),
    getTranslations(locale)
  ])

  return <SongsClient initialSongs={initialSongs} t={t} />
}
