"use client"

import {
  Globe,
  Share2,
  CalendarDays,
  Music2,
  GripVertical,
  Settings,
  Copy,
  ExternalLink,
  Link as LinkIcon,
  Turtle,
  Rabbit,
  Zap
} from "lucide-react"
import { toast } from "sonner"
import { useEffect, useState, startTransition } from "react"
import { useMutation } from "@tanstack/react-query"
import { DragDropContext, Droppable, Draggable, type DropResult } from "@hello-pangea/dnd"
import { useLocale } from "@/features/settings"
import { useUser } from "@/features/auth"
import { useTeams } from "@/features/teams"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Switch } from "@/components/ui/switch"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Sheet, SheetContent, SheetTitle } from "@/components/ui/sheet"
import { LyricsView } from "@/features/lyrics-editor"
import { reorderPlaylistSongsAction, updatePlaylistAction } from "@/features/playlists"
import type { PlaylistWithSongs, Playlist } from "@/features/playlists"
import type { Song } from "@/features/songs"
import {
  useAllUserSongSettings,
  useEffectiveSongSettings,
  useUpsertUserSongSettings,
  useUserPreferences,
  useUpdateSong
} from "@/features/songs"
import { TagBadge } from "@/features/songs"
import { usePublicPlaylistRealtime } from "../hooks"
import { formatLongDate } from "@/lib/utils"

interface ActiveSongLyricsForShareProps {
  song: Song
  onClose: () => void
  isAuthenticated: boolean
  canEdit?: boolean
  onSaveLyrics?: (lyrics: string) => void
  isSaving?: boolean
  onPrevSong?: () => void
  onNextSong?: () => void
  hasPrevSong?: boolean
  hasNextSong?: boolean
  songPosition?: { current: number; total: number }
  slideDirection?: "next" | "prev"
}

function ActiveSongLyricsForShare({
  song,
  onClose,
  isAuthenticated,
  canEdit = false,
  onSaveLyrics,
  isSaving,
  onPrevSong,
  onNextSong,
  hasPrevSong,
  hasNextSong,
  songPosition,
  slideDirection
}: ActiveSongLyricsForShareProps) {
  const effectiveSettings = useEffectiveSongSettings(song)
  const { mutate: upsertSettings } = useUpsertUserSongSettings(song)
  const { data: preferences } = useUserPreferences()

  return (
    <LyricsView
      mode="panel"
      readOnly={!canEdit}
      song={{
        ...song,
        lyrics: song.lyrics ?? "",
        fontSize: song.fontSize ?? 1,
        transpose: song.transpose ?? 0,
        capo: song.capo ?? 0
      }}
      onClose={onClose}
      onSaveLyrics={canEdit ? onSaveLyrics : undefined}
      isSaving={isSaving}
      initialSettings={effectiveSettings}
      onSettingsChange={isAuthenticated ? upsertSettings : undefined}
      initialLyricsColumns={preferences?.lyricsColumns ?? 2}
      onPrevSong={onPrevSong}
      onNextSong={onNextSong}
      hasPrevSong={hasPrevSong}
      hasNextSong={hasNextSong}
      songPosition={songPosition}
      slideDirection={slideDirection}
    />
  )
}

interface PlaylistShareViewProps {
  playlist: PlaylistWithSongs
}

export function PlaylistShareView({ playlist }: PlaylistShareViewProps) {
  const { t, locale } = useLocale()
  const { data: user } = useUser()
  const { data: teams = [] } = useTeams()
  // Pre-populate individual song settings caches so the lyrics drawer has warm data on open.
  useAllUserSongSettings()
  const [activeIndex, setActiveIndex] = useState<number | null>(null)
  const [slideDirection, setSlideDirection] = useState<"next" | "prev" | null>(null)
  const [songs, setSongs] = useState<Song[]>(playlist.songs)
  const [localVisibility, setLocalVisibility] = useState(playlist.visibility)
  const [localGuestEditing, setLocalGuestEditing] = useState(playlist.allowGuestEditing ?? false)

  const songsCountLabel = songs.length === 1 ? t.playlistDetail.song : t.playlistDetail.songsPlural

  const reorderMutation = useMutation({
    mutationFn: (updates: Array<{ songId: string; position: number }>) =>
      reorderPlaylistSongsAction(playlist.id, updates, playlist.shareCode)
  })

  const updateMutation = useMutation({
    mutationFn: (updates: Partial<Playlist>) => updatePlaylistAction(playlist.id, updates),
    onError: () => {
      toast.error(t.toasts?.error || "Something went wrong")
    }
  })

  const handleDragEnd = (result: DropResult) => {
    const { destination, source } = result
    if (!destination || destination.index === source.index) return

    const reordered = Array.from(songs)
    const [moved] = reordered.splice(source.index, 1)
    reordered.splice(destination.index, 0, moved)

    setSongs(reordered)
    reorderMutation.mutate(reordered.map((song, position) => ({ songId: song.id, position })))
  }

  useEffect(() => {
    if (activeIndex === null) return

    const scrollY = window.scrollY
    document.body.style.position = "fixed"
    document.body.style.top = `-${scrollY}px`
    document.body.style.width = "100%"

    return () => {
      document.body.style.position = ""
      document.body.style.top = ""
      document.body.style.width = ""
      window.scrollTo(0, scrollY)
    }
  }, [activeIndex])

  // Realtime: subscribe to playlist settings and song order changes
  usePublicPlaylistRealtime(playlist.id, playlist.shareCode ?? "", {
    onSongsChange: setSongs,
    onPlaylistChange: ({ visibility, allowGuestEditing }) => {
      setLocalVisibility(visibility)
      setLocalGuestEditing(allowGuestEditing)
    }
  })

  const activeSong = activeIndex !== null ? songs[activeIndex] : null
  const totalSongs = songs.length

  const { mutate: updateSong, isPending: isSavingLyrics } = useUpdateSong()

  const isOwner = user && playlist.userId === user.id
  const isTeamMember = !!(user && playlist.teamId && teams.some((t) => t.id === playlist.teamId))
  const canEditSongs = !!(isOwner || isTeamMember)

  const handleCloseDrawer = () => startTransition(() => setActiveIndex(null))
  const handlePrevSong = () => {
    if (activeIndex === null || activeIndex === 0) return
    startTransition(() => {
      setSlideDirection("prev")
      setActiveIndex(activeIndex - 1)
    })
  }
  const handleNextSong = () => {
    if (activeIndex === null || activeIndex >= totalSongs - 1) return
    startTransition(() => {
      setSlideDirection("next")
      setActiveIndex(activeIndex + 1)
    })
  }

  const copyShareUrl = async () => {
    if (!playlist.shareCode) return
    const shareUrl = `${window.location.origin}/shared/${playlist.shareCode}`
    try {
      await navigator.clipboard.writeText(shareUrl)
      toast.success(t.playlistDetail.copied)
    } catch {
      toast.error(t.common.copyToClipboardFailed)
    }
  }

  const handleVisibilityChange = (checked: boolean) => {
    const newVisibility = checked ? "public" : "private"
    setLocalVisibility(newVisibility)
    if (!checked && localGuestEditing) {
      setLocalGuestEditing(false)
      updateMutation.mutate({ visibility: newVisibility, allowGuestEditing: false })
    } else {
      updateMutation.mutate({ visibility: newVisibility })
    }
  }

  const handleGuestEditingChange = (checked: boolean) => {
    setLocalGuestEditing(checked)
    updateMutation.mutate({ allowGuestEditing: checked })
  }

  const canReorder = !!user || localGuestEditing

  return (
    <div className="min-h-[calc(100dvh-4rem)] bg-background">
      <main className="mx-auto max-w-2xl px-4 pb-20 pt-8">
        {/* Playlist header */}
        <div className="rounded-2xl border border-border/50 bg-linear-to-br from-accent-playlists/10 via-accent-playlists/5 to-transparent p-7 mb-8">
          {/* Title */}
          <h1 className="text-2xl font-bold tracking-tight leading-snug mb-3">
            {playlist.name}
          </h1>
          {playlist.description && (
            <p className="text-sm text-muted-foreground mb-3">{playlist.description}</p>
          )}

          {/* Badges */}
          <div className="flex flex-wrap items-center gap-2 mb-5">
            <div className="inline-flex items-center gap-1.5 rounded-full border border-accent-playlists/30 bg-accent-playlists/10 px-3 py-1 text-xs font-medium text-accent-playlists">
              <LinkIcon className="h-3 w-3" />
              {t.playlistShare.sharedPlaylist}
            </div>
            {localVisibility === "public" && (
              <Badge variant="secondary" className="gap-1 px-2.5 py-1 text-xs font-normal">
                <Globe className="h-3 w-3" />
                {t.filters.public}
              </Badge>
            )}
            {localGuestEditing && (
              <Badge variant="secondary" className="px-2.5 py-1 text-xs font-normal">
                {t.playlistShare.guestEditing}
              </Badge>
            )}
          </div>

          {/* Bottom row: date on left, actions on right */}
          <div className="flex items-center justify-between gap-3">
            <div>
              {playlist.date && (
                <span className="flex items-center gap-1.5 text-sm text-muted-foreground">
                  <CalendarDays className="h-4 w-4" />
                  {formatLongDate(playlist.date, locale)}
                </span>
              )}
            </div>

            <div className="flex shrink-0 items-center gap-1.5">
              {playlist.shareCode && (
                <Button
                  variant="outline"
                  size="sm"
                  className="gap-1.5 border-accent-playlists/40 text-accent-playlists hover:bg-accent-playlists/10 hover:text-accent-playlists dark:text-white dark:border-white/20 dark:hover:bg-white/10 dark:hover:text-white"
                  onClick={copyShareUrl}
                  aria-label={t.playlistShare.share}
                >
                  <Share2 className="h-3.5 w-3.5" />
                  {t.playlistShare.share}
                </Button>
              )}

              {!!user && (
                <Popover>
                  <PopoverTrigger asChild>
                    <Button variant="ghost" size="icon" className="h-8 w-8">
                      <Settings className="h-4 w-4" />
                    </Button>
                  </PopoverTrigger>
                  <PopoverContent className="w-72" align="end">
                    <h3 className="text-sm font-medium mb-4">{t.playlistDetail.privacySharing}</h3>
                    <div className="space-y-4">
                      {/* Public visibility */}
                      <div className="flex items-center justify-between gap-3">
                        <div className="space-y-0.5">
                          <p className="text-sm font-medium">{t.playlistDetail.publicVisibility}</p>
                          <p className="text-xs text-muted-foreground">
                            <Globe className="h-3 w-3 inline mr-1" />
                            {t.playlistDetail.anyoneWithLink}
                          </p>
                        </div>
                        <Switch
                          checked={localVisibility === "public"}
                          onCheckedChange={handleVisibilityChange}
                        />
                      </div>

                      {/* Share URL */}
                      {localVisibility === "public" && playlist.shareCode && (
                        <div className="space-y-1.5">
                          <p className="text-xs font-medium text-muted-foreground">
                            {t.playlistDetail.publicUrl}
                          </p>
                          <div className="flex items-center gap-1.5">
                            <code className="flex-1 truncate rounded bg-muted px-2 py-1 text-xs font-mono">
                              {playlist.shareCode}
                            </code>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="h-7 w-7 shrink-0"
                              onClick={copyShareUrl}
                            >
                              <Copy className="h-3 w-3" />
                            </Button>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="h-7 w-7 shrink-0"
                              asChild
                            >
                              <a
                                href={`/shared/${playlist.shareCode}`}
                                target="_blank"
                                rel="noopener noreferrer"
                              >
                                <ExternalLink className="h-3 w-3" />
                              </a>
                            </Button>
                          </div>
                        </div>
                      )}

                      {/* Guest editing */}
                      <div className="flex items-center justify-between gap-3">
                        <div className="space-y-0.5">
                          <p className="text-sm font-medium">{t.playlistDetail.guestEditing}</p>
                          <p className="text-xs text-muted-foreground">
                            {localVisibility !== "public"
                              ? t.playlistDetail.guestEditingDisabledHint
                              : t.playlistDetail.guestsCanReorder}
                          </p>
                        </div>
                        <Switch
                          checked={localGuestEditing}
                          disabled={localVisibility !== "public" || updateMutation.isPending}
                          onCheckedChange={handleGuestEditingChange}
                        />
                      </div>
                    </div>
                  </PopoverContent>
                </Popover>
              )}
            </div>
          </div>
        </div>

        {/* Songs list */}
        {songs.length > 0 && (
          <div className="flex items-center gap-2 mb-3 px-1">
            <span className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">
              {songs.length} {songsCountLabel}
            </span>
          </div>
        )}
        {songs.length === 0 ? (
          <div className="flex flex-col items-center gap-3 py-16 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-accent-playlists/10">
              <Music2 className="h-6 w-6 text-accent-playlists" />
            </div>
            <p className="text-sm text-muted-foreground">{t.playlistDetail.noSongsInPlaylist}</p>
          </div>
        ) : canReorder ? (
          <DragDropContext onDragEnd={handleDragEnd}>
            <Droppable droppableId={playlist.id}>
              {(provided, snapshot) => (
                <div
                  {...provided.droppableProps}
                  ref={provided.innerRef}
                  className={`divide-y overflow-hidden rounded-xl border bg-card ${snapshot.isDraggingOver ? "bg-accent/20" : ""}`}
                >
                  {songs.map((song, index) => (
                    <Draggable key={song.id} draggableId={song.id} index={index}>
                      {(provided, snapshot) => (
                        <div
                          ref={provided.innerRef}
                          {...provided.draggableProps}
                          {...provided.dragHandleProps}
                          className={`group flex w-full items-center gap-3 px-4 py-4 text-left transition-colors touch-manipulation cursor-grab active:cursor-grabbing ${snapshot.isDragging ? "bg-card opacity-90 shadow-md" : "hover:bg-muted/50"}`}
                          onClick={() => { setSlideDirection(null); startTransition(() => setActiveIndex(index)) }}
                        >
                          <GripVertical className="h-4 w-4 shrink-0 text-muted-foreground" />
                          <span className="w-5 shrink-0 text-center text-xs tabular-nums text-muted-foreground">
                            {index + 1}
                          </span>
                          <div className="min-w-0 flex-1">
                            <p className="truncate text-base font-medium">{song.title}</p>
                            {song.artist && (
                              <p className="truncate text-sm text-muted-foreground">
                                {song.artist}
                              </p>
                            )}
                            {song.tags && song.tags.length > 0 && (
                              <div className="mt-1 flex flex-wrap gap-1">
                                {song.tags.map((tag) => (
                                  <TagBadge key={tag.id} tag={tag} />
                                ))}
                              </div>
                            )}
                          </div>
                          <div className="flex shrink-0 items-center gap-1.5">
                            {song.key && (
                              <Badge variant="outline" className="h-6 min-w-[24px] px-2 text-xs font-medium">
                                {song.key}
                              </Badge>
                            )}
                            {song.bpm > 0 && (
                              <Badge
                                variant="outline"
                                className="hidden h-6 items-center gap-0.5 px-2 text-xs font-normal sm:flex"
                              >
                                {song.bpm < 90 ? (
                                  <Turtle className="h-3 w-3" />
                                ) : song.bpm <= 120 ? (
                                  <Rabbit className="h-3 w-3" />
                                ) : (
                                  <Zap className="h-3 w-3" />
                                )}
                                {song.bpm}
                              </Badge>
                            )}
                          </div>
                        </div>
                      )}
                    </Draggable>
                  ))}
                  {provided.placeholder}
                </div>
              )}
            </Droppable>
          </DragDropContext>
        ) : (
          <div className="divide-y rounded-xl border bg-card">
            {songs.map((song, index) => (
              <button
                key={song.id}
                type="button"
                className="group flex w-full items-center gap-3 px-4 py-4 text-left transition-colors hover:bg-muted/50 first:rounded-t-xl last:rounded-b-xl active:bg-muted"
                onClick={() => { setSlideDirection(null); startTransition(() => setActiveIndex(index)) }}
                aria-label={`${song.title} ${song.artist}`}
              >
                <span className="w-5 shrink-0 text-center text-xs tabular-nums text-muted-foreground transition-colors group-hover:text-accent-playlists">
                  {index + 1}
                </span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-base font-medium">{song.title}</p>
                  {song.artist && (
                    <p className="truncate text-sm text-muted-foreground">{song.artist}</p>
                  )}
                  {song.tags && song.tags.length > 0 && (
                    <div className="mt-1 flex flex-wrap gap-1">
                      {song.tags.map((tag) => (
                        <TagBadge key={tag.id} tag={tag} />
                      ))}
                    </div>
                  )}
                </div>
                <div className="flex shrink-0 items-center gap-1.5">
                  {song.key && (
                    <Badge variant="outline" className="h-6 min-w-[24px] px-2 text-xs font-medium">
                      {song.key}
                    </Badge>
                  )}
                  {song.bpm > 0 && (
                    <Badge
                      variant="outline"
                      className="hidden h-6 items-center gap-0.5 px-2 text-xs font-normal sm:flex"
                    >
                      {song.bpm < 90 ? (
                        <Turtle className="h-3 w-3" />
                      ) : song.bpm <= 120 ? (
                        <Rabbit className="h-3 w-3" />
                      ) : (
                        <Zap className="h-3 w-3" />
                      )}
                      {song.bpm}
                    </Badge>
                  )}
                </div>
              </button>
            ))}
          </div>
        )}
      </main>

      {/* Lyrics Sheet */}
      <Sheet
        open={activeIndex !== null}
        onOpenChange={(open) => !open && handleCloseDrawer()}
      >
        <SheetContent
          side="top"
          hideClose
          forceMount
          className="h-dvh flex flex-col gap-0 p-0 overflow-hidden rounded-none will-change-transform"
        >
          <SheetTitle className="sr-only">
            {activeSong ? `${activeSong.title} lyrics` : "Song lyrics"}
          </SheetTitle>
          <div className="relative flex h-full flex-col">

            <div className="flex-1 overflow-y-auto overflow-x-hidden">
              {activeSong && (
                <ActiveSongLyricsForShare
                  key={activeSong.id}
                  song={activeSong}
                  onClose={handleCloseDrawer}
                  isAuthenticated={!!user}
                  canEdit={canEditSongs}
                  onSaveLyrics={(lyrics) => {
                    const songId = activeSong.id
                    setSongs((prev) =>
                      prev.map((s) => (s.id === songId ? { ...s, lyrics } : s))
                    )
                    updateSong({ songId, updates: { lyrics } })
                  }}
                  isSaving={isSavingLyrics}
                  onPrevSong={handlePrevSong}
                  onNextSong={handleNextSong}
                  hasPrevSong={activeIndex !== null && activeIndex > 0}
                  hasNextSong={activeIndex !== null && activeIndex < totalSongs - 1}
                  songPosition={
                    activeIndex !== null
                      ? { current: activeIndex + 1, total: totalSongs }
                      : undefined
                  }
                  slideDirection={slideDirection ?? undefined}
                />
              )}
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  )
}
