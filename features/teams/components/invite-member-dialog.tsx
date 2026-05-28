"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogFooter
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/components/ui/select"
import { Spinner } from "@/components/ui/spinner"
import { Mail, Users } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"
import { useInviteTeamMember } from "../hooks"
import type { Tables } from "@/lib/supabase/database.types"

interface InviteMemberDialogProps {
  teamId: string
  isOpen: boolean
  onOpenChange: (open: boolean) => void
  availableRoles: Tables<"team_invitations">["role"][]
}

export function InviteMemberDialog({
  teamId,
  isOpen,
  onOpenChange,
  availableRoles
}: InviteMemberDialogProps) {
  const { t } = useTranslation()
  const [email, setEmail] = useState("")
  const [role, setRole] = useState<Tables<"team_invitations">["role"]>("member")
  const inviteTeamMember = useInviteTeamMember()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!email.trim()) return

    inviteTeamMember.mutate(
      { teamId, email, role },
      {
        onSuccess: () => {
          setEmail("")
          setRole("member")
          onOpenChange(false)
        }
      }
    )
  }

  return (
    <Dialog open={isOpen} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t.teams.inviteMember}</DialogTitle>
          <DialogDescription>
            {t.teams.sendInvitationTo}{" "}
            <span className="font-semibold">{t.teams.newTeamMember}</span>
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="email">{t.common.email}</Label>
            <div className="relative">
              <Mail className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                id="email"
                type="email"
                placeholder={t.common.emailPlaceholder}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={inviteTeamMember.isPending}
                required
                className="pl-9"
              />
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="role">{t.common.role}</Label>
            <div className="relative">
              <Users className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground z-10" />
              <Select
                value={role}
                onValueChange={(value) => setRole(value as Tables<"team_invitations">["role"])}
              >
              <SelectTrigger id="role" className="pl-9 w-full">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {availableRoles.includes("member") && (
                  <SelectItem value="member">{t.teams.roleMember}</SelectItem>
                )}
                {availableRoles.includes("admin") && (
                  <SelectItem value="admin">{t.teams.roleAdmin}</SelectItem>
                )}
                {availableRoles.includes("viewer") && (
                  <SelectItem value="viewer">{t.teams.roleViewer}</SelectItem>
                )}
              </SelectContent>
            </Select>
            </div>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={inviteTeamMember.isPending}
            >
              {t.common.cancel}
            </Button>
            <Button type="submit" disabled={inviteTeamMember.isPending}>
              {inviteTeamMember.isPending && <Spinner className="h-4 w-4 mr-2" />}
              {t.teams.sendInvitation}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
