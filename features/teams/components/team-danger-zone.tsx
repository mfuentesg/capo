"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import {
  Item,
  ItemActions,
  ItemContent,
  ItemDescription,
  ItemGroup,
  ItemTitle
} from "@/components/ui/item"
import { RoleBadge } from "./role-badge"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/components/ui/select"
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger
} from "@/components/ui/alert-dialog"
import { ArrowLeftRight, LogOut, Trash2 } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"
import type { Tables } from "@/lib/supabase/database.types"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"

type TeamMemberWithName = Tables<"team_members"> & {
  user_full_name: string | null
  user_email: string | null
}

interface OwnerDangerActionsProps {
  teamName: string
  otherMembers: TeamMemberWithName[]
  hasOtherMembers: boolean
  selectedNewOwnerId: string
  onSelectNewOwner: (value: string) => void
  onTransferOwnership: () => void
  onTransferAndLeave: () => void
  onDelete: () => void
  isDeleting?: boolean
  isTransferring?: boolean
  getMemberLabel: (member: TeamMemberWithName) => string
}

function OwnerDangerActions({
  teamName,
  otherMembers,
  hasOtherMembers,
  selectedNewOwnerId,
  onSelectNewOwner,
  onTransferOwnership,
  onTransferAndLeave,
  onDelete,
  isDeleting,
  isTransferring,
  getMemberLabel
}: OwnerDangerActionsProps) {
  const { t } = useTranslation()
  const deleteOnlyDialogIds = createOverlayIds(`team-danger-owner-delete-only-${teamName}`)
  const leaveDialogIds = createOverlayIds(`team-danger-owner-leave-${teamName}`)
  const transferDialogIds = createOverlayIds(`team-danger-owner-transfer-${teamName}`)
  const deleteDialogIds = createOverlayIds(`team-danger-owner-delete-${teamName}`)

  if (!hasOtherMembers) {
    return (
      <Item variant="muted" size="sm">
        <ItemContent>
          <ItemTitle>{t.teams.deleteTeam}</ItemTitle>
          <ItemDescription>{t.teams.deleteTeamDescription}</ItemDescription>
        </ItemContent>
        <ItemActions>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                variant="destructive"
                disabled={isDeleting}
                className="transition active:scale-[0.98]"
                id={deleteOnlyDialogIds.triggerId}
                aria-controls={deleteOnlyDialogIds.contentId}
              >
                <Trash2 className="h-4 w-4 mr-2" />
                {t.common.delete}
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent
              id={deleteOnlyDialogIds.contentId}
            >
              <AlertDialogHeader>
                <AlertDialogTitle>{t.teams.deleteTeamConfirmTitle}</AlertDialogTitle>
                <AlertDialogDescription>
                  {t.teams.deleteTeamConfirmDescription.replace("{name}", teamName)}
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
                <AlertDialogAction variant="destructive" onClick={onDelete}>
                  {t.common.delete}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </ItemActions>
      </Item>
    )
  }

  return (
    <>
      <Item variant="muted" size="sm">
        <ItemContent>
          <ItemTitle>{t.teams.leaveTeam}</ItemTitle>
          <ItemDescription>{t.teams.leaveAsOwner}</ItemDescription>
        </ItemContent>
        <ItemActions>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                variant="destructive"
                disabled={isTransferring}
                className="transition active:scale-[0.98]"
                id={leaveDialogIds.triggerId}
                aria-controls={leaveDialogIds.contentId}
              >
                <LogOut className="h-4 w-4 mr-2" />
                {t.teams.leaveShort}
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent
              id={leaveDialogIds.contentId}
            >
              <AlertDialogHeader>
                <AlertDialogTitle>{t.teams.leaveTeam}</AlertDialogTitle>
                <AlertDialogDescription>
                  {t.teams.transferOwnershipDescription}
                </AlertDialogDescription>
              </AlertDialogHeader>
              <div className="py-4">
                <label className="text-sm font-medium mb-2 block">{t.teams.selectNewOwner}</label>
                <Select value={selectedNewOwnerId} onValueChange={onSelectNewOwner}>
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder={t.teams.selectNewOwner} />
                  </SelectTrigger>
                  <SelectContent>
                    {otherMembers.map((member) => (
                      <SelectItem key={member.user_id} value={member.user_id}>
                        <div className="flex items-center gap-2">
                          <span>{getMemberLabel(member)}</span>
                          {member.role && <RoleBadge role={member.role} className="text-[10px]" />}
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <AlertDialogFooter>
                <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
                <AlertDialogAction
                  variant="destructive"
                  onClick={onTransferAndLeave}
                  disabled={!selectedNewOwnerId || isTransferring}
                >
                  {isTransferring ? t.teams.transferring : t.teams.transferAndLeave}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </ItemActions>
      </Item>
      <Item variant="muted" size="sm">
        <ItemContent>
          <ItemTitle>{t.teams.transferOwnership}</ItemTitle>
          <ItemDescription>{t.teams.transferOwnershipStayDescription}</ItemDescription>
        </ItemContent>
        <ItemActions>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                variant="outline"
                disabled={isTransferring}
                className="transition active:scale-[0.98]"
                id={transferDialogIds.triggerId}
                aria-controls={transferDialogIds.contentId}
              >
                <ArrowLeftRight className="h-4 w-4 mr-2" />
                {t.teams.transferShort}
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent
              id={transferDialogIds.contentId}
            >
              <AlertDialogHeader>
                <AlertDialogTitle>{t.teams.transferOwnership}</AlertDialogTitle>
                <AlertDialogDescription>
                  {t.teams.transferOwnershipStayDescription}
                </AlertDialogDescription>
              </AlertDialogHeader>
              <div className="py-4">
                <label className="text-sm font-medium mb-2 block">{t.teams.selectNewOwner}</label>
                <Select value={selectedNewOwnerId} onValueChange={onSelectNewOwner}>
                  <SelectTrigger className="w-full">
                    <SelectValue placeholder={t.teams.selectNewOwner} />
                  </SelectTrigger>
                  <SelectContent>
                    {otherMembers.map((member) => (
                      <SelectItem key={member.user_id} value={member.user_id}>
                        <div className="flex items-center gap-2">
                          <span>{getMemberLabel(member)}</span>
                          {member.role && <RoleBadge role={member.role} className="text-[10px]" />}
                        </div>
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <AlertDialogFooter>
                <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
                <AlertDialogAction
                  variant="destructive"
                  onClick={onTransferOwnership}
                  disabled={!selectedNewOwnerId || isTransferring}
                >
                  {isTransferring ? t.teams.transferring : t.teams.transferAndStay}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </ItemActions>
      </Item>
      <Item variant="muted" size="sm">
        <ItemContent>
          <ItemTitle>{t.teams.deleteTeam}</ItemTitle>
          <ItemDescription>{t.teams.deleteTeamDescription}</ItemDescription>
        </ItemContent>
        <ItemActions>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button
                variant="destructive"
                disabled={isDeleting}
                className="transition active:scale-[0.98]"
                id={deleteDialogIds.triggerId}
                aria-controls={deleteDialogIds.contentId}
              >
                <Trash2 className="h-4 w-4 mr-2" />
                {t.common.delete}
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent
              id={deleteDialogIds.contentId}
            >
              <AlertDialogHeader>
                <AlertDialogTitle>{t.teams.deleteTeamConfirmTitle}</AlertDialogTitle>
                <AlertDialogDescription>
                  {t.teams.deleteTeamConfirmDescription.replace("{name}", teamName)}
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
                <AlertDialogAction variant="destructive" onClick={onDelete}>
                  {t.common.delete}
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </ItemActions>
      </Item>
    </>
  )
}

interface MemberLeaveActionProps {
  teamName: string
  onLeave: () => void
  isLeaving?: boolean
}

function MemberLeaveAction({ teamName, onLeave, isLeaving }: MemberLeaveActionProps) {
  const { t } = useTranslation()
  const leaveDialogIds = createOverlayIds(`team-danger-member-leave-${teamName}`)

  return (
    <Item variant="muted" size="sm">
      <ItemContent>
        <ItemTitle>{t.teams.leaveTeam}</ItemTitle>
        <ItemDescription>{t.teams.leaveTeamWarning}</ItemDescription>
      </ItemContent>
      <ItemActions>
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button
              variant="destructive"
              disabled={isLeaving}
              className="transition active:scale-[0.98]"
              id={leaveDialogIds.triggerId}
              aria-controls={leaveDialogIds.contentId}
            >
              <LogOut className="h-4 w-4 mr-2" />
              {t.teams.leaveShort}
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent
            id={leaveDialogIds.contentId}
          >
            <AlertDialogHeader>
              <AlertDialogTitle>{t.teams.leaveTeam}</AlertDialogTitle>
              <AlertDialogDescription>
                {t.teams.leaveTeamConfirm.replace("{name}", teamName)}
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>{t.common.cancel}</AlertDialogCancel>
              <AlertDialogAction variant="destructive" onClick={onLeave}>
                {isLeaving ? t.teams.leaving : t.teams.leaveTeam}
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </ItemActions>
    </Item>
  )
}

interface TeamDangerZoneProps {
  teamName: string
  members: TeamMemberWithName[]
  currentUserId: string
  isOwner: boolean
  onLeave: () => void
  onDelete: () => void
  onTransferOwnership: (newOwnerId: string) => void
  onTransferAndLeave: (newOwnerId: string) => void
  isDeleting?: boolean
  isTransferring?: boolean
  isLeaving?: boolean
}

export function TeamDangerZone({
  teamName,
  members,
  currentUserId,
  isOwner,
  onLeave,
  onDelete,
  onTransferOwnership,
  onTransferAndLeave,
  isDeleting,
  isTransferring,
  isLeaving
}: TeamDangerZoneProps) {
  const { t } = useTranslation()
  const [selectedNewOwnerId, setSelectedNewOwnerId] = useState("")

  // Get other members (excluding current user)
  const otherMembers = members.filter((m) => m.user_id !== currentUserId)
  const hasOtherMembers = otherMembers.length > 0

  const handleTransferOwnership = () => {
    if (selectedNewOwnerId) {
      onTransferOwnership(selectedNewOwnerId)
    }
  }

  const handleTransferAndLeave = () => {
    if (selectedNewOwnerId) {
      onTransferAndLeave(selectedNewOwnerId)
    }
  }

  const getMemberLabel = (member: TeamMemberWithName) =>
    member.user_full_name || member.user_email || member.user_id.slice(0, 8)

  return (
    <div className="rounded-2xl border border-destructive/30 bg-destructive/[0.02] p-6">
      <h2 className="text-base font-bold text-destructive mb-4">{t.account.dangerZone}</h2>
      <ItemGroup className="gap-4">
        {isOwner ? (
          <OwnerDangerActions
            teamName={teamName}
            otherMembers={otherMembers}
            hasOtherMembers={hasOtherMembers}
            selectedNewOwnerId={selectedNewOwnerId}
            onSelectNewOwner={setSelectedNewOwnerId}
            onTransferOwnership={handleTransferOwnership}
            onTransferAndLeave={handleTransferAndLeave}
            onDelete={onDelete}
            isDeleting={isDeleting}
            isTransferring={isTransferring}
            getMemberLabel={getMemberLabel}
          />
        ) : (
          <MemberLeaveAction teamName={teamName} onLeave={onLeave} isLeaving={isLeaving} />
        )}
      </ItemGroup>
    </div>
  )
}
