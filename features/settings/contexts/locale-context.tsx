"use client"

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useTransition,
  useCallback,
  useMemo,
  type ReactNode
} from "react"
import type { Locale } from "@/lib/i18n/config"
import { defaultLocale } from "@/lib/i18n/config"
import type { Translations } from "@/lib/i18n/translations"
import en from "@/lib/i18n/locales/en.json"
import { setLocaleAction } from "@/lib/actions/locale"

// Only the default locale ships in the client bundle. Non-default locales are
// provided by the server via initialTranslations (SSR-consistent) or loaded on
// demand as a separate chunk when the user switches language at runtime.
async function loadTranslations(locale: Locale): Promise<Translations> {
  switch (locale) {
    case "es":
      return (await import("@/lib/i18n/locales/es.json")).default
    default:
      return en
  }
}

interface LocaleContextType {
  locale: Locale
  setLocale: (locale: Locale) => void
  t: Translations
}

const LocaleContext = createContext<LocaleContextType | undefined>(undefined)

export function LocaleProvider({
  children,
  initialLocale = defaultLocale,
  initialTranslations
}: {
  children: ReactNode
  initialLocale?: Locale
  initialTranslations?: Translations
}) {
  const [locale, setLocaleState] = useState<Locale>(initialLocale)
  const [loaded, setLoaded] = useState<Partial<Record<Locale, Translations>>>(() =>
    initialTranslations ? { [initialLocale]: initialTranslations } : {}
  )
  const [, startTransition] = useTransition()

  const setLocale = useCallback(
    (newLocale: Locale) => {
      setLocaleState(newLocale)
      startTransition(async () => {
        await setLocaleAction(newLocale)
      })
    },
    [startTransition]
  )

  // Fetch the dictionary chunk when switching to a locale not yet in memory
  useEffect(() => {
    if (locale === defaultLocale || loaded[locale]) return
    let cancelled = false
    void loadTranslations(locale).then((dict) => {
      if (!cancelled) setLoaded((prev) => ({ ...prev, [locale]: dict }))
    })
    return () => {
      cancelled = true
    }
  }, [locale, loaded])

  const translations = locale === defaultLocale ? en : (loaded[locale] ?? en)

  const value = useMemo(
    () => ({ locale, setLocale, t: translations }),
    [locale, setLocale, translations]
  )

  return <LocaleContext.Provider value={value}>{children}</LocaleContext.Provider>
}

export function useLocale() {
  const context = useContext(LocaleContext)
  if (context === undefined) {
    throw new Error("useLocale must be used within a LocaleProvider")
  }
  return context
}
