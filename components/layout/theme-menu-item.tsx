"use client"

import { useSyncExternalStore, useTransition } from "react"
import { useTheme } from "next-themes"
import { Sun, Moon, Monitor, Sparkles } from "lucide-react"
import { useLocale } from "@/features/settings"
import { cn } from "@/lib/utils"
import { setThemeAction } from "@/lib/actions/theme"
import { DropdownMenuItem } from "@/components/ui/dropdown-menu"

const THEMES = ["light", "dark", "system"] as const
type Theme = (typeof THEMES)[number]

const subscribe = () => () => {}

export function ThemeMenuItem({ onSurprise }: { onSurprise?: () => void }) {
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
    <DropdownMenuItem
      className="flex items-center gap-2 focus:bg-transparent cursor-default"
      onSelect={(e) => e.preventDefault()}
    >
      <span className="text-sm flex-1 text-muted-foreground">{t.settings.theme}</span>
      <div className="flex items-center gap-0.5" role="radiogroup" aria-label={t.settings.theme}>
        {THEMES.map((option) => {
          const { icon: Icon, label } = themeConfig[option]
          const isActive = activeTheme === option
          return (
            <button
              key={option}
              type="button"
              role="radio"
              aria-checked={isActive}
              aria-label={label}
              onClick={() => handleThemeChange(option)}
              className={cn(
                "flex items-center justify-center h-7 w-7 rounded-md transition-colors",
                isActive
                  ? "bg-primary/10 text-primary"
                  : "text-muted-foreground hover:bg-muted hover:text-foreground"
              )}
            >
              <Icon className="h-4 w-4" />
            </button>
          )
        })}
        {onSurprise && (
          <>
            <div className="w-px h-4 bg-border/60 mx-0.5" />
            <button
              type="button"
              aria-label={t.settings.surpriseMe}
              onClick={onSurprise}
              className="flex items-center justify-center h-7 w-7 rounded-md transition-colors text-muted-foreground hover:bg-muted hover:text-foreground active:scale-90"
            >
              <Sparkles className="h-4 w-4" />
            </button>
          </>
        )}
      </div>
    </DropdownMenuItem>
  )
}
