import type React from "react"
import { cookies } from "next/headers"
import { QueryProvider } from "@/components/providers/query-provider"
import { LocaleProvider } from "@/features/settings"
import { defaultLocale, isValidLocale } from "@/lib/i18n/config"
import type { Locale } from "@/lib/i18n/config"
import { getTranslations } from "@/lib/i18n/translations"

export default async function PublicLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const cookieStore = await cookies()
  const localeCookie = cookieStore.get("NEXT_LOCALE")
  const initialLocale: Locale =
    localeCookie && isValidLocale(localeCookie.value) ? localeCookie.value : defaultLocale

  return (
    <QueryProvider initialUser={null}>
      <LocaleProvider
        initialLocale={initialLocale}
        // Non-default locales aren't in the client bundle — provide the
        // dictionary from the server so SSR and hydration stay consistent
        initialTranslations={
          initialLocale !== defaultLocale ? getTranslations(initialLocale) : undefined
        }
      >
        {children}
      </LocaleProvider>
    </QueryProvider>
  )
}
