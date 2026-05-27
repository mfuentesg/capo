"use client"

import Link from "next/link"
import { Sparkles } from "lucide-react"
import { DropdownMenuItem, DropdownMenuSeparator } from "@/components/ui/dropdown-menu"
import { Mail, LogOut, Settings } from "lucide-react"
import { useSignOut } from "@/features/auth"
import { useLocale, usePalette, useFont } from "@/features/settings"
import { VALID_PALETTES } from "@/lib/palette"
import { VALID_UI_FONTS } from "@/lib/font"
import { ThemeMenuItem } from "@/components/layout/theme-menu-item"

export function ProfileMenuActions() {
  const { t } = useLocale()
  const { palette, setPalette } = usePalette()
  const { font, setFont } = useFont()
  const signOut = useSignOut()

  const surpriseMe = () => {
    const otherPalettes = VALID_PALETTES.filter((p) => p !== palette)
    const otherFonts = VALID_UI_FONTS.filter((f) => f !== font)
    setPalette(otherPalettes[Math.floor(Math.random() * otherPalettes.length)])
    setFont(otherFonts[Math.floor(Math.random() * otherFonts.length)])
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
        <ThemeMenuItem />
        <DropdownMenuItem
          className="flex items-center gap-2 focus:bg-transparent cursor-default mt-0.5"
          onSelect={(e) => e.preventDefault()}
        >
          <span className="text-sm flex-1 text-muted-foreground">{t.settings.surpriseMe}</span>
          <button
            type="button"
            onClick={surpriseMe}
            className="flex items-center gap-1.5 rounded-full border border-border bg-muted/60 px-2.5 py-1 text-xs font-medium text-muted-foreground transition-colors hover:bg-muted hover:text-foreground active:scale-[0.97]"
          >
            <Sparkles className="h-3 w-3" />
          </button>
        </DropdownMenuItem>
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
