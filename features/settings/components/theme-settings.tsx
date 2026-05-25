"use client"

import { useSyncExternalStore, useTransition } from "react"
import { useTheme } from "next-themes"
import { Sun, Moon, Monitor } from "lucide-react"
import { useLocale } from "@/features/settings"
import { cn } from "@/lib/utils"
import { setThemeAction } from "@/lib/actions/theme"

const THEMES = ["light", "dark", "system"] as const
type Theme = (typeof THEMES)[number]

// next-themes reads from localStorage on the client, which may differ from the
// SSR defaultTheme prop. useSyncExternalStore gives false on the server and true
// on the client — React re-renders with the correct theme after hydration without
// a className mismatch or a setState-in-effect lint violation.
const subscribe = () => () => {}

export function ThemeSettings() {
  const { t } = useLocale()
  const { theme, setTheme } = useTheme()
  const [, startTransition] = useTransition()
  const mounted = useSyncExternalStore(subscribe, () => true, () => false)

  const activeTheme = mounted ? theme : undefined

  const themeConfig: Record<Theme, { icon: typeof Sun; label: string }> = {
    light: { icon: Sun, label: t.settings.themeLight },
    dark: { icon: Moon, label: t.settings.themeDark },
    system: { icon: Monitor, label: t.settings.themeSystem }
  }

  function handleThemeChange(option: Theme) {
    setTheme(option)
    startTransition(async () => {
      await setThemeAction(option)
    })
  }

  return (
    <section className="space-y-4">
      <div>
        <h2 className="text-base font-semibold tracking-tight">{t.settings.appearance}</h2>
        <p className="text-sm text-muted-foreground mt-0.5">{t.settings.themeDescription}</p>
      </div>
      <div className="grid grid-cols-3 gap-2" role="radiogroup" aria-label={t.settings.theme}>
        {THEMES.map((option) => {
          const { icon: Icon, label } = themeConfig[option]
          const isActive = activeTheme === option
          return (
            <label
              key={option}
              className={cn(
                "relative flex cursor-pointer flex-col items-center gap-2 rounded-xl border px-3 py-4 text-sm font-medium transition select-none",
                "active:scale-[0.97]",
                isActive
                  ? "border-primary/60 bg-primary/8 text-primary shadow-sm"
                  : "border-border bg-muted/40 text-muted-foreground hover:bg-muted hover:text-foreground"
              )}
            >
              <input
                type="radio"
                name="theme"
                value={option}
                checked={isActive}
                onChange={() => handleThemeChange(option)}
                className="sr-only"
              />
              <Icon className={cn("h-5 w-5", isActive ? "text-primary" : "text-muted-foreground")} />
              <span className="text-xs leading-none">{label}</span>
              {isActive && (
                <span className="absolute bottom-1.5 left-1/2 h-1 w-4 -translate-x-1/2 rounded-full bg-primary" />
              )}
            </label>
          )
        })}
      </div>
    </section>
  )
}
