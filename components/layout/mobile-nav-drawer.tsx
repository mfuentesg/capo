"use client"

import { Button } from "@/components/ui/button"
import {
  Drawer,
  DrawerContent,
  DrawerHeader,
  DrawerTitle,
  DrawerTrigger
} from "@/components/ui/drawer"
import { OptimizedLogo } from "@/components/optimized-logo"
import { Menu, Check, CircleUserRound, Layers, LayoutDashboard, Music, ListMusic, Users, Guitar } from "lucide-react"
import { NavLinks } from "@/components/layout/nav-links"
import { useLocale } from "@/features/settings"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import { useViewFilter, useAppContext } from "@/features/app-context"
import { useUser } from "@/features/auth"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { TeamIcon } from "@/components/ui/icon-picker"
import { cn } from "@/lib/utils"
import type { ViewFilter } from "@/features/app-context"

interface MobileNavDrawerProps {
  isOpen: boolean
  onOpenChange: (open: boolean) => void
}

export function MobileNavDrawer({ isOpen, onOpenChange }: MobileNavDrawerProps) {
  const { t } = useLocale()
  const drawerIds = createOverlayIds("mobile-nav-drawer")
  const { viewFilter, setViewFilter } = useViewFilter()
  const { teams } = useAppContext()
  const { data: user } = useUser()

  const navItems = [
    { title: t.nav.dashboard, href: "/dashboard", icon: LayoutDashboard, exact: true },
    { title: t.nav.songs, href: "/dashboard/songs", icon: Music },
    { title: t.nav.playlists, href: "/dashboard/playlists", icon: ListMusic },
    { title: t.nav.chords, href: "/dashboard/chords", icon: Guitar },
    { title: t.nav.teams, href: "/dashboard/teams", icon: Users }
  ]

  function handleSelect(filter: ViewFilter) {
    setViewFilter(filter)
    onOpenChange(false)
  }

  const hasTeams = teams.length > 0
  const userName = user?.displayName || user?.email || "You"

  return (
    <Drawer open={isOpen} onOpenChange={onOpenChange} direction="left">
      <DrawerTrigger asChild>
        <Button
          variant="ghost"
          size="icon"
          className="mr-2 md:hidden"
          id={drawerIds.triggerId}
          aria-controls={drawerIds.contentId}
        >
          <Menu className="h-5 w-5" />
          <span className="sr-only">{t.common.toggleMenu}</span>
        </Button>
      </DrawerTrigger>
      <DrawerContent className="w-64" id={drawerIds.contentId}>
        <DrawerHeader>
          <DrawerTitle className="flex items-center gap-2">
            <OptimizedLogo
              name="capo-text"
              alt={t.common.capoLogo}
              width={80}
              height={27}
              className="dark:invert"
            />
          </DrawerTitle>
        </DrawerHeader>

        {/* Inline context section — no Popover inside Drawer */}
        <div className="px-3 pb-2" data-vaul-no-drag>
          <p className="px-1 py-1 text-xs font-bold uppercase tracking-widest text-muted-foreground">
            {t.nav.filterContext}
          </p>

          {hasTeams && (
            <button
              onClick={() => handleSelect({ type: "all" })}
              className={cn(
                "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left transition-colors hover:bg-accent",
                viewFilter.type === "all" && "bg-accent"
              )}
            >
              <Layers className="h-4 w-4 shrink-0 text-muted-foreground" />
              <span className="flex-1 text-sm">{t.nav.viewAll}</span>
              {viewFilter.type === "all" && <Check className="h-3.5 w-3.5 text-primary" />}
            </button>
          )}

          <button
            onClick={() => handleSelect({ type: "personal" })}
            className={cn(
              "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left transition-colors hover:bg-accent",
              viewFilter.type === "personal" && "bg-accent"
            )}
          >
            <Avatar className="h-5 w-5 shrink-0">
              {user?.avatarUrl && <AvatarImage src={user.avatarUrl} alt={userName} />}
              <AvatarFallback className="bg-primary/10">
                <CircleUserRound className="h-3 w-3 text-muted-foreground" />
              </AvatarFallback>
            </Avatar>
            <span className="flex-1 truncate text-sm">{userName}</span>
            {viewFilter.type === "personal" && <Check className="h-3.5 w-3.5 text-primary" />}
          </button>

          {teams.map((team) => (
            <button
              key={team.id}
              onClick={() => handleSelect({ type: "team", teamId: team.id })}
              className={cn(
                "flex w-full items-center gap-2 rounded-md px-2 py-1.5 text-left transition-colors hover:bg-accent",
                viewFilter.type === "team" && viewFilter.teamId === team.id && "bg-accent"
              )}
            >
              <Avatar className="h-5 w-5 shrink-0">
                {team.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
                <AvatarFallback className="bg-primary/10 text-[9px]">
                  <TeamIcon icon={team.icon} className="h-3 w-3" />
                </AvatarFallback>
              </Avatar>
              <span className="flex-1 truncate text-sm">{team.name}</span>
              {viewFilter.type === "team" && viewFilter.teamId === team.id && (
                <Check className="h-3.5 w-3.5 text-primary" />
              )}
            </button>
          ))}
        </div>

        <div className="border-t" />

        <nav className="mt-2 flex flex-col gap-2 px-3" data-vaul-no-drag>
          <NavLinks items={navItems} variant="vertical" onItemClick={() => onOpenChange(false)} />
        </nav>
      </DrawerContent>
    </Drawer>
  )
}
