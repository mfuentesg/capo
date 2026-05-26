"use client"

import { useState, useRef, useEffect } from "react"
import Link from "next/link"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { ArrowLeft, Pencil, Check } from "lucide-react"
import { cn, formatDate } from "@/lib/utils"
import { useAppContext } from "@/features/app-context"
import { useTranslation } from "@/hooks/use-translation"
import type { Tables, TablesUpdate } from "@/lib/supabase/database.types"
import { TeamIcon, IconPicker } from "@/components/ui/icon-picker"
import { RoleBadge } from "./role-badge"

interface TeamDetailHeaderProps {
  team: Tables<"teams">
  onUpdate?: (updates: TablesUpdate<"teams">) => void
  isOwner?: boolean
  currentUserRole?: Tables<"team_members">["role"]
}

function EditableField({
  value,
  onSave,
  className,
  inputClassName,
  multiline = false,
  allowEmpty = false,
  label
}: {
  value: string
  onSave: (value: string) => void
  className?: string
  inputClassName?: string
  multiline?: boolean
  allowEmpty?: boolean
  label?: string
}) {
  const [isEditing, setIsEditing] = useState(false)
  const [editValue, setEditValue] = useState(value)
  const inputRef = useRef<HTMLInputElement | HTMLTextAreaElement>(null)

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus()
      if (!multiline) {
        ;(inputRef.current as HTMLInputElement).select()
      }
    }
  }, [isEditing, multiline])

  const handleSave = () => {
    const trimmed = editValue.trim()
    if (trimmed !== value && (trimmed || allowEmpty)) {
      onSave(trimmed)
    } else {
      setEditValue(value)
    }
    setIsEditing(false)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !multiline) {
      handleSave()
    } else if (e.key === "Escape") {
      setEditValue(value)
      setIsEditing(false)
    }
  }

  if (isEditing) {
    return (
      <div className="flex items-start gap-1.5">
        {multiline ? (
          <textarea
            ref={inputRef as React.RefObject<HTMLTextAreaElement>}
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            onKeyDown={handleKeyDown}
            onBlur={handleSave}
            className={cn("min-h-20 px-2 py-1 border rounded resize-none", inputClassName)}
            rows={3}
          />
        ) : (
          <Input
            ref={inputRef as React.RefObject<HTMLInputElement>}
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            onKeyDown={handleKeyDown}
            onBlur={handleSave}
            className={cn("h-8 px-2", inputClassName)}
          />
        )}
        <Button
          size="icon"
          variant="ghost"
          className="h-8 w-8 shrink-0"
          onClick={handleSave}
          aria-label="Save"
        >
          <Check className="h-5 w-5 text-green-600" />
        </Button>
      </div>
    )
  }

  return (
    <button
      onClick={() => setIsEditing(true)}
      className={cn(
        "group inline-flex max-w-full items-center gap-1.5 rounded px-1 -ml-1 hover:bg-muted transition-colors text-left",
        className
      )}
    >
      <span className={multiline ? "whitespace-pre-wrap" : "truncate"}>{value || label}</span>
      <Pencil className="h-3 w-3 opacity-0 group-hover:opacity-50 transition-opacity shrink-0" />
    </button>
  )
}

export function TeamDetailHeader({
  team,
  onUpdate,
  isOwner,
  currentUserRole
}: TeamDetailHeaderProps) {
  const { context } = useAppContext()
  const { t } = useTranslation()
  const [editingIcon, setEditingIcon] = useState(team.icon || "")
  const isCurrentTeam = context?.type === "team" && context.teamId === team.id

  const handleIconChange = (newIcon: string) => {
    setEditingIcon(newIcon)
    if (onUpdate) {
      onUpdate({ icon: newIcon })
    }
  }

  return (
    <div>
      {/* Back button */}
      <Button
        variant="ghost"
        asChild
        aria-label={t.invitations.backToTeams}
        className="mb-4 gap-1.5"
      >
        <Link href="/dashboard/teams">
          <ArrowLeft className="h-4 w-4" />
          {t.invitations.backToTeams}
        </Link>
      </Button>

      {/* Header: icon + info side by side */}
      <div className="flex items-start gap-4">
        {/* Team icon */}
        <div className="relative shrink-0">
          <div className="h-14 w-14 rounded-xl border-2 border-border bg-muted flex items-center justify-center overflow-hidden">
            {isOwner ? (
              <IconPicker
                value={editingIcon}
                onChange={handleIconChange}
                iconClassName="h-7 w-7"
                triggerClassName="h-14 w-14 rounded-xl bg-transparent border-0 hover:bg-foreground/5 p-0"
                idBase={`team-detail-${team.id}-icon-picker`}
              />
            ) : (
              <Avatar className="h-14 w-14 rounded-xl">
                {team.avatar_url && <AvatarImage src={team.avatar_url} alt={team.name} />}
                <AvatarFallback className="rounded-xl bg-transparent">
                  <TeamIcon icon={editingIcon} className="h-7 w-7" />
                </AvatarFallback>
              </Avatar>
            )}
          </div>
          {/* Edit indicator for owners */}
          {isOwner && (
            <div className="absolute -bottom-1.5 -right-1.5 h-5 w-5 rounded-full bg-background border border-border flex items-center justify-center pointer-events-none">
              <Pencil className="h-2.5 w-2.5 text-muted-foreground" />
            </div>
          )}
        </div>

        {/* Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <div className="flex-1 min-w-0">
              {isOwner && onUpdate ? (
                <EditableField
                  value={team.name}
                  onSave={(value) => onUpdate({ name: value })}
                  className="max-w-full text-2xl font-bold tracking-tight leading-none"
                />
              ) : (
                <h1 className="truncate text-2xl font-bold tracking-tight leading-none">{team.name}</h1>
              )}
            </div>
            {/* Active badge — desktop only */}
            {isCurrentTeam && (
              <Badge variant="default" className="shrink-0 gap-1.5 hidden sm:flex">
                <Check className="h-3 w-3" />
                {t.teams.active}
              </Badge>
            )}
          </div>

          <p className="text-xs text-muted-foreground mt-0.5">
            {t.teams.created} {formatDate(team.created_at)}
          </p>

          <div className="flex flex-wrap items-center gap-2 mt-2">
            {currentUserRole && <RoleBadge role={currentUserRole} />}
            {team.is_public && <Badge variant="secondary">{t.filters.public}</Badge>}
            {/* Active badge — mobile only */}
            {isCurrentTeam && (
              <Badge variant="default" className="gap-1.5 sm:hidden">
                <Check className="h-3 w-3" />
                {t.teams.active}
              </Badge>
            )}
          </div>
        </div>
      </div>

    </div>
  )
}
