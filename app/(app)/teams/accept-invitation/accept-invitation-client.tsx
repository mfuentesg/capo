"use client"

import { useEffect, useState } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { useUser } from "@/features/auth"
import { useAcceptTeamInvitation } from "@/features/teams"
import { Spinner } from "@/components/ui/spinner"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { CheckCircle, XCircle, AlertCircle } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"
import { mapInvitationAcceptError } from "@/features/teams"

type InvitationStatus = "loading" | "success" | "error" | "invalid"

const AUTH_ERROR_MESSAGES = ["not authenticated", "different email address", "user email not available"]

function isAuthRelatedError(message: string): boolean {
  const lower = message.toLowerCase()
  return AUTH_ERROR_MESSAGES.some((m) => lower.includes(m))
}

export function AcceptInvitationClient() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const { t } = useTranslation()
  const { data: user, isLoading: userLoading } = useUser()
  const { mutateAsync: acceptInvitation } = useAcceptTeamInvitation()
  const token = searchParams.get("token")
  const [status, setStatus] = useState<InvitationStatus>("loading")
  const [error, setError] = useState<string>("")
  const [isAuthError, setIsAuthError] = useState(false)

  useEffect(() => {
    if (status !== "loading") return

    const doAccept = async () => {
      if (userLoading) return

      if (!token) {
        setStatus("invalid")
        setError(t.invitations.missingToken)
        return
      }

      if (!user) {
        setStatus("error")
        setIsAuthError(true)
        setError(t.invitations.signInRequiredDescription)
        return
      }

      try {
        await acceptInvitation({ token })
        setStatus("success")

        // Redirect to team page after 2 seconds
        setTimeout(() => {
          router.push(`/dashboard/teams`)
        }, 2000)
      } catch (err) {
        const rawMessage = err instanceof Error ? err.message : ""
        setStatus("error")
        setIsAuthError(isAuthRelatedError(rawMessage))
        console.error("Accept invitation error:", err)
        setError(mapInvitationAcceptError(err, t))
      }
    }

    doAccept()
  }, [token, user, userLoading, router, t, acceptInvitation, status])

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-background p-4 relative overflow-hidden">
      {/* Gradient orbs */}
      <div className="pointer-events-none absolute inset-0 -z-10" aria-hidden>
        <div
          className="absolute -top-32 -right-32 h-[500px] w-[500px] rounded-full"
          style={{ background: "radial-gradient(circle, oklch(0.793 0.132 56 / 15%) 0%, transparent 70%)" }}
        />
        <div
          className="absolute -bottom-32 -left-32 h-[500px] w-[500px] rounded-full"
          style={{ background: "radial-gradient(circle, oklch(0.749 0.160 298 / 10%) 0%, transparent 70%)" }}
        />
      </div>

      <div className="w-full max-w-sm space-y-4">
        {/* Status icon above the card */}
        {status === "success" && (
          <div className="flex justify-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-green-500/10 border border-green-500/20">
              <CheckCircle className="h-8 w-8 text-green-500" />
            </div>
          </div>
        )}
        {(status === "error" || status === "invalid") && (
          <div className="flex justify-center">
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10 border border-destructive/20">
              {status === "error" ? (
                <XCircle className="h-8 w-8 text-destructive" />
              ) : (
                <AlertCircle className="h-8 w-8 text-destructive" />
              )}
            </div>
          </div>
        )}

        {/* Card */}
        <div className="rounded-2xl border bg-card shadow-lg p-8 space-y-6">
          {status === "loading" && (
            <div className="flex flex-col items-center text-center space-y-4">
              <Spinner className="h-8 w-8" />
              <div>
                <h1 className="text-xl font-bold tracking-tight">{t.invitations.title}</h1>
                <p className="text-sm text-muted-foreground mt-1">{t.invitations.acceptingDescription}</p>
              </div>
            </div>
          )}

          {status === "success" && (
            <div className="text-center space-y-2">
              <h1 className="text-2xl font-bold tracking-tight">{t.invitations.acceptedTitle}</h1>
              <p className="text-muted-foreground">{t.invitations.welcome}</p>
              <p className="text-sm text-muted-foreground">{t.invitations.redirecting}</p>
            </div>
          )}

          {status === "error" && (
            <div className="space-y-4">
              <div className="text-center">
                <h1 className="text-xl font-bold tracking-tight">{t.invitations.unableToAccept}</h1>
                <p className="text-sm text-muted-foreground mt-1">{error}</p>
              </div>
              <div className="flex flex-col gap-2">
                {isAuthError ? (
                  <Button
                    onClick={() => {
                      if (token) {
                        document.cookie = `_invitation_token=${token}; path=/; max-age=3600; SameSite=Lax`
                      }
                      router.push("/")
                    }}
                    className="w-full transition active:scale-[0.98]"
                  >
                    {t.invitations.signIn}
                  </Button>
                ) : (
                  <Button
                    onClick={() => router.push("/dashboard/teams")}
                    className="w-full transition active:scale-[0.98]"
                  >
                    {t.invitations.goToTeams}
                  </Button>
                )}
                <Button
                  variant="outline"
                  onClick={() => router.push("/dashboard")}
                  className="w-full transition active:scale-[0.98]"
                >
                  {t.invitations.goToDashboard}
                </Button>
              </div>
            </div>
          )}

          {status === "invalid" && (
            <div className="space-y-4">
              <div className="text-center">
                <h1 className="text-xl font-bold tracking-tight">{t.invitations.invalid}</h1>
                <p className="text-sm text-muted-foreground mt-1">{t.invitations.invalidLinkDescription}</p>
              </div>
              <Alert variant="destructive">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription className="ml-2">{t.invitations.invalidLinkTitle}</AlertDescription>
              </Alert>
              <div className="flex flex-col gap-2">
                <Button
                  onClick={() => router.push("/dashboard/teams")}
                  className="w-full transition active:scale-[0.98]"
                >
                  {t.invitations.goToTeams}
                </Button>
                <Button
                  variant="outline"
                  onClick={() => router.push("/dashboard")}
                  className="w-full transition active:scale-[0.98]"
                >
                  {t.invitations.goToDashboard}
                </Button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
