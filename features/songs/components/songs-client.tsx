"use client"

import { useState, useEffect, useMemo, useCallback, startTransition } from "react"
import dynamic from "next/dynamic"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { ResizablePanelGroup, ResizablePanel, ResizableHandle } from "@/components/ui/resizable"
import {
  Sheet,
  SheetContent,
  SheetTitle,
  SheetDescription
} from "@/components/ui/sheet"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Separator } from "@/components/ui/separator"
import { Badge } from "@/components/ui/badge"
import {
  Plus,
  Search,
  Music,
  Music4,
  LayoutList,
  Music2,
  Settings2,
  X,
  Turtle,
  Rabbit,
  Zap
} from "lucide-react"
import { toast } from "sonner"
import { SongList, TagBadge, CifraClubImportDialog } from "@/features/songs"
import { useSongs, useCreateSong } from "../hooks/use-songs"
import { useTags } from "../hooks/use-tags"
import { useUser } from "@/features/auth"
import { useAppContext, type AppContext } from "@/features/app-context"
import type { Song, GroupBy, BPMRange } from "../types"
import type { CifraClubParsedSong } from "../types/cifraclub-import.types"
import type { Translations } from "@/lib/i18n/translations"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"

interface SongsClientProps {
  initialSongs?: Song[]
  t: Translations
}

function SongDetailSkeleton() {
  return (
    <div className="flex flex-1 flex-col bg-muted/30">
      <div className="shrink-0 flex items-center justify-between border-b bg-background p-4 lg:p-6">
        <div className="flex flex-col gap-2 min-w-0">
          <Skeleton className="h-5 w-40" />
          <Skeleton className="h-4 w-28" />
        </div>
        <div className="flex items-center gap-1 shrink-0">
          <Skeleton className="h-8 w-24 rounded-md" />
          <Skeleton className="h-8 w-8 rounded-md" />
        </div>
      </div>
      <div className="flex-1 p-4 lg:p-6 space-y-6">
        <div className="flex gap-3">
          <Skeleton className="h-9 w-24 rounded-full" />
          <Skeleton className="h-9 w-28 rounded-full" />
        </div>
        <div className="space-y-3">
          <Skeleton className="h-4 w-24" />
          <div className="flex items-center gap-3">
            <Skeleton className="h-8 w-10 rounded-md" />
            <Skeleton className="h-10 w-20 rounded-lg" />
            <Skeleton className="h-8 w-10 rounded-md" />
          </div>
        </div>
        <div className="space-y-3">
          <Skeleton className="h-4 w-16" />
          <div className="flex items-center gap-3">
            <Skeleton className="h-8 w-10 rounded-md" />
            <Skeleton className="h-10 w-28 rounded-lg" />
            <Skeleton className="h-8 w-10 rounded-md" />
          </div>
        </div>
        <div className="flex gap-2 pt-4 border-t">
          <Skeleton className="h-8 w-36 rounded-md" />
        </div>
      </div>
    </div>
  )
}

function SongDraftFormSkeleton() {
  return (
    <div className="flex flex-1 flex-col">
      <div className="shrink-0 flex items-center justify-between border-b bg-background p-4 lg:p-6">
        <Skeleton className="h-5 w-32" />
        <Skeleton className="h-8 w-8 rounded-md" />
      </div>
      <div className="flex-1 p-4 lg:p-6 space-y-4">
        <div className="space-y-2">
          <Skeleton className="h-4 w-16" />
          <Skeleton className="h-9 w-full rounded-md" />
        </div>
        <div className="space-y-2">
          <Skeleton className="h-4 w-16" />
          <Skeleton className="h-9 w-full rounded-md" />
        </div>
        <div className="flex gap-3">
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-8" />
            <Skeleton className="h-9 w-full rounded-md" />
          </div>
          <div className="flex-1 space-y-2">
            <Skeleton className="h-4 w-8" />
            <Skeleton className="h-9 w-full rounded-md" />
          </div>
        </div>
        <div className="flex gap-2 pt-2">
          <Skeleton className="h-9 w-24 rounded-md" />
          <Skeleton className="h-9 w-20 rounded-md" />
        </div>
      </div>
    </div>
  )
}

const SongLyricsPanelLazy = dynamic(
  () => import("@/features/songs").then((mod) => mod.SongLyricsPanel),
  { ssr: false, loading: () => <SongDetailSkeleton /> }
)

const SongDraftFormLazy = dynamic(
  () => import("@/features/song-draft").then((mod) => mod.SongDraftForm),
  { ssr: false, loading: () => <SongDraftFormSkeleton /> }
)

export function SongsClient({ initialSongs = [], t }: SongsClientProps) {
  const { data: user } = useUser()
  const { context } = useAppContext()

  const [isMobile, setIsMobile] = useState(false)
  const [searchQuery, setSearchQuery] = useState("")
  const [debouncedQuery, setDebouncedQuery] = useState("")
  const [selectedSong, setSelectedSong] = useState<Song | null>(null)
  const [groupBy, setGroupBy] = useState<GroupBy>("none")
  const [bpmRange, setBpmRange] = useState<BPMRange>("all")
  const [filterTags, setFilterTags] = useState<string[]>([])
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState(false)
  const [isCreatingNewSong, setIsCreatingNewSong] = useState(false)
  const [isCifraImportOpen, setIsCifraImportOpen] = useState(false)
  const [previewSong, setPreviewSong] = useState<Song | null>(null)
  const [creationBucket, setCreationBucket] = useState<AppContext | null>(null)
  const filterPopoverIds = createOverlayIds("songs-filter-popover")
  const resizeHandleIds = createOverlayIds("songs-layout-resize")
  const mobileDrawerIds = createOverlayIds("songs-mobile-drawer")

  const { data: songs = initialSongs, isLoading } = useSongs(debouncedQuery || undefined, initialSongs)
  const { data: availableTags = [] } = useTags()
  const createSongMutation = useCreateSong()

  // Track viewport to render Sheet only after mount and on mobile
  useEffect(() => {
    const mq = window.matchMedia("(max-width: 767px)")
    const update = () => setIsMobile(mq.matches)
    update()
    mq.addEventListener("change", update)
    return () => mq.removeEventListener("change", update)
  }, [])

  // Preload lazy chunks as soon as mobile is detected so they are ready
  // before the first tap — prevents chunk-load during the open animation
  useEffect(() => {
    if (isMobile) {
      void import("@/features/songs")
      void import("@/features/song-draft")
    }
  }, [isMobile])

  // Keep selectedSong in sync with the React Query cache so mutations
  // (e.g. tag updates) are reflected in the detail panel without a reload.
  useEffect(() => {
    if (isCreatingNewSong) return
    setSelectedSong((prev) => {
      if (!prev) return prev
      const updated = songs.find((s) => s.id === prev.id)
      return updated ?? prev
    })
  }, [songs, isCreatingNewSong])

  // Debounce search query before sending to server
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedQuery(searchQuery)
    }, 300)
    return () => clearTimeout(timer)
  }, [searchQuery])

  const handleDeleteSong = useCallback(() => {
    setSelectedSong(null)
    setIsMobileDrawerOpen(false)
  }, [])

  const handleTransferSuccess = useCallback(() => {
    setSelectedSong(null)
    setIsMobileDrawerOpen(false)
  }, [])

  const handleSelectSong = useCallback(
    (song: Song) => {
      if (isCreatingNewSong) return
      startTransition(() => {
        setSelectedSong(song)
        setIsMobileDrawerOpen(true)
      })
    },
    [isCreatingNewSong]
  )

  const handleCloseSongDetail = useCallback(() => {
    setSelectedSong(null)
    setIsMobileDrawerOpen(false)
    setIsCreatingNewSong(false)
    setPreviewSong(null)
  }, [])

  const handleCreateNewSong = () => {
    const previewId = crypto.randomUUID()
    const newPreview: Song = {
      id: previewId,
      title: "",
      artist: "",
      key: "",
      bpm: 0
    }
    setPreviewSong(newPreview)
    setSelectedSong(newPreview)
    setIsCreatingNewSong(true)
    setIsMobileDrawerOpen(true)
    setCreationBucket(context)
  }

  const handleUpdatePreview = (updates: Partial<Song>) => {
    if (previewSong) {
      setPreviewSong((prev) => (prev ? { ...prev, ...updates } : null))
      setSelectedSong((prev) => (prev ? { ...prev, ...updates } : null))
    }
  }

  const handleCifraClubImported = (imported: CifraClubParsedSong) => {
    const previewId = crypto.randomUUID()
    const newPreview: Song = {
      id: previewId,
      title: imported.title,
      artist: imported.artist,
      key: imported.key,
      bpm: 0,
      lyrics: imported.lyrics
    }
    setPreviewSong(newPreview)
    setSelectedSong(newPreview)
    setIsCreatingNewSong(true)
    setIsMobileDrawerOpen(true)
    setCreationBucket(context)
    toast.success(t.toasts.cifraImportSuccess)
  }

  const handleSaveSong = async (song: Song) => {
    if (!user?.id) {
      return // User not authenticated
    }
    // SongDraftForm's buildSong() only carries title/artist/key/bpm — merge
    // back in any lyrics seeded by a CifraClub import before persisting.
    const songToSave = previewSong?.lyrics ? { ...song, lyrics: previewSong.lyrics } : song
    try {
      const savedSong = await createSongMutation.mutateAsync({
        song: songToSave,
        userId: user.id,
        context: creationBucket ?? undefined
      })
      setIsCreatingNewSong(false)
      setPreviewSong(null)
      setSelectedSong(savedSong)
      // Keep drawer open on mobile to show the new song detail
      setIsMobileDrawerOpen(true)
    } catch {
      // Error is handled by the mutation's onError callback (toast)
      // Keep the form open so user can retry
    }
  }

  // Calculate active filter count
  const activeFilterCount = useMemo(() => {
    let count = 0
    if (groupBy !== "none") count++
    if (bpmRange !== "all") count++
    count += filterTags.length
    return count
  }, [groupBy, bpmRange, filterTags])

  // Clear all filters
  const clearAllFilters = () => {
    setGroupBy("none")
    setBpmRange("all")
    setFilterTags([])
  }

  return (
    <div className="relative h-[calc(100dvh-4rem)] bg-background overflow-hidden">
      <div className="pointer-events-none absolute inset-0 -z-10" aria-hidden>
        <div className="absolute -top-32 -right-32 h-[400px] w-[400px] rounded-full bg-primary/5 blur-[100px]" />
        <div className="absolute bottom-0 -left-32 h-[500px] w-[500px] rounded-full bg-blue-500/5 blur-[100px]" />
      </div>
      <ResizablePanelGroup id="songs-layout-group" direction="horizontal" className="h-full">
        <ResizablePanel
          id="songs-list-panel"
          defaultSize={35}
          minSize={25}
          maxSize={50}
          className="flex flex-col border-r bg-background"
        >
          <div className="border-b border-r p-4 lg:p-6">
            <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4">
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold tracking-tight lg:text-2xl">
                  {t.songs.title}
                </h1>
                <span className="text-sm text-muted-foreground tabular-nums">· {songs.length}</span>
              </div>
              <div className="flex items-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  className="flex-1 gap-1.5 rounded-full sm:flex-initial"
                  onClick={() => setIsCifraImportOpen(true)}
                  disabled={isCreatingNewSong}
                >
                  <Music4 className="h-4 w-4" />
                  <span className="truncate">{t.songs.cifraImport.button}</span>
                </Button>
                <Button
                  size="sm"
                  className="flex-1 gap-1.5 rounded-full sm:flex-initial"
                  onClick={handleCreateNewSong}
                  disabled={isCreatingNewSong}
                >
                  <Plus className="h-4 w-4" />
                  {t.songs.addSong}
                </Button>
              </div>
            </div>

            <div className="relative mt-4 flex items-center gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                <Input
                  placeholder={t.songs.searchPlaceholder}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className={`pl-9 h-9 bg-muted/50 ${searchQuery ? "pr-9" : "pr-3"}`}
                  suppressHydrationWarning
                />
                {searchQuery && (
                  <button
                    onClick={() => setSearchQuery("")}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                  >
                    <X className="h-4 w-4" />
                  </button>
                )}
              </div>

              <Popover>
                <PopoverTrigger asChild>
                  <Button
                    variant="outline"
                    size="sm"
                    className="relative gap-2 shrink-0"
                    id={filterPopoverIds.triggerId}
                    aria-controls={filterPopoverIds.contentId}
                  >
                    <Settings2 className="h-4 w-4" />
                    <span className="hidden sm:inline">{t.songs.filters}</span>
                    {activeFilterCount > 0 && (
                      <Badge variant="default" className="ml-1 h-5 w-5 rounded-full p-0 text-xs">
                        {activeFilterCount}
                      </Badge>
                    )}
                  </Button>
                </PopoverTrigger>

                <PopoverContent
                  className="w-80 max-h-125 overflow-y-auto"
                  align="end"
                  id={filterPopoverIds.contentId}
                  aria-labelledby={filterPopoverIds.triggerId}
                >
                  <div className="space-y-4">
                    <div className="flex items-center justify-between">
                      <div className="space-y-1">
                        <h4 className="font-medium leading-none">{t.songs.filters}</h4>
                        <p className="text-xs text-muted-foreground">
                          {t.songs.filtersDescription}
                        </p>
                      </div>
                      {activeFilterCount > 0 && (
                        <Button
                          variant="ghost"
                          size="sm"
                          className="h-7 text-xs"
                          onClick={clearAllFilters}
                        >
                          {t.filters.clearAll}
                        </Button>
                      )}
                    </div>

                    <Separator />

                    {/* BPM Range Filter */}
                    <div className="space-y-2">
                      <div className="flex items-center gap-2">
                        <Music2 className="h-4 w-4" />
                        <span className="text-sm font-medium">{t.songs.bpmRange}</span>
                      </div>
                      <div className="grid grid-cols-4 gap-2">
                        <Button
                          onClick={() => setBpmRange("all")}
                          variant={bpmRange === "all" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.songs.all}
                        </Button>
                        <Button
                          onClick={() => setBpmRange("slow")}
                          variant={bpmRange === "slow" ? "default" : "outline"}
                          size="sm"
                          className="justify-center gap-1.5"
                        >
                          <Turtle className="h-3.5 w-3.5" />
                          {t.songs.slow}
                        </Button>
                        <Button
                          onClick={() => setBpmRange("medium")}
                          variant={bpmRange === "medium" ? "default" : "outline"}
                          size="sm"
                          className="justify-center gap-1.5"
                        >
                          <Rabbit className="h-3.5 w-3.5" />
                          {t.songs.medium}
                        </Button>
                        <Button
                          onClick={() => setBpmRange("fast")}
                          variant={bpmRange === "fast" ? "default" : "outline"}
                          size="sm"
                          className="justify-center gap-1.5"
                        >
                          <Zap className="h-3.5 w-3.5" />
                          {t.songs.fast}
                        </Button>
                      </div>
                      <p className="text-xs text-muted-foreground">{t.songs.bpmDescription}</p>
                    </div>

                    <Separator />

                    {/* Group By */}
                    <div className="space-y-2">
                      <div className="flex items-center gap-2">
                        <LayoutList className="h-4 w-4" />
                        <span className="text-sm font-medium">{t.songs.groupBy}</span>
                      </div>
                      <div className="grid grid-cols-3 gap-2">
                        <Button
                          onClick={() => setGroupBy("none")}
                          variant={groupBy === "none" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.songs.none}
                        </Button>
                        <Button
                          onClick={() => setGroupBy("key")}
                          variant={groupBy === "key" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.songs.byKey}
                        </Button>
                        <Button
                          onClick={() => setGroupBy("artist")}
                          variant={groupBy === "artist" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.songs.byArtist}
                        </Button>
                      </div>
                    </div>

                    {availableTags.length > 0 && (
                      <>
                        <Separator />
                        <div className="space-y-2">
                          <span className="text-sm font-medium">{t.songs.tags.title}</span>
                          <div className="flex flex-wrap gap-1.5">
                            {availableTags.map((tag) => (
                              <button
                                key={tag.id}
                                onClick={() =>
                                  setFilterTags((prev) =>
                                    prev.includes(tag.id)
                                      ? prev.filter((id) => id !== tag.id)
                                      : [...prev, tag.id]
                                  )
                                }
                                className="focus:outline-none"
                              >
                                <TagBadge
                                  tag={tag}
                                  className={filterTags.includes(tag.id) ? "ring-2 ring-ring ring-offset-1" : ""}
                                />
                              </button>
                            ))}
                          </div>
                        </div>
                      </>
                    )}
                  </div>
                </PopoverContent>
              </Popover>
            </div>

          </div>

          <div className="flex-1 overflow-y-auto">
            <SongList
              songs={songs}
              previewSong={previewSong}
              selectedSong={selectedSong}
              groupBy={groupBy}
              bpmRange={bpmRange}
              filterTags={filterTags}
              isCreatingNewSong={isCreatingNewSong}
              isLoading={isLoading && songs.length === 0}
              onSelectSong={handleSelectSong}
            />
          </div>
        </ResizablePanel>

        <ResizableHandle withHandle className="hidden md:flex" id={resizeHandleIds.handleId} />

        <ResizablePanel
          id="songs-detail-panel"
          defaultSize={65}
          minSize={40}
          className="hidden md:flex"
        >
          {isCreatingNewSong ? (
            <div className="flex-1 overflow-y-auto min-h-0">
              <SongDraftFormLazy
                song={previewSong || undefined}
                onClose={() => {
                  setIsCreatingNewSong(false)
                  setPreviewSong(null)
                  setSelectedSong(null)
                }}
                onSave={handleSaveSong}
                onChange={handleUpdatePreview}
                selectedBucket={creationBucket}
                onBucketChange={setCreationBucket}
                autoFocus
              />
            </div>
          ) : selectedSong ? (
            <div className="flex-1 overflow-y-auto min-h-0">
              <SongLyricsPanelLazy
                key={selectedSong.id}
                song={selectedSong}
                onClose={handleCloseSongDetail}
                onDelete={handleDeleteSong}
                onTransferSuccess={handleTransferSuccess}
              />
            </div>
          ) : (
            <div className="flex flex-1 flex-col justify-end bg-card relative overflow-hidden p-8 lg:p-12">
              <div className="pointer-events-none select-none absolute inset-0 flex items-center justify-center" aria-hidden>
                <Music style={{ width: "45%", height: "45%" }} className="text-foreground/[0.04]" />
              </div>
              <div className="relative">
                <div className="h-0.5 w-8 rounded-full mb-4" style={{ background: "var(--accent-songs)" }} />
                <h3 className="text-lg font-bold tracking-tight leading-none">{t.songs.selectSong}</h3>
                <p className="mt-2 text-sm text-muted-foreground max-w-xs leading-relaxed">
                  {t.songs.selectSongDescription}
                </p>
              </div>
            </div>
          )}
        </ResizablePanel>
      </ResizablePanelGroup>

      {isMobile && (
        <Sheet
          open={isMobileDrawerOpen}
          onOpenChange={(open) => {
            if (!open) handleCloseSongDetail()
          }}
        >
          <SheetContent
            side="bottom"
            hideClose
            forceMount
            className="h-dvh flex flex-col gap-0 p-0 overflow-hidden rounded-none will-change-transform"
            id={mobileDrawerIds.contentId}
          >
            <SheetTitle className="sr-only">
              {isCreatingNewSong ? t.songs.createSong : t.songs.songDetails}
            </SheetTitle>
            <SheetDescription className="sr-only">
              {isCreatingNewSong ? t.songs.enterSongDetails : t.songs.selectSongDescription}
            </SheetDescription>
            <div className="flex-1 overflow-y-auto">
              {isCreatingNewSong ? (
                <SongDraftFormLazy
                  song={previewSong || undefined}
                  onClose={handleCloseSongDetail}
                  onSave={handleSaveSong}
                  onChange={handleUpdatePreview}
                  selectedBucket={creationBucket}
                  onBucketChange={setCreationBucket}
                />
              ) : selectedSong ? (
                <SongLyricsPanelLazy
                  key={selectedSong.id}
                  song={selectedSong}
                  onClose={handleCloseSongDetail}
                  onDelete={handleDeleteSong}
                  onTransferSuccess={handleTransferSuccess}
                />
              ) : null}
            </div>
          </SheetContent>
        </Sheet>
      )}

      <CifraClubImportDialog
        mode="create"
        open={isCifraImportOpen}
        onOpenChange={setIsCifraImportOpen}
        onImported={handleCifraClubImported}
      />
    </div>
  )
}
