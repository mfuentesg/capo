"use client"

import { useEffect } from "react"
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
import { Music, Mic } from "lucide-react"
import { useTranslation } from "@/hooks/use-translation"
import type { Song } from "@/features/songs/types"

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

  useEffect(() => {
    if (open) {
      form.reset({
        title: song.title,
        artist: song.artist,
        key: song.key,
        bpm: song.bpm ?? 120
      })
    }
  }, [open, song, form])

  const onSubmit = (values: SongEditFormValues) => {
    onUpdate(song.id, values)
    onOpenChange(false)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
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
                      <div className="relative">
                        <Music className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                        <Input placeholder={t.songs.songTitlePlaceholder} {...field} className="pl-9" />
                      </div>
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
                      <div className="relative">
                        <Mic className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                        <Input placeholder={t.songs.artistPlaceholder} {...field} className="pl-9" />
                      </div>
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
            </div>
            <DialogFooter className="mt-4">
              <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
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
