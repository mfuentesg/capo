"use client"

import Link from "next/link"
import { useTransition } from "react"
import { useTheme } from "next-themes"
import { DropdownMenuItem, DropdownMenuSeparator } from "@/components/ui/dropdown-menu"
import { Mail, LogOut, Settings } from "lucide-react"
import { useSignOut } from "@/features/auth"
import { useLocale, usePalette, useFont } from "@/features/settings"
import { VALID_PALETTES } from "@/lib/palette"
import { VALID_UI_FONTS } from "@/lib/font"
import { setThemeAction } from "@/lib/actions/theme"
import { ThemeMenuItem } from "@/components/layout/theme-menu-item"

export function ProfileMenuActions() {
  const { t } = useLocale()
  const { palette, setPalette } = usePalette()
  const { font, setFont } = useFont()
  const { theme, setTheme } = useTheme()
  const [, startTransition] = useTransition()
  const signOut = useSignOut()

  const surpriseMe = () => {
    const otherPalettes = VALID_PALETTES.filter((p) => p !== palette)
    const otherFonts = VALID_UI_FONTS.filter((f) => f !== font)
    const modes = ["light", "dark"] as const
    const otherModes = modes.filter((m) => m !== theme)
    const newTheme = otherModes[Math.floor(Math.random() * otherModes.length)] ?? "dark"
    setPalette(otherPalettes[Math.floor(Math.random() * otherPalettes.length)])
    setFont(otherFonts[Math.floor(Math.random() * otherFonts.length)])
    setTheme(newTheme)
    startTransition(async () => {
      await setThemeAction(newTheme)
    })
  }

  const handleSignOut = async () => {
    await signOut.mutateAsync()
  }

  return (
    <>
      <div className="p-1">
        <DropdownMenuItem asChild className="flex items-center gap-2">
          <Link href="/dashboard/settings">
            <Settings className="h-4 w-4" />
            <span>{t.nav.settings}</span>
          </Link>
        </DropdownMenuItem>
        <DropdownMenuItem asChild className="flex items-center gap-2">
          <Link href="/dashboard/invitations" onClick={(e) => e.stopPropagation()}>
            <Mail className="h-4 w-4" />
            <span>{t.nav.invitations}</span>
          </Link>
        </DropdownMenuItem>
      </div>

      <DropdownMenuSeparator />
      <div className="p-1">
        <ThemeMenuItem onSurprise={surpriseMe} />
      </div>

      <DropdownMenuSeparator />
      <div className="p-1">
        <DropdownMenuItem
          onClick={handleSignOut}
          disabled={signOut.isPending}
          className="flex items-center gap-2 text-destructive focus:text-destructive"
        >
          <LogOut className="h-4 w-4" />
          <span>{signOut.isPending ? t.common.loading || "Loading..." : t.nav.logout}</span>
        </DropdownMenuItem>
      </div>
    </>
  )
}
