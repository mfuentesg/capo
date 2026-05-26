"use client"

import Link from "next/link"
import { useState } from "react"
import { useRouter } from "next/navigation"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle
} from "@/components/ui/dialog"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Users as UsersIcon, LogOut, Trash2 } from "lucide-react"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { useLeaveTeam, useDeleteTeam, useUpdateTeam } from "@/features/teams"
import { useAppContext } from "@/features/app-context"
import { useUser } from "@/features/auth"
import { useTranslation } from "@/hooks/use-translation"
import type { TeamWithMemberCount } from "@/features/teams"
import { TeamIcon, IconPicker } from "@/components/ui/icon-picker"
import { RoleBadge } from "./role-badge"
import { cn } from "@/lib/utils"

function getRoleAccentStyles(role: string | undefined) {
  switch (role) {
    case "owner":
      return { barStyle: { background: "var(--primary)" }, iconBg: "bg-primary/10 border-primary/20" }
    case "admin":
      return {
        barStyle: { background: "var(--accent-songs)" },
        iconBg: "bg-accent-songs/10 border-accent-songs/20"
      }
    default:
      return {
        barStyle: { background: "var(--accent-activity)" },
        iconBg: "bg-accent-activity/10 border-accent-activity/20"
      }
  }
}

interface TeamCardProps {
  team: TeamWithMemberCount
  memberCount?: number
}

export function TeamCard({ team, memberCount = 1 }: TeamCardProps) {
  const { context, switchToPersonal } = useAppContext()
  const { data: user } = useUser()
  const { t } = useTranslation()
  const router = useRouter()
  const [isLeaveDialogOpen, setIsLeaveDialogOpen] = useState(false)
  const [isDeleteDialogOpen, setIsDeleteDialogOpen] = useState(false)
  const [editingIcon, setEditingIcon] = useState(team.icon || "")

  const onTeamActionSuccess = (teamId: string) => {
    if (context?.type === "team" && context.teamId === teamId) {
      switchToPersonal()
    }
  }

  const leaveTeamMutation = useLeaveTeam({ onSuccess: onTeamActionSuccess })
  const deleteTeamMutation = useDeleteTeam({ onSuccess: onTeamActionSuccess })
  const updateTeamMutation = useUpdateTeam()

  const isCurrentTeam = context?.type === "team" && context.teamId === team.id
  const isOwner = user?.id === team.created_by
  const isOnlyMember = memberCount <= 1
  const roleClasses = getRoleAccentStyles(team.role)

  const handleIconChange = (newIcon: string) => {
    setEditingIcon(newIcon)
    updateTeamMutation.mutate({ teamId: team.id, updates: { icon: newIcon } })
  }

  const handleLeaveOrDelete = () => {
    if (isOwner) {
      if (isOnlyMember) {
        setIsDeleteDialogOpen(true)
      } else {
        router.push(`/dashboard/teams/${team.id}`)
      }
    } else {
      setIsLeaveDialogOpen(true)
    }
  }

  return (
    <>
      <Card
        className={cn(
          "hover:shadow-md transition-shadow overflow-hidden",
          isCurrentTeam ? "border-2 border-primary" : ""
        )}
      >
        {/* Role-colored accent bar — h-1 (4px), rounded top corners only */}
        <div className="h-1 rounded-t-lg" style={roleClasses.barStyle} />

        <CardHeader className="pb-2">
          {/* Row 1: icon + name + Active badge */}
          <div className="flex items-start justify-between gap-2">
            <div className="flex items-center gap-3 flex-1 min-w-0">
              {isOwner ? (
                <div
                  className={cn(
                    "h-9 w-9 rounded-lg border flex items-center justify-center shrink-0",
                    roleClasses.iconBg
                  )}
                >
                  <IconPicker
                    value={editingIcon}
                    onChange={handleIconChange}
                    iconClassName="h-5 w-5"
                    idBase={`team-card-${team.id}-icon-picker`}
                  />
                </div>
              ) : (
                <Avatar className={cn("h-9 w-9 rounded-lg border", roleClasses.iconBg)}>
                  {team.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
                  <AvatarFallback className="rounded-lg bg-transparent">
                    <TeamIcon icon={editingIcon} className="h-5 w-5" />
                  </AvatarFallback>
                </Avatar>
              )}
              <div className="flex-1 min-w-0">
                <Link href={`/dashboard/teams/${team.id}`}>
                  <CardTitle className="text-base font-bold tracking-tight truncate hover:underline cursor-pointer">
                    {team.name}
                  </CardTitle>
                </Link>
              </div>
            </div>
            {isCurrentTeam && (
              <Badge variant="default" className="shrink-0">
                Active
              </Badge>
            )}
          </div>

          {/* Row 2: role badge + public badge */}
          <div className="flex items-center gap-2 mt-1">
            {team.role && <RoleBadge role={team.role} className="text-[10px]" />}
            {team.is_public && (
              <Badge variant="secondary" className="text-xs">
                Public
              </Badge>
            )}
          </div>
        </CardHeader>

        <CardContent className="pt-0">
          <div className="border-t border-border my-2" />
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-1 text-sm text-muted-foreground">
              <UsersIcon className="h-4 w-4" />
              <span>
                {memberCount} {t.teams.members}
              </span>
            </div>
            <div className="flex items-center gap-1">
              <Button
                variant="ghost"
                size="sm"
                onClick={handleLeaveOrDelete}
                className="text-destructive hover:text-destructive hover:bg-destructive/10"
                title={isOwner && isOnlyMember ? t.teams.deleteTeam : t.teams.leaveTeam}
              >
                {isOwner && isOnlyMember ? (
                  <Trash2 className="h-4 w-4" />
                ) : (
                  <LogOut className="h-4 w-4" />
                )}
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Leave Team Dialog (for non-owners) */}
      <Dialog open={isLeaveDialogOpen} onOpenChange={setIsLeaveDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t.teams.leaveTeam}</DialogTitle>
            <DialogDescription>
              {t.teams.leaveTeamConfirm.replace("{name}", team.name)}
            </DialogDescription>
          </DialogHeader>
          <Alert variant="destructive">
            <AlertDescription>{t.teams.leaveTeamWarning}</AlertDescription>
          </Alert>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsLeaveDialogOpen(false)}
              disabled={leaveTeamMutation.isPending}
            >
              {t.common.cancel}
            </Button>
            <Button
              type="button"
              variant="destructive"
              onClick={() =>
                leaveTeamMutation.mutate(team.id, {
                  onSuccess: () => setIsLeaveDialogOpen(false)
                })
              }
              disabled={leaveTeamMutation.isPending}
            >
              {leaveTeamMutation.isPending ? t.teams.leaving : t.teams.leaveTeam}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Team Dialog (for owners with no other members) */}
      <Dialog open={isDeleteDialogOpen} onOpenChange={setIsDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{t.teams.deleteTeamConfirmTitle}</DialogTitle>
            <DialogDescription>
              {t.teams.deleteTeamConfirmDescription.replace("{name}", team.name)}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setIsDeleteDialogOpen(false)}
              disabled={deleteTeamMutation.isPending}
            >
              {t.common.cancel}
            </Button>
            <Button
              type="button"
              variant="destructive"
              onClick={() =>
                deleteTeamMutation.mutate(team.id, {
                  onSuccess: () => setIsDeleteDialogOpen(false)
                })
              }
              disabled={deleteTeamMutation.isPending}
            >
              {t.teams.deleteTeam}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}
