"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import {
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemGroup,
  ItemMedia,
  ItemTitle
} from "@/components/ui/item"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle
} from "@/components/ui/alert-dialog"
import {
  Users as UsersIcon,
  UserPlus,
  MoreVertical,
  CircleUserRound,
  Trash2,
  Shield,
  ChevronDown,
  Mail,
  Clock,
  Copy,
  RefreshCw
} from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"
import { InviteMemberDialog } from "./invite-member-dialog"
import {
  useRemoveTeamMember,
  useChangeTeamMemberRole,
  useCancelTeamInvitation,
  useResendTeamInvitation
} from "../hooks"
import {
  getAvailableRolesForTarget,
  ROLE_HIERARCHY,
  ROLE_ICONS,
  ROLE_LABELS,
  ROLE_PERMISSIONS
} from "../constants"
import { RoleBadge } from "./role-badge"
import type { Tables } from "@/lib/supabase/database.types"
import { cn, formatDate } from "@/lib/utils"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"
import { toast } from "sonner"

interface TeamMembersSectionProps {
  members: (Tables<"team_members"> & {
    user_full_name: string | null
    user_email: string | null
    user_avatar_url: string | null
  })[]
  invitations: Tables<"team_invitations">[]
  teamId: string
  currentUserId?: string
  currentUserRole?: Tables<"team_members">["role"]
}

export function TeamMembersSection({
  members,
  invitations,
  teamId,
  currentUserId,
  currentUserRole = "viewer"
}: TeamMembersSectionProps) {
  const { t } = useTranslation()
  const [isInviteDialogOpen, setIsInviteDialogOpen] = useState(false)
  const [memberToRemove, setMemberToRemove] = useState<(typeof members)[0] | null>(null)
  const [invitationToCancel, setInvitationToCancel] = useState<Tables<"team_invitations"> | null>(
    null
  )
  const [roleChangeInProgress, setRoleChangeInProgress] = useState<string | null>(null)
  const removeTeamMember = useRemoveTeamMember()
  const changeTeamMemberRole = useChangeTeamMemberRole()
  const cancelTeamInvitation = useCancelTeamInvitation()
  const resendTeamInvitation = useResendTeamInvitation()

  const handleRemoveMember = () => {
    if (!memberToRemove) return
    removeTeamMember.mutate(
      { teamId, userId: memberToRemove.user_id },
      {
        onSuccess: () => {
          setMemberToRemove(null)
        }
      }
    )
  }

  const handleChangeRole = (userId: string, newRole: Tables<"team_members">["role"]) => {
    setRoleChangeInProgress(userId)
    changeTeamMemberRole.mutate(
      { teamId, userId, newRole },
      {
        onSettled: () => {
          setRoleChangeInProgress(null)
        }
      }
    )
  }

  const handleCancelInvitation = () => {
    if (!invitationToCancel) return
    cancelTeamInvitation.mutate(
      { invitationId: invitationToCancel.id, teamId },
      {
        onSuccess: () => {
          setInvitationToCancel(null)
        }
      }
    )
  }

  const canManageTeamMembers = () => {
    return ROLE_PERMISSIONS[currentUserRole]?.canInvite
  }

  const canManageMember = (member: (typeof members)[0]) => {
    // Cannot manage yourself or the owner
    if (member.user_id === currentUserId || member.role === "owner") {
      return false
    }
    if (currentUserRole === "admin" && member.role === "admin") {
      return false
    }
    return currentUserRole === "owner" || currentUserRole === "admin"
  }

  const getAvailableRoles = (member: (typeof members)[0]) => {
    return getAvailableRolesForTarget(currentUserRole, member.role)
  }

  const getRoleButtonLabel = (member: (typeof members)[0]) => {
    const availableRoles = getAvailableRoles(member)
    const isOnlyDowngrade = availableRoles.every(
      (role) => ROLE_HIERARCHY[role] < ROLE_HIERARCHY[member.role]
    )
    return isOnlyDowngrade ? "Downgrade" : t.teams.changeRole
  }

  const handleCopyInvitationLink = (token: string) => {
    const url = `${window.location.origin}/teams/accept-invitation?token=${token}`
    navigator.clipboard.writeText(url).then(() => {
      toast.success(t.teams.invitationLinkCopied)
    })
  }

  const isExpired = (invitation: Tables<"team_invitations">) =>
    invitation.expires_at < new Date().toISOString()

  const pendingInvitations = invitations.filter((inv) => !isExpired(inv))
  const expiredInvitations = invitations.filter((inv) => isExpired(inv))

  const totalCount = (members?.length || 0) + (pendingInvitations?.length || 0)

  return (
    <>
      <div className="rounded-2xl border bg-card p-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center gap-2">
            <UsersIcon className="h-5 w-5" />
            <h2 className="text-base font-bold tracking-tight">{t.teams.members}</h2>
            <Badge variant="secondary">{totalCount}</Badge>
          </div>
          {canManageTeamMembers() && (
            <Button onClick={() => setIsInviteDialogOpen(true)} className="transition active:scale-[0.98]">
              <UserPlus className="h-4 w-4 sm:mr-2" />
              <span className="hidden sm:inline">{t.teams.addMember}</span>
            </Button>
          )}
        </div>

        {members.length > 0 || invitations.length > 0 ? (
          <ItemGroup className="gap-2">
            {members.map((member) => {
              const availableRoles = getAvailableRoles(member)
              const roleMenuIds = createOverlayIds(`team-member-role-${member.user_id}`)

              const isCurrentUser = member.user_id === currentUserId

              return (
                <Item
                  key={member.id}
                  variant="outline"
                  size="sm"
                  className={cn(
                    "hover:bg-muted/50",
                    isCurrentUser && "border-primary/40 bg-primary/5 rounded-md"
                  )}
                >
                  <ItemMedia>
                    <Avatar className="h-8 w-8">
                      {member.user_avatar_url && (
                        <AvatarImage
                          src={member.user_avatar_url}
                          alt={member.user_full_name || "Team member"}
                        />
                      )}
                      <AvatarFallback className="bg-primary/10">
                        <CircleUserRound className="h-4 w-4 text-muted-foreground" />
                      </AvatarFallback>
                    </Avatar>
                  </ItemMedia>
                  <ItemContent>
                    <ItemTitle>
                      {member.user_full_name || `User ${member.user_id.slice(0, 8)}`}
                      {isCurrentUser && " (you)"}
                    </ItemTitle>
                    <ItemDescription>Joined {formatDate(member.joined_at)}</ItemDescription>
                  </ItemContent>
                  <ItemActions>
                    <RoleBadge role={member.role} />
                    {canManageMember(member) && availableRoles.length > 0 && (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button
                            variant="outline"
                            size="sm"
                            disabled={roleChangeInProgress === member.user_id}
                            id={roleMenuIds.triggerId}
                            aria-controls={roleMenuIds.contentId}
                          >
                            <Shield className="h-4 w-4 mr-2" />
                            {getRoleButtonLabel(member)}
                            <ChevronDown className="h-3 w-3 ml-2" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent
                          align="end"
                          className="w-64"
                          id={roleMenuIds.contentId}
                          aria-labelledby={roleMenuIds.triggerId}
                        >
                          <DropdownMenuLabel>{t.teams.changeRole}</DropdownMenuLabel>
                          <DropdownMenuSeparator />
                          {availableRoles.map((role) => {
                            const RoleIcon = ROLE_ICONS[role]

                            return (
                              <DropdownMenuItem
                                key={role}
                                onClick={() => handleChangeRole(member.user_id, role)}
                                disabled={roleChangeInProgress === member.user_id}
                              >
                                <RoleIcon className="h-4 w-4 mr-2" />
                                {ROLE_LABELS[role]}
                              </DropdownMenuItem>
                            )
                          })}
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            onClick={() => setMemberToRemove(member)}
                            className="text-destructive focus:text-destructive"
                          >
                            <Trash2 className="h-4 w-4 mr-2" />
                            {t.teams.removeMember}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    )}
                    {canManageMember(member) && availableRoles.length === 0 && (
                      <Button
                        variant="ghost"
                        size="icon"
                        disabled
                        aria-label={t.common.memberOptions}
                      >
                        <MoreVertical className="h-4 w-4" />
                      </Button>
                    )}
                  </ItemActions>
                </Item>
              )
            })}
            {pendingInvitations.length > 0 && (
              <div className="pt-4">
                <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground mb-2">
                  <Mail className="h-4 w-4" />
                  <span>{t.teams.pendingInvitations}</span>
                  <Badge variant="outline">{pendingInvitations.length}</Badge>
                </div>
                <ItemGroup className="gap-2">
                  {pendingInvitations.map((invitation) => (
                    <Item
                      key={invitation.id}
                      variant="outline"
                      size="sm"
                      className="bg-muted/40 items-start gap-3 sm:items-center"
                    >
                      <ItemMedia>
                        <Avatar className="h-8 w-8">
                          <AvatarFallback className="bg-primary/10">
                            <Mail className="h-4 w-4 text-muted-foreground" />
                          </AvatarFallback>
                        </Avatar>
                      </ItemMedia>
                      <ItemContent className="min-w-0">
                        <ItemTitle className="w-full truncate">{invitation.email}</ItemTitle>
                        <ItemDescription className="flex items-center gap-1 text-xs sm:text-sm">
                          <Clock className="h-3 w-3" />
                          {t.teams.invitedOn.replace("{date}", formatDate(invitation.created_at))}
                        </ItemDescription>
                      </ItemContent>
                      <ItemActions className="mt-2 w-full justify-between sm:mt-0 sm:w-auto sm:justify-end">
                        <div className="flex items-center gap-2">
                          <RoleBadge role={invitation.role} />
                          <Badge variant="secondary" className="inline-flex">
                            {t.teams.invitationPending}
                          </Badge>
                        </div>
                        <div className="flex items-center gap-2">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleCopyInvitationLink(invitation.token)}
                            aria-label={t.teams.copyInvitationLink}
                            className="h-9 w-9 px-0 sm:h-9 sm:w-auto sm:px-3"
                          >
                            <Copy className="h-4 w-4 sm:mr-2" />
                            <span className="hidden sm:inline">{t.teams.copyInvitationLink}</span>
                          </Button>
                          {canManageTeamMembers() && (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => setInvitationToCancel(invitation)}
                              disabled={cancelTeamInvitation.isPending}
                              aria-label={t.teams.cancelInvitation}
                              className="h-9 w-9 px-0 sm:h-9 sm:w-auto sm:px-3"
                            >
                              <Trash2 className="h-4 w-4 sm:mr-2" />
                              <span className="hidden sm:inline">{t.teams.cancelInvitation}</span>
                            </Button>
                          )}
                        </div>
                      </ItemActions>
                    </Item>
                  ))}
                </ItemGroup>
              </div>
            )}
            {expiredInvitations.length > 0 && (
              <div className="pt-4">
                <div className="flex items-center gap-2 text-sm font-medium text-muted-foreground mb-2">
                  <Clock className="h-4 w-4" />
                  <span>{t.teams.expiredInvitations}</span>
                  <Badge variant="outline">{expiredInvitations.length}</Badge>
                </div>
                <ItemGroup className="gap-2">
                  {expiredInvitations.map((invitation) => (
                    <Item
                      key={invitation.id}
                      variant="outline"
                      size="sm"
                      className="bg-muted/20 items-start gap-3 sm:items-center opacity-75"
                    >
                      <ItemMedia>
                        <Avatar className="h-8 w-8">
                          <AvatarFallback className="bg-muted">
                            <Mail className="h-4 w-4 text-muted-foreground" />
                          </AvatarFallback>
                        </Avatar>
                      </ItemMedia>
                      <ItemContent className="min-w-0">
                        <ItemTitle className="w-full truncate">{invitation.email}</ItemTitle>
                        <ItemDescription className="flex items-center gap-1 text-xs sm:text-sm">
                          <Clock className="h-3 w-3" />
                          {t.teams.invitedOn.replace("{date}", formatDate(invitation.created_at))}
                        </ItemDescription>
                      </ItemContent>
                      <ItemActions className="mt-2 w-full justify-between sm:mt-0 sm:w-auto sm:justify-end">
                        <div className="flex items-center gap-2">
                          <RoleBadge role={invitation.role} />
                          <Badge variant="destructive" className="inline-flex">
                            {t.teams.invitationExpired}
                          </Badge>
                        </div>
                        {canManageTeamMembers() && (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() =>
                              resendTeamInvitation.mutate({
                                invitationId: invitation.id,
                                teamId,
                                email: invitation.email,
                                role: invitation.role
                              })
                            }
                            disabled={resendTeamInvitation.isPending}
                            aria-label={t.teams.resendInvitation}
                            className="h-9 w-9 px-0 sm:h-9 sm:w-auto sm:px-3"
                          >
                            <RefreshCw className="h-4 w-4 sm:mr-2" />
                            <span className="hidden sm:inline">{t.teams.resendInvitation}</span>
                          </Button>
                        )}
                      </ItemActions>
                    </Item>
                  ))}
                </ItemGroup>
              </div>
            )}
          </ItemGroup>
        ) : (
          <div className="py-8 px-2">
            <div className="h-0.5 w-8 rounded-full mb-4 bg-muted-foreground/30" />
            <p className="font-bold tracking-tight text-lg leading-none text-muted-foreground">{t.teams.noMembersYet}</p>
          </div>
        )}
      </div>

      <InviteMemberDialog
        teamId={teamId}
        isOpen={isInviteDialogOpen}
        onOpenChange={setIsInviteDialogOpen}
        availableRoles={ROLE_PERMISSIONS[currentUserRole]?.canAssignRoles || []}
      />

      <AlertDialog
        open={!!memberToRemove}
        onOpenChange={(open: boolean) => !open && setMemberToRemove(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t.teams.removeMember}</AlertDialogTitle>
            <AlertDialogDescription>
              {memberToRemove &&
                t.teams.removeMemberConfirm.replace(
                  "{name}",
                  memberToRemove.user_full_name || `User ${memberToRemove.user_id.slice(0, 8)}`
                )}
              <br />
              <br />
              {t.teams.removeMemberWarning}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={removeTeamMember.isPending}>
              {t.common.cancel}
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleRemoveMember}
              disabled={removeTeamMember.isPending}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {removeTeamMember.isPending ? t.common.loading : t.teams.removeMember}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <AlertDialog
        open={!!invitationToCancel}
        onOpenChange={(open: boolean) => !open && setInvitationToCancel(null)}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{t.teams.cancelInvitation}</AlertDialogTitle>
            <AlertDialogDescription>
              {invitationToCancel &&
                t.teams.cancelInvitationConfirm.replace("{email}", invitationToCancel.email)}
              <br />
              <br />
              {t.teams.cancelInvitationWarning}
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel disabled={cancelTeamInvitation.isPending}>
              {t.common.cancel}
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleCancelInvitation}
              disabled={cancelTeamInvitation.isPending}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {cancelTeamInvitation.isPending ? t.common.loading : t.teams.cancelInvitation}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  )
}
