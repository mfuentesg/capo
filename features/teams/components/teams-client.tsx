"use client"

import { useState, useMemo, useEffect } from "react"
import { useSearchParams, useRouter } from "next/navigation"
import { useUser } from "@/features/auth"
import { useAppContext } from "@/features/app-context"
import { TeamsHeader } from "@/features/teams"
import { TeamsSearch } from "@/features/teams"
import { TeamCard } from "@/features/teams"
import { TeamsEmptyState } from "@/features/teams"
import { toast } from "sonner"
import { TeamWithMemberCount } from "@/features/teams"

import { useTeams } from "../hooks/use-teams"
import type { Translations } from "@/lib/i18n/translations"

interface TeamsClientProps {
  initialTeams?: TeamWithMemberCount[]
  t: Translations
}

export function TeamsClient({ initialTeams = [], t }: TeamsClientProps) {
  const { data: user } = useUser()
  const { switchToTeam } = useAppContext()
  const router = useRouter()
  const searchParams = useSearchParams()
  const { data: teams = initialTeams } = useTeams(initialTeams)
  const [searchQuery, setSearchQuery] = useState("")
  const [debouncedSearchQuery, setDebouncedSearchQuery] = useState("")

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearchQuery(searchQuery), 300)
    return () => clearTimeout(timer)
  }, [searchQuery])

  // Handle switching to a team from query parameter
  useEffect(() => {
    const switchToTeamId = searchParams.get("switchToTeamId")
    if (switchToTeamId && user?.id && teams.length > 0) {
      // Check if the team exists in the teams list
      const team = teams.find((t) => t.id === switchToTeamId)
      if (team) {
        switchToTeam(switchToTeamId)
        toast.success(t.toasts.teamSwitched.replace("{name}", team.name))
        // Remove query parameter from URL
        router.replace("/dashboard/teams")
      }
    }
  }, [searchParams, user?.id, teams, switchToTeam, router, t])

  const filteredTeams = useMemo(
    () =>
      teams.filter((team) => team.name.toLowerCase().includes(debouncedSearchQuery.toLowerCase())),
    [teams, debouncedSearchQuery]
  )

  return (
    <div className="relative min-h-screen bg-background overflow-hidden p-4 sm:p-6 lg:p-8">
      <div className="pointer-events-none absolute inset-0 -z-10" aria-hidden>
        <div className="absolute -top-32 -right-32 h-[500px] w-[500px] rounded-full bg-green-500/5 blur-[100px]" />
        <div className="absolute -bottom-32 -left-32 h-[500px] w-[500px] rounded-full bg-primary/5 blur-[100px]" />
      </div>
      <div className="mx-auto max-w-7xl space-y-6">
        <TeamsHeader />
        <TeamsSearch value={searchQuery} onChange={setSearchQuery} />

        {filteredTeams.length > 0 ? (
          <div className="grid gap-4 sm:grid-cols-2">
            {filteredTeams.map((team) => (
              <TeamCard key={team.id} team={team} memberCount={team.member_count} />
            ))}
          </div>
        ) : (
          <TeamsEmptyState searchQuery={searchQuery} />
        )}
      </div>
    </div>
  )
}
