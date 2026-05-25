"use client"

import { useLocale } from "@/features/settings"
import { locales, localeNames } from "@/lib/i18n/config"
import { cn } from "@/lib/utils"

const LOCALE_FLAGS: Record<string, string> = {
  en: "🇬🇧",
  es: "🇪🇸"
}

export function LanguageSettings() {
  const { t, locale, setLocale } = useLocale()

  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-base font-semibold tracking-tight">{t.settings.language}</h2>
        <p className="text-sm text-muted-foreground mt-0.5">{t.settings.languageDescription}</p>
      </div>
      <div className="flex flex-wrap gap-2" role="radiogroup" aria-label={t.settings.language}>
        {locales.map((loc) => {
          const isActive = locale === loc
          return (
            <label
              key={loc}
              className={cn(
                "relative flex cursor-pointer items-center gap-2.5 rounded-xl border px-4 py-3 text-sm font-medium transition select-none",
                "active:scale-[0.97]",
                isActive
                  ? "border-primary/60 bg-primary/8 text-primary shadow-sm"
                  : "border-border bg-muted/40 text-muted-foreground hover:bg-muted hover:text-foreground"
              )}
            >
              <input
                type="radio"
                name="language"
                value={loc}
                checked={isActive}
                onChange={() => setLocale(loc)}
                className="sr-only"
              />
              <span className="text-base leading-none" aria-hidden>
                {LOCALE_FLAGS[loc] ?? "🌐"}
              </span>
              <span>{localeNames[loc]}</span>
              {isActive && (
                <span className="absolute bottom-1 left-1/2 h-0.5 w-4 -translate-x-1/2 rounded-full bg-primary" />
              )}
            </label>
          )
        })}
      </div>
    </section>
  )
}
