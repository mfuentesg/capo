"use client"

import { useState } from "react"
import { useRouter } from "next/navigation"
import { useUser } from "@/features/auth"
import { useAcceptTeamInvitation, usePendingInvitations, mapInvitationAcceptError } from "@/features/teams"
import type { PendingInvitation } from "@/features/teams"
import type { Translations } from "@/lib/i18n/translations"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { Spinner } from "@/components/ui/spinner"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Badge } from "@/components/ui/badge"
import { Mail, CheckCircle, Clock, AlertCircle, ArrowLeft } from "lucide-react"
import { cn } from "@/lib/utils"

function getExpiryMeta(expiresAt: string): { label: string; className: string; isExpired: boolean } {
  const now = new Date()
  const expires = new Date(expiresAt)
  const isExpired = expires < now
  if (isExpired) return { label: "", className: "text-destructive", isExpired: true }
  const daysLeft = Math.ceil((expires.getTime() - now.getTime()) / 86400000)
  const className =
    daysLeft <= 2 ? "text-destructive" : daysLeft <= 5 ? "text-amber-500" : "text-muted-foreground"
  return { label: expires.toLocaleDateString(), className, isExpired: false }
}

export function InvitationCardSkeleton() {
  return (
    <div className="rounded-2xl border bg-card shadow-sm p-6 space-y-4">
      <div className="flex items-start justify-between">
        <div className="space-y-2">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-4 w-36" />
        </div>
        <Skeleton className="h-5 w-16 rounded-full" />
      </div>
      <div className="flex items-center gap-4">
        <Skeleton className="h-4 w-40" />
        <Skeleton className="h-4 w-28" />
      </div>
      <Skeleton className="h-10 w-full rounded-lg" />
    </div>
  )
}

export function PendingInvitationsClient({
  t,
  initialInvitations = []
}: {
  t: Translations
  initialInvitations?: PendingInvitation[]
}) {
  const router = useRouter()
  const { isLoading: userLoading } = useUser()
  const {
    data: invitations = initialInvitations,
    isLoading: invitationsLoading,
    error: fetchError
  } = usePendingInvitations(initialInvitations)
  const acceptInvitationMutation = useAcceptTeamInvitation()
  const [error, setError] = useState<string>("")
  const [acceptingId, setAcceptingId] = useState<string | null>(null)

  const handleAcceptInvitation = async (token: string, invitationId: string) => {
    try {
      setAcceptingId(invitationId)
      await acceptInvitationMutation.mutateAsync({ token })
    } catch (err) {
      setError(mapInvitationAcceptError(err, t))
      setAcceptingId(null)
    }
  }

  const isLoading = userLoading || invitationsLoading
  const hasError = !!error || !!fetchError

  if (isLoading) {
    return (
      <div className="min-h-screen bg-background p-4 sm:p-6 lg:p-8">
        <div className="mx-auto max-w-2xl space-y-6">
          <div className="space-y-2">
            <Skeleton className="h-10 w-56" />
            <Skeleton className="h-5 w-80" />
          </div>
          <div className="space-y-4">
            <InvitationCardSkeleton />
            <InvitationCardSkeleton />
          </div>
          <Skeleton className="h-10 w-full rounded-lg" />
        </div>
      </div>
    )
  }

  return (
    <div className="relative min-h-screen bg-background p-4 sm:p-6 lg:p-8 overflow-hidden">
      {/* Gradient orbs */}
      <div className="pointer-events-none absolute inset-0 -z-10" aria-hidden>
        <div
          className="absolute -top-32 -right-32 h-[500px] w-[500px] rounded-full"
          style={{ background: "radial-gradient(circle, oklch(0.749 0.160 298 / 10%) 0%, transparent 70%)" }}
        />
        <div
          className="absolute -bottom-32 -left-32 h-[500px] w-[500px] rounded-full"
          style={{ background: "radial-gradient(circle, oklch(0.793 0.132 56 / 10%) 0%, transparent 70%)" }}
        />
      </div>

      <div className="mx-auto max-w-2xl space-y-6">
        {/* Header */}
        <div>
          <div className="flex items-baseline gap-2">
            <h1 className="text-3xl font-bold tracking-tight leading-none">
              {t.invitations.pendingTitle}
            </h1>
            {invitations.length > 0 && (
              <span className="text-lg text-muted-foreground tabular-nums">· {invitations.length}</span>
            )}
          </div>
          <p className="text-muted-foreground mt-2">{t.invitations.pendingDescription}</p>
        </div>

        {hasError && (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription className="ml-2">
              {error || (fetchError instanceof Error ? fetchError.message : t.invitations.loadFailed)}
            </AlertDescription>
          </Alert>
        )}

        {invitations.length === 0 ? (
          <div className="rounded-2xl border bg-card shadow-sm relative overflow-hidden">
            <div className="pointer-events-none select-none absolute inset-0 flex items-center justify-center" aria-hidden>
              <Mail style={{ width: "40%", height: "40%" }} className="text-foreground/[0.04]" />
            </div>
            <div className="relative p-8 space-y-4">
              <div className="h-0.5 w-8 rounded-full" style={{ background: "var(--accent-activity)" }} />
              <div className="space-y-1">
                <p className="font-bold text-lg tracking-tight leading-none">{t.invitations.emptyTitle}</p>
                <p className="text-sm text-muted-foreground">{t.invitations.emptyDescription}</p>
              </div>
              <Button onClick={() => router.push("/dashboard/teams")} className="transition active:scale-[0.98]">
                {t.invitations.goToTeams}
              </Button>
            </div>
          </div>
        ) : (
          <>
            <div className="space-y-4">
              {invitations.map((invitation) => {
                const expiry = getExpiryMeta(invitation.expires_at)
                return (
                  <div key={invitation.id} className="rounded-2xl border bg-card shadow-sm overflow-hidden">
                    <div className="p-6 pb-4">
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <h3 className="text-2xl font-bold tracking-tight leading-tight truncate">
                            {invitation.teamName}
                          </h3>
                          <p className="text-sm text-muted-foreground mt-0.5">
                            {t.invitations.invitationFrom.replace("{name}", invitation.inviterName || "")}
                          </p>
                        </div>
                        <Badge variant="outline" className="capitalize shrink-0 mt-1">
                          {invitation.role}
                        </Badge>
                      </div>

                      <div className="flex flex-wrap items-center gap-4 mt-4 text-sm">
                        <span className="flex items-center gap-1.5 text-muted-foreground">
                          <Mail className="h-3.5 w-3.5 shrink-0" />
                          {invitation.email}
                        </span>
                        <span className={cn("flex items-center gap-1.5", expiry.className)}>
                          <Clock className="h-3.5 w-3.5 shrink-0" />
                          {expiry.isExpired
                            ? t.invitations.expired
                            : t.invitations.expires.replace("{date}", expiry.label)}
                        </span>
                      </div>
                    </div>

                    <div className="px-6 pb-6">
                      {expiry.isExpired ? (
                        <Alert variant="destructive">
                          <AlertCircle className="h-4 w-4" />
                          <AlertDescription className="ml-2">{t.invitations.expired}</AlertDescription>
                        </Alert>
                      ) : (
                        <div className="space-y-2">
                          <Button
                            onClick={() => handleAcceptInvitation(invitation.token, invitation.id)}
                            disabled={acceptingId === invitation.id}
                            className="w-full transition active:scale-[0.98]"
                          >
                            {acceptingId === invitation.id ? (
                              <>
                                <Spinner className="h-4 w-4 mr-2" />
                                {t.invitations.accepting}
                              </>
                            ) : (
                              <>
                                <CheckCircle className="h-4 w-4 mr-2" />
                                {t.invitations.accept}
                              </>
                            )}
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() =>
                              router.push(`/teams/accept-invitation?token=${invitation.token}`)
                            }
                            disabled={acceptingId === invitation.id}
                            className="w-full text-muted-foreground hover:text-foreground"
                          >
                            {t.invitations.view}
                          </Button>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>

            <Button
              variant="outline"
              onClick={() => router.push("/dashboard/teams")}
              className="w-full transition active:scale-[0.98]"
            >
              <ArrowLeft className="h-4 w-4 mr-2" />
              {t.invitations.backToTeams}
            </Button>
          </>
        )}
      </div>
    </div>
  )
}
