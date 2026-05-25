"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { ArrowLeft } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"
import { CreateTeamForm } from "@/features/teams"

export function CreateTeamClient() {
  const { t } = useTranslation()
  return (
    <div className="min-h-screen bg-background p-4 sm:p-6 lg:p-8">
      <div className="mx-auto max-w-2xl space-y-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="icon" asChild aria-label={t.invitations.backToTeams}>
            <Link href="/dashboard/teams">
              <ArrowLeft className="h-4 w-4" />
            </Link>
          </Button>
          <div>
            <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">
              {t.teams.createNewTeam}
            </h1>
            <p className="text-muted-foreground">{t.teams.createNewTeamDescription}</p>
          </div>
        </div>
        <CreateTeamForm />
      </div>
    </div>
  )
}
