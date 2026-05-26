"use client"

import { useState, useEffect, useMemo, useCallback, startTransition } from "react"
import dynamic from "next/dynamic"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { ResizablePanelGroup, ResizablePanel, ResizableHandle } from "@/components/ui/resizable"
import { Sheet, SheetContent, SheetTitle, SheetDescription } from "@/components/ui/sheet"
import { Skeleton } from "@/components/ui/skeleton"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Separator } from "@/components/ui/separator"
import { Badge } from "@/components/ui/badge"
import { Plus, Search, ListMusic, Settings2, X } from "lucide-react"
import { PlaylistList } from "./playlist-list"
import type { Playlist } from "../types"
import { usePlaylists, useCreatePlaylist, useUpdatePlaylist, useDeletePlaylist } from "../hooks"
import { useUser } from "@/features/auth"
import { useAppContext, type AppContext } from "@/features/app-context"
import { getTranslations } from "@/lib/i18n/translations"
import { createOverlayIds } from "@/lib/ui/stable-overlay-ids"

interface PlaylistsClientProps {
  initialPlaylists?: Playlist[]
  t: ReturnType<typeof getTranslations>
}

function PlaylistDetailSkeleton() {
  return (
    <div className="flex flex-col h-full p-4 gap-4">
      <div className="flex items-center justify-between">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-8 w-8 rounded-md" />
      </div>
      <div className="flex gap-2">
        <Skeleton className="h-6 w-24 rounded-full" />
        <Skeleton className="h-6 w-20 rounded-full" />
      </div>
      <Skeleton className="h-px w-full" />
      <div className="flex flex-col gap-3">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="flex items-center gap-3 p-3 rounded-lg border">
            <Skeleton className="h-9 w-9 rounded-md shrink-0" />
            <div className="flex-1 min-w-0 space-y-1.5">
              <Skeleton className="h-4 w-3/4" />
              <Skeleton className="h-3 w-1/2" />
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

function PlaylistCreateFormSkeleton() {
  return (
    <div className="flex flex-col h-full p-4 gap-4">
      <div className="flex items-center justify-between">
        <Skeleton className="h-7 w-40" />
        <Skeleton className="h-8 w-8 rounded-md" />
      </div>
      <div className="space-y-3">
        <Skeleton className="h-4 w-16" />
        <Skeleton className="h-10 w-full rounded-md" />
      </div>
      <div className="space-y-3">
        <Skeleton className="h-4 w-24" />
        <Skeleton className="h-20 w-full rounded-md" />
      </div>
      <Skeleton className="h-10 w-full rounded-md" />
      <div className="flex gap-2 mt-auto">
        <Skeleton className="h-10 flex-1 rounded-md" />
        <Skeleton className="h-10 flex-1 rounded-md" />
      </div>
    </div>
  )
}

const PlaylistDetailLazy = dynamic(
  () => import("./playlist-detail").then((mod) => mod.PlaylistDetail),
  { ssr: false, loading: () => <PlaylistDetailSkeleton /> }
)

const PlaylistCreateFormLazy = dynamic(
  () => import("./playlist-create-form").then((mod) => mod.PlaylistCreateForm),
  { ssr: false, loading: () => <PlaylistCreateFormSkeleton /> }
)

export function PlaylistsClient({ initialPlaylists = [], t }: PlaylistsClientProps) {
  const { data: playlists = initialPlaylists, isLoading } = usePlaylists(initialPlaylists)
  const { data: user } = useUser()
  const { context } = useAppContext()
  const createPlaylistMutation = useCreatePlaylist()
  const [creationBucket, setCreationBucket] = useState<AppContext | null>(null)
  const updatePlaylistMutation = useUpdatePlaylist()
  const deletePlaylistMutation = useDeletePlaylist()
  const [isMobile, setIsMobile] = useState(false)
  const [searchQuery, setSearchQuery] = useState("")
  const [filterStatus, setFilterStatus] = useState<"all" | "drafts" | "completed">("all")
  const [filterVisibility, setFilterVisibility] = useState<"all" | "public" | "private">("all")
  const [selectedPlaylistId, setSelectedPlaylistId] = useState<string | null>(null)
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState(false)
  const [isCreating, setIsCreating] = useState(false)
  const filterPopoverIds = createOverlayIds("playlists-filter-popover")
  const resizeHandleIds = createOverlayIds("playlists-layout-resize")
  const mobileDrawerIds = createOverlayIds("playlists-mobile-drawer")

  const selectedPlaylist = selectedPlaylistId
    ? (playlists.find((p) => p.id === selectedPlaylistId) ?? null)
    : null

  // Track viewport to render Sheet only after mount and on mobile
  useEffect(() => {
    const mq = window.matchMedia("(max-width: 767px)")
    const update = () => setIsMobile(mq.matches)
    update()
    mq.addEventListener("change", update)
    return () => mq.removeEventListener("change", update)
  }, [])

  // Preload lazy chunks on mobile so first tap is instant
  useEffect(() => {
    if (isMobile) {
      void import("./playlist-detail")
      void import("./playlist-create-form")
    }
  }, [isMobile])

  // Calculate active filter count
  const activeFilterCount = useMemo(() => {
    let count = 0
    if (filterStatus !== "all") count++
    if (filterVisibility !== "all") count++
    return count
  }, [filterStatus, filterVisibility])

  // Clear all filters
  const clearAllFilters = () => {
    setFilterStatus("all")
    setFilterVisibility("all")
  }

  const handleSelectPlaylist = useCallback((playlist: Playlist) => {
    startTransition(() => {
      setIsCreating(false)
      setSelectedPlaylistId(playlist.id)
      setIsMobileDrawerOpen(true)
    })
  }, [])

  const handleClosePlaylistDetail = () => {
    setSelectedPlaylistId(null)
    setIsCreating(false)
    setIsMobileDrawerOpen(false)
  }

  const handleCreateClick = () => {
    startTransition(() => {
      setSelectedPlaylistId(null)
      setIsCreating(true)
      setIsMobileDrawerOpen(true)
      setCreationBucket(context)
    })
  }

  const handleCreateSubmit = async (playlist: Playlist, bucket?: AppContext) => {
    if (!user?.id) return
    const created = await createPlaylistMutation.mutateAsync({
      playlist,
      userId: user.id,
      context: bucket ?? creationBucket ?? undefined
    })
    setIsCreating(false)
    setSelectedPlaylistId(created.id)
  }

  const handleCreateCancel = () => {
    setIsCreating(false)
    setIsMobileDrawerOpen(false)
  }

  return (
    <div className="relative h-[calc(100dvh-4rem)] bg-background overflow-hidden">
      <div className="pointer-events-none absolute inset-0 -z-10" aria-hidden>
        <div className="absolute -top-32 -left-32 h-[400px] w-[400px] rounded-full bg-violet-500/5 blur-[100px]" />
        <div className="absolute bottom-0 -right-32 h-[500px] w-[500px] rounded-full bg-primary/5 blur-[100px]" />
      </div>
      <ResizablePanelGroup id="playlists-layout-group" direction="horizontal" className="h-full">
        <ResizablePanel
          id="playlists-list-panel"
          defaultSize={35}
          minSize={25}
          maxSize={50}
          className="flex flex-col border-r bg-background"
        >
          <div className="border-b border-r p-4 lg:p-6">
            <div className="flex items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-bold tracking-tight lg:text-2xl">
                  {t.playlists.title}
                </h1>
                <span
                  className="text-sm text-muted-foreground tabular-nums"
                  suppressHydrationWarning
                >
                  · {playlists.length}
                </span>
              </div>
              <Button size="sm" className="gap-1.5 rounded-full" onClick={handleCreateClick}>
                <Plus className="h-4 w-4" />
                {t.playlists.createPlaylist}
              </Button>
            </div>

            <div className="relative mt-4 flex items-center gap-2">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                <Input
                  placeholder={`${t.common.search} ${t.playlists.title.toLowerCase()}...`}
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

                    {/* Status Filter */}
                    <div className="space-y-2">
                      <span className="text-sm font-medium">{t.songs.status}</span>
                      <div className="grid grid-cols-3 gap-2">
                        <Button
                          onClick={() => setFilterStatus("all")}
                          variant={filterStatus === "all" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.songs.all}
                        </Button>
                        <Button
                          onClick={() => setFilterStatus("drafts")}
                          variant={filterStatus === "drafts" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.playlists.drafts}
                        </Button>
                        <Button
                          onClick={() => setFilterStatus("completed")}
                          variant={filterStatus === "completed" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.playlists.completed}
                        </Button>
                      </div>
                    </div>

                    <Separator />

                    {/* Visibility Filter */}
                    <div className="space-y-2">
                      <span className="text-sm font-medium">{t.filters.visibility}</span>
                      <div className="grid grid-cols-3 gap-2">
                        <Button
                          onClick={() => setFilterVisibility("all")}
                          variant={filterVisibility === "all" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.songs.all}
                        </Button>
                        <Button
                          onClick={() => setFilterVisibility("public")}
                          variant={filterVisibility === "public" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.filters.public}
                        </Button>
                        <Button
                          onClick={() => setFilterVisibility("private")}
                          variant={filterVisibility === "private" ? "default" : "outline"}
                          size="sm"
                          className="justify-center"
                        >
                          {t.filters.private}
                        </Button>
                      </div>
                    </div>
                  </div>
                </PopoverContent>
              </Popover>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto">
            <PlaylistList
              playlists={playlists}
              searchQuery={searchQuery}
              filterStatus={filterStatus}
              filterVisibility={filterVisibility}
              selectedPlaylistId={selectedPlaylistId}
              isLoading={isLoading && playlists.length === 0}
              onSelectPlaylist={handleSelectPlaylist}
            />
          </div>
        </ResizablePanel>

        <ResizableHandle withHandle className="hidden md:flex" id={resizeHandleIds.handleId} />

        <ResizablePanel
          id="playlists-detail-panel"
          defaultSize={65}
          minSize={40}
          className="hidden md:flex"
        >
          {isCreating ? (
            <PlaylistCreateFormLazy
              onSubmit={handleCreateSubmit}
              onCancel={handleCreateCancel}
              selectedBucket={creationBucket}
              onBucketChange={setCreationBucket}
              autoFocus
            />
          ) : selectedPlaylist ? (
            <PlaylistDetailLazy
              playlist={selectedPlaylist}
              onClose={handleClosePlaylistDetail}
              onUpdate={(playlistId, updates) =>
                updatePlaylistMutation.mutate({ playlistId, updates })
              }
              onDelete={(id) => {
                deletePlaylistMutation.mutate(id)
                handleClosePlaylistDetail()
              }}
            />
          ) : (
            <div className="flex flex-1 flex-col justify-end bg-card relative overflow-hidden p-8 lg:p-12">
              <div className="pointer-events-none select-none absolute inset-0 flex items-center justify-center" aria-hidden>
                <ListMusic style={{ width: "45%", height: "45%" }} className="text-foreground/[0.04]" />
              </div>
              <div className="relative">
                <div className="h-0.5 w-8 rounded-full mb-4" style={{ background: "var(--accent-playlists)" }} />
                <h3 className="text-lg font-bold tracking-tight leading-none">{t.playlists.selectPlaylist}</h3>
                <p className="mt-2 text-sm text-muted-foreground max-w-xs leading-relaxed">
                  {t.playlists.selectPlaylistDescription}
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
            if (!open) handleClosePlaylistDetail()
          }}
        >
          <SheetContent
            side="bottom"
            hideClose
            forceMount
            className="h-dvh flex flex-col gap-0 p-0 overflow-hidden rounded-none will-change-transform"
            id={mobileDrawerIds.contentId}
          >
            <SheetTitle className="sr-only">{t.playlists.playlistDetails}</SheetTitle>
            <SheetDescription className="sr-only">
              {t.playlistDetail.editDescription}
            </SheetDescription>
            <div className="flex-1 overflow-y-auto">
              {isCreating ? (
                <PlaylistCreateFormLazy
                  onSubmit={handleCreateSubmit}
                  onCancel={handleCreateCancel}
                  selectedBucket={creationBucket}
                  onBucketChange={setCreationBucket}
                />
              ) : selectedPlaylist ? (
                <PlaylistDetailLazy
                  playlist={selectedPlaylist}
                  onClose={handleClosePlaylistDetail}
                  onUpdate={(playlistId, updates) =>
                    updatePlaylistMutation.mutate({ playlistId, updates })
                  }
                  onDelete={(id) => {
                    deletePlaylistMutation.mutate(id)
                    handleClosePlaylistDetail()
                  }}
                />
              ) : null}
            </div>
          </SheetContent>
        </Sheet>
      )}
    </div>
  )
}
