"use client"

import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Plus } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"

interface TeamsEmptyStateProps {
  searchQuery: string
}

export function TeamsEmptyState({ searchQuery }: TeamsEmptyStateProps) {
  const { t } = useTranslation()
  return (
    <Card>
      <CardContent className="p-8">
        <div className="h-0.5 w-8 rounded-full mb-4 bg-muted-foreground/30" />
        <h3 className="font-bold tracking-tight text-lg leading-none mb-2">{t.teams.noTeamsFound}</h3>
        <p className="text-sm text-muted-foreground mb-4 max-w-sm">
          {searchQuery ? t.common.tryDifferentSearch : t.teams.createNewTeamDescription}
        </p>
        {!searchQuery && (
          <Button asChild>
            <Link href="/dashboard/teams/new">
              <Plus className="mr-2 h-4 w-4" />
              {t.teams.createTeam}
            </Link>
          </Button>
        )}
      </CardContent>
    </Card>
  )
}
