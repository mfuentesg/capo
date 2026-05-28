"use client"

import { useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter
} from "@/components/ui/dialog"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from "@/components/ui/form"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { KeySelect } from "@/features/songs/components/key-select"
import { TagSelector } from "@/features/songs/components/tag-selector"
import { useTranslation } from "@/hooks/use-translation"
import { Tag } from "lucide-react"
import type { Song, SongTag } from "@/features/songs/types"
import { useTags, useCreateTag, useDeleteTag, useSetSongTags } from "@/features/songs/hooks/use-tags"
import { songsKeys } from "@/features/songs/hooks/query-keys"
import type { Song as SongFull } from "@/types"

type SongEditFormValues = {
  title: string
  artist: string
  key: string
  bpm: number
}

interface SongEditDialogProps {
  song: Song
  open: boolean
  onOpenChange: (open: boolean) => void
  onUpdate: (songId: string, updates: Partial<Song>) => void
}

export function SongEditDialog({ song, open, onOpenChange, onUpdate }: SongEditDialogProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { data: availableTags = [] } = useTags()
  const { mutateAsync: createTag } = useCreateTag()
  const { mutate: deleteTag } = useDeleteTag()
  const { mutate: setSongTags } = useSetSongTags(song.id)
  const [localTags, setLocalTags] = useState<SongTag[]>(song.tags ?? [])

  const schema = z.object({
    title: z
      .string()
      .min(1, t.validation.required.replace("{field}", t.validation.songTitle))
      .trim(),
    artist: z.string().trim(),
    key: z.string().min(1, t.validation.required.replace("{field}", t.validation.key)),
    bpm: z
      .number()
      .int()
      .min(40, t.validation.minBpm.replace("{min}", "40"))
      .max(300, t.validation.maxBpm.replace("{max}", "300"))
  })

  const form = useForm<SongEditFormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      title: song.title,
      artist: song.artist,
      key: song.key,
      bpm: song.bpm ?? 120
    }
  })

  const handleOpenChange = (next: boolean) => {
    if (next) {
      // Read latest song data from cache — prop may lag behind
      // if tags were changed via the panel TagSelector before opening.
      let latestTags = song.tags ?? []
      const cached = queryClient.getQueriesData<SongFull[]>({ queryKey: songsKeys.lists() })
      for (const [, data] of cached) {
        if (!Array.isArray(data)) continue
        const found = data.find((s) => s.id === song.id)
        if (found?.tags) { latestTags = found.tags; break }
      }
      form.reset({
        title: song.title,
        artist: song.artist,
        key: song.key,
        bpm: song.bpm ?? 120
      })
      setLocalTags(latestTags)
    }
    onOpenChange(next)
  }

  const onSubmit = (values: SongEditFormValues) => {
    onUpdate(song.id, values)
    setSongTags({ tagIds: localTags.map((t) => t.id), tags: localTags })
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t.songs.editDetails}</DialogTitle>
        </DialogHeader>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)}>
            <div className="space-y-4 py-2">
              <FormField
                control={form.control}
                name="title"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t.songs.songTitle}</FormLabel>
                    <FormControl>
                      <Input placeholder={t.songs.songTitlePlaceholder} {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="artist"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>{t.songs.artist}</FormLabel>
                    <FormControl>
                      <Input placeholder={t.songs.artistPlaceholder} {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <div className="grid grid-cols-2 gap-3">
                <FormField
                  control={form.control}
                  name="key"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>{t.songs.key}</FormLabel>
                      <FormControl>
                        <KeySelect value={field.value} onValueChange={field.onChange} className="w-full" />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={form.control}
                  name="bpm"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>{t.songs.bpm}</FormLabel>
                      <FormControl>
                        <Input
                          type="number"
                          inputMode="numeric"
                          min="40"
                          max="300"
                          value={field.value || ""}
                          onChange={(e) => {
                            const num = parseInt(e.target.value, 10)
                            field.onChange(isNaN(num) ? 0 : num)
                          }}
                          onBlur={field.onBlur}
                          name={field.name}
                          ref={field.ref}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              <div className="space-y-1.5">
                <span className="flex items-center gap-1.5 text-sm font-medium">
                  <Tag className="h-3.5 w-3.5" />
                  {t.songs.tags.title}
                </span>
                <TagSelector
                  selectedTags={localTags}
                  availableTags={availableTags}
                  onTagsChange={setLocalTags}
                  onCreateTag={(name, color) => createTag({ name, color })}
                  onDeleteTag={(tagId) => deleteTag(tagId)}
                />
              </div>
            </div>
            <DialogFooter className="mt-4">
              <Button type="button" variant="outline" onClick={() => handleOpenChange(false)}>
                {t.common.cancel}
              </Button>
              <Button type="submit" disabled={form.formState.isSubmitting}>
                {t.common.save}
              </Button>
            </DialogFooter>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  )
}
