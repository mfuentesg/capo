"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Plus, Mail } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"

export function TeamsHeader() {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0">
        <h1 className="text-2xl font-bold tracking-tight sm:text-4xl leading-none">{t.teams.title}</h1>
        <p className="text-sm text-muted-foreground sm:text-base pt-1">{t.teams.manageTeams}</p>
      </div>
      <div className="grid w-full grid-cols-2 gap-2 sm:flex sm:w-auto">
        <Button variant="outline" asChild className="w-full sm:w-auto transition active:scale-[0.98]">
          <Link href="/dashboard/invitations" className="inline-flex w-full items-center justify-center">
            <Mail className="mr-2 h-4 w-4" />
            {t.nav.invitations}
          </Link>
        </Button>
        <Button asChild className="w-full sm:w-auto transition active:scale-[0.98]">
          <Link href="/dashboard/teams/new" className="inline-flex w-full items-center justify-center">
            <Plus className="mr-2 h-4 w-4" />
            {t.teams.createTeam}
          </Link>
        </Button>
      </div>
    </div>
  )
}
