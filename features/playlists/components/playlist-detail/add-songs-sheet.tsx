"use client"

import { useMemo, useState } from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"
import { Search, Music2, Settings2 } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import { Badge } from "@/components/ui/badge"
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover"
import { Separator } from "@/components/ui/separator"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetFooter,
  SheetDescription
} from "@/components/ui/sheet"
import { useAllSongs } from "@/features/songs"
import { addSongsToPlaylistAction } from "../../api/actions"
import { playlistsKeys } from "../../hooks/query-keys"
import { useTranslation } from "@/hooks/use-translation"
import type { BPMRange } from "@/features/songs"
import type { Song } from "@/features/songs"

interface AddSongsSheetProps {
  open: boolean
  onClose: () => void
  playlistId: string
  existingSongIds: string[]
  playlistUserId?: string | null
  playlistTeamId?: string | null
}

export function AddSongsSheet({
  open,
  onClose,
  playlistId,
  existingSongIds,
  playlistUserId,
  playlistTeamId
}: AddSongsSheetProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { data: allSongs = [], isLoading } = useAllSongs()
  const [search, setSearch] = useState("")
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [filterKey, setFilterKey] = useState<string>("all")
  const [filterBpm, setFilterBpm] = useState<BPMRange>("all")

  const existingSet = new Set(existingSongIds)
  // Filter songs to only those matching the playlist's bucket to prevent cross-bucket adds
  const bucketSongs = allSongs.filter((s) => {
    if (!s.ownership) return true // no ownership info, include all (single-context query)
    if (playlistTeamId) {
      return s.ownership.type === "team" && s.ownership.teamId === playlistTeamId
    }
    if (playlistUserId) {
      return s.ownership.type === "personal"
    }
    return true
  })
  const addableSongs = bucketSongs.filter((s) => !existingSet.has(s.id))

  const availableKeys = useMemo(() => {
    const keys = Array.from(new Set(addableSongs.map((s) => s.key).filter(Boolean))).sort()
    return keys
  }, [addableSongs])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return addableSongs.filter((s) => {
      const matchesSearch =
        q.length === 0 ||
        s.title.toLowerCase().includes(q) ||
        s.artist.toLowerCase().includes(q)

      const matchesKey = filterKey === "all" || s.key === filterKey

      const bpm = s.bpm ?? 0
      const matchesBpm =
        filterBpm === "all" ||
        (filterBpm === "slow"
          ? bpm < 100
          : filterBpm === "medium"
            ? bpm >= 100 && bpm <= 140
            : bpm > 140)

      return matchesSearch && matchesKey && matchesBpm
    })
  }, [addableSongs, search, filterKey, filterBpm])

  const activeFilterCount = (filterKey !== "all" ? 1 : 0) + (filterBpm !== "all" ? 1 : 0)

  const addMutation = useMutation({
    mutationFn: (songIds: string[]) => addSongsToPlaylistAction(playlistId, songIds),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: playlistsKeys.lists() })
      queryClient.invalidateQueries({ queryKey: playlistsKeys.detail(playlistId) })
      toast.success(t.toasts.songsAdded)
      setSelectedIds(new Set())
      onClose()
    }
  })

  const toggleSong = (song: Song) => {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(song.id)) {
        next.delete(song.id)
      } else {
        next.add(song.id)
      }
      return next
    })
  }

  const handleAdd = () => {
    if (selectedIds.size === 0) return
    addMutation.mutate(Array.from(selectedIds))
  }

  const handleOpenChange = (nextOpen: boolean) => {
    if (!nextOpen) {
      setSearch("")
      setSelectedIds(new Set())
      setFilterKey("all")
      setFilterBpm("all")
      onClose()
    }
  }

  return (
    <Sheet open={open} onOpenChange={handleOpenChange}>
      <SheetContent side="right" className="flex w-full flex-col sm:max-w-md p-0">
        <SheetHeader className="border-b px-6 py-4">
          <SheetTitle>{t.playlistDetail.addSongsButton}</SheetTitle>
          <SheetDescription className="sr-only">
            {t.playlistDetail.addSongsDescription}
          </SheetDescription>
        </SheetHeader>

        <div className="px-6 py-3 border-b space-y-2">
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder={t.playlistDetail.searchSongs}
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-9"
              />
            </div>
            <Popover>
              <PopoverTrigger asChild>
                <Button variant="outline" size="sm" className="relative shrink-0 gap-2 self-center">
                  <Settings2 className="h-4 w-4" />
                  <span className="hidden sm:inline">{t.songs.filters}</span>
                  {activeFilterCount > 0 && (
                    <Badge variant="default" className="ml-1 h-5 w-5 rounded-full p-0 text-xs">
                      {activeFilterCount}
                    </Badge>
                  )}
                </Button>
              </PopoverTrigger>
              <PopoverContent className="w-72" align="end">
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <h4 className="font-medium leading-none">{t.songs.filters}</h4>
                    {activeFilterCount > 0 && (
                      <Button
                        variant="ghost"
                        size="sm"
                        className="h-7 text-xs"
                        onClick={() => {
                          setFilterKey("all")
                          setFilterBpm("all")
                        }}
                      >
                        {t.filters.clearAll}
                      </Button>
                    )}
                  </div>

                  <Separator />

                  {/* Key filter */}
                  {availableKeys.length > 0 && (
                    <div className="space-y-2">
                      <span className="text-sm font-medium">{t.songs.key}</span>
                      <div className="flex flex-wrap gap-1.5">
                        <Button
                          size="sm"
                          variant={filterKey === "all" ? "default" : "outline"}
                          className="h-7 text-xs px-2"
                          onClick={() => setFilterKey("all")}
                        >
                          {t.songs.all}
                        </Button>
                        {availableKeys.map((key) => (
                          <Button
                            key={key}
                            size="sm"
                            variant={filterKey === key ? "default" : "outline"}
                            className="h-7 text-xs px-2 font-mono"
                            onClick={() => setFilterKey(key)}
                          >
                            {key}
                          </Button>
                        ))}
                      </div>
                    </div>
                  )}

                  {availableKeys.length > 0 && <Separator />}

                  {/* BPM filter */}
                  <div className="space-y-2">
                    <span className="text-sm font-medium">{t.songs.bpmRange}</span>
                    <div className="grid grid-cols-4 gap-1.5">
                      {(["all", "slow", "medium", "fast"] as const).map((range) => (
                        <Button
                          key={range}
                          size="sm"
                          variant={filterBpm === range ? "default" : "outline"}
                          className="h-7 text-xs justify-center"
                          onClick={() => setFilterBpm(range)}
                        >
                          {range === "all"
                            ? t.songs.all
                            : range === "slow"
                              ? t.songs.slow
                              : range === "medium"
                                ? t.songs.medium
                                : t.songs.fast}
                        </Button>
                      ))}
                    </div>
                    <p className="text-xs text-muted-foreground">{t.songs.bpmDescription}</p>
                  </div>
                </div>
              </PopoverContent>
            </Popover>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          {isLoading ? (
            <div className="divide-y">
              {Array.from({ length: 6 }).map((_, i) => (
                <div key={i} className="flex w-full items-center gap-3 px-6 py-3">
                  <Skeleton className="h-5 w-5 shrink-0 rounded" />
                  <div className="min-w-0 flex-1 space-y-2">
                    <Skeleton className="h-4 w-3/4" />
                    <Skeleton className="h-3 w-1/2" />
                  </div>
                  <Skeleton className="h-3 w-8 shrink-0" />
                </div>
              ))}
            </div>
          ) : filtered.length === 0 ? (
            <div className="flex flex-col items-center gap-3 py-16 text-center px-6">
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-muted">
                <Music2 className="h-5 w-5 text-muted-foreground" />
              </div>
              <p className="text-sm text-muted-foreground">
                {addableSongs.length === 0
                  ? t.playlistDetail.noSongsToAdd
                  : t.playlistDetail.noSongsInPlaylist}
              </p>
            </div>
          ) : (
            <div className="divide-y">
              {filtered.map((song) => {
                const isSelected = selectedIds.has(song.id)
                return (
                  <button
                    key={song.id}
                    type="button"
                    className={`flex w-full items-center gap-3 px-6 py-3 text-left transition-colors hover:bg-muted/50 ${isSelected ? "bg-primary/5" : ""}`}
                    onClick={() => toggleSong(song)}
                  >
                    <div
                      className={`flex h-5 w-5 shrink-0 items-center justify-center rounded border transition-colors ${
                        isSelected
                          ? "border-primary bg-primary text-primary-foreground"
                          : "border-muted-foreground/40"
                      }`}
                    >
                      {isSelected && (
                        <svg
                          viewBox="0 0 10 8"
                          className="h-3 w-3 fill-current"
                          aria-hidden="true"
                        >
                          <path
                            d="M1 4l3 3L9 1"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            fill="none"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          />
                        </svg>
                      )}
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium">{song.title}</p>
                      {song.artist && (
                        <p className="truncate text-xs text-muted-foreground">{song.artist}</p>
                      )}
                    </div>
                    {song.key && (
                      <span className="shrink-0 text-xs text-muted-foreground font-mono">
                        {song.key}
                      </span>
                    )}
                  </button>
                )
              })}
            </div>
          )}
        </div>

        <SheetFooter className="border-t px-6 py-4">
          <Button
            className="w-full"
            disabled={selectedIds.size === 0 || addMutation.isPending}
            onClick={handleAdd}
          >
            {selectedIds.size > 0
              ? t.playlistDetail.addSelectedSongs.replace("{count}", String(selectedIds.size))
              : t.playlistDetail.addSongsButton}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
