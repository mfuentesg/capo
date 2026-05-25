"use client"

import { CircleUserRound, KeyRound } from "lucide-react"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { useUser } from "@/features/auth"
import { useLocale } from "@/features/settings"
import { getInitials } from "@/lib/utils"

function formatProviderName(provider?: string): string {
  if (!provider) return "Email"
  return provider.charAt(0).toUpperCase() + provider.slice(1)
}

export function ProfileSettings() {
  const { t } = useLocale()
  const { data: user } = useUser()

  const displayName = user?.displayName || user?.fullName || user?.email || "—"
  const initials = getInitials(displayName)
  const providerName = formatProviderName(user?.provider)

  return (
    <section className="space-y-5">
      <div>
        <h2 className="text-base font-semibold tracking-tight">{t.settings.profile}</h2>
        <p className="text-sm text-muted-foreground mt-0.5">{t.settings.profileDescription}</p>
      </div>

      <div className="flex items-center gap-4">
        <div className="relative shrink-0">
          <Avatar className="h-16 w-16">
            <AvatarImage src={user?.avatarUrl} alt={displayName} />
            <AvatarFallback className="bg-primary/10 text-xl font-bold text-primary">
              {initials || <CircleUserRound className="h-8 w-8 text-muted-foreground" />}
            </AvatarFallback>
          </Avatar>
        </div>

        <div className="min-w-0 flex-1 space-y-1">
          <p className="truncate font-bold tracking-tight">{displayName}</p>
          {user?.email && (
            <p className="truncate text-sm text-muted-foreground">{user.email}</p>
          )}
          <div className="inline-flex items-center gap-1.5 rounded-full bg-muted px-2.5 py-1 text-xs font-medium text-muted-foreground">
            <KeyRound className="h-3 w-3" />
            {t.settings.connectedVia.replace("{provider}", providerName)}
          </div>
        </div>
      </div>
    </section>
  )
}
