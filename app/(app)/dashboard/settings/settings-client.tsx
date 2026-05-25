"use client"

import { useState } from "react"
import {
  ProfileSettings,
  ThemeSettings,
  LanguageSettings,
  AccountDangerZone,
  ChordHandSettings,
  PaletteSettings,
  useLocale
} from "@/features/settings"
import { Separator } from "@/components/ui/separator"
import { User, Palette, ShieldAlert } from "lucide-react"
import { cn } from "@/lib/utils"

type Section = "profile" | "appearance" | "account"

const NAV_ITEMS: { id: Section; label: string; icon: typeof User }[] = [
  { id: "profile", label: "Profile", icon: User },
  { id: "appearance", label: "Appearance", icon: Palette },
  { id: "account", label: "Account", icon: ShieldAlert }
]

export function SettingsClient() {
  const { t } = useLocale()
  const [active, setActive] = useState<Section>("profile")

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <h1 className="text-3xl font-bold tracking-tight leading-none mb-8">{t.settings.title}</h1>

      <div className="flex flex-col sm:flex-row gap-6 sm:gap-8 items-start">
        {/* Nav — horizontal scrollable tabs on mobile, vertical sidebar on sm+ */}
        <nav className="w-full sm:w-44 sm:shrink-0">
          {/* Mobile: horizontal pill tabs */}
          <div className="flex sm:hidden gap-1 overflow-x-auto pb-1 -mx-4 px-4 scrollbar-none">
            {NAV_ITEMS.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActive(id)}
                className={cn(
                  "flex shrink-0 items-center gap-2 px-4 py-2 rounded-full text-sm font-medium transition-colors whitespace-nowrap",
                  active === id
                    ? "bg-primary/10 text-primary"
                    : "text-muted-foreground bg-muted/60 hover:bg-muted hover:text-foreground"
                )}
              >
                <Icon className="h-4 w-4 shrink-0" />
                {label}
              </button>
            ))}
          </div>
          {/* Desktop: vertical sidebar */}
          <div className="hidden sm:flex flex-col space-y-0.5">
            {NAV_ITEMS.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                onClick={() => setActive(id)}
                className={cn(
                  "w-full flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm font-medium transition-colors text-left",
                  active === id
                    ? "bg-primary/10 text-primary"
                    : "text-muted-foreground hover:bg-muted hover:text-foreground"
                )}
              >
                <Icon className="h-4 w-4 shrink-0" />
                {label}
              </button>
            ))}
          </div>
        </nav>

        {/* Content panel */}
        <div className="flex-1 min-w-0">
          {active === "profile" && (
            <div className="rounded-2xl border bg-card p-6 shadow-sm">
              <ProfileSettings />
            </div>
          )}

          {active === "appearance" && (
            <div className="rounded-2xl border bg-card p-6 shadow-sm space-y-6">
              <PaletteSettings />
              <Separator />
              <ThemeSettings />
              <Separator />
              <LanguageSettings />
              <Separator />
              <ChordHandSettings />
            </div>
          )}

          {active === "account" && (
            <div className="rounded-2xl border border-destructive/30 bg-destructive/[0.02] p-6 shadow-sm">
              <AccountDangerZone />
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
