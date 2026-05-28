"use client"

import { useCallback, useEffect } from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { KeySelect } from "@/features/songs"
import { Alert, AlertDescription } from "@/components/ui/alert"
import { X, Info, Music, Mic } from "lucide-react"
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from "@/components/ui/form"
import type { Song } from "@/types"
import type { AppContext } from "@/features/app-context"
import { BucketSelector, useAppContext } from "@/features/app-context"
import { useTranslation } from "@/hooks/use-translation"

type SongFormValues = {
  title: string
  artist: string
  key: string
  bpm: number
}

interface SongDraftFormProps {
  song?: Song
  onClose: () => void
  onSave: (song: Song) => void | Promise<void>
  onChange?: (updates: Partial<Song>) => void
  autoFocus?: boolean
  selectedBucket?: AppContext | null
  onBucketChange?: (ctx: AppContext) => void
}

export function SongDraftForm({
  song,
  onClose,
  onSave,
  onChange,
  autoFocus = false,
  selectedBucket,
  onBucketChange
}: SongDraftFormProps) {
  const { t } = useTranslation()
  const { teams, context } = useAppContext()
  const userId = context?.userId ?? ""

  const songFormSchema = z.object({
    title: z
      .string()
      .min(1, t.validation.required.replace("{field}", t.validation.songTitle))
      .trim(),
    artist: z
      .string()
      .min(1, t.validation.required.replace("{field}", t.validation.artistName))
      .trim(),
    key: z.string().min(1, t.validation.required.replace("{field}", t.validation.key)),
    bpm: z
      .number()
      .int()
      .min(40, t.validation.minBpm.replace("{min}", "40"))
      .max(300, t.validation.maxBpm.replace("{max}", "300"))
  })

  const form = useForm<SongFormValues>({
    resolver: zodResolver(songFormSchema),
    defaultValues: {
      title: song?.title || "",
      artist: song?.artist || "",
      key: song?.key || "",
      bpm: song?.bpm || 120
    }
  })

  const {
    formState: { isValid, isSubmitting }
  } = form

  // Notify parent of field changes for live preview
  useEffect(() => {
    const subscription = form.watch((value) => {
      if (onChange) {
        onChange({
          title: value.title || "",
          artist: value.artist || "",
          key: value.key || "",
          bpm: value.bpm || 0
        })
      }
    })
    return () => subscription.unsubscribe()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [onChange])

  const buildSong = useCallback(
    (values: SongFormValues): Song => ({
      id: song?.id?.startsWith("preview-") ? crypto.randomUUID() : song?.id || crypto.randomUUID(),
      title: values.title,
      artist: values.artist,
      key: values.key,
      bpm: values.bpm
    }),
    [song?.id]
  )

  const onSubmit = useCallback(
    async (values: SongFormValues) => {
      await onSave(buildSong(values))
    },
    [onSave, buildSong]
  )

  return (
    <div className="h-full flex flex-col bg-background overflow-hidden">
      {/* Header */}
      <div className="border-b p-4 md:p-6 flex items-center justify-between shrink-0">
        <div>
          <h2 className="text-lg font-semibold">{t.songs.createSong}</h2>
          <p className="text-sm text-muted-foreground mt-1">{t.songs.enterSongDetails}</p>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <button
            onClick={onClose}
            className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground transition-colors"
            aria-label={t.common.close}
          >
            <X className="h-5 w-5" />
          </button>
        </div>
      </div>

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex-1 flex flex-col">
          <div className="flex-1 overflow-y-auto p-4 md:p-6">
            <div className="space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="title"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>{t.songs.songTitle}</FormLabel>
                      <FormControl>
                        <div className="relative">
                          <Music className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                          <Input
                            placeholder={t.songs.songTitlePlaceholder}
                            {...field}
                            className="pl-9 shadow-none"
                            autoFocus={autoFocus}
                          />
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
                          <Input
                            placeholder={t.songs.artistPlaceholder}
                            {...field}
                            className="pl-9 shadow-none"
                          />
                        </div>
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="key"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>{t.songs.key}</FormLabel>
                      <FormControl>
                        <KeySelect
                          value={field.value}
                          onValueChange={field.onChange}
                          placeholder={t.songs.selectKey}
                        />
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
                          placeholder="120"
                          value={field.value || ""}
                          onChange={(e) => {
                            const num = parseInt(e.target.value, 10)
                            field.onChange(isNaN(num) ? 0 : num)
                          }}
                          onBlur={field.onBlur}
                          name={field.name}
                          ref={field.ref}
                          min="40"
                          max="300"
                          className="shadow-none"
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              {onBucketChange !== undefined && (
                <BucketSelector
                  value={selectedBucket ?? context}
                  onChange={onBucketChange}
                  userId={userId}
                  teams={teams}
                  label={t.songs.bucket}
                />
              )}

              <Alert>
                <Info />
                <AlertDescription>{t.songs.songSettingsInfo}</AlertDescription>
              </Alert>
            </div>
          </div>

          {/* Footer - Action buttons */}
          <div className="border-t p-4 md:p-6 flex gap-3 justify-end shrink-0 bg-background">
            <Button type="button" variant="outline" onClick={onClose}>
              {t.common.cancel}
            </Button>
            <Button type="submit" disabled={!isValid || isSubmitting}>
              {isSubmitting ? t.common.saving : t.common.submit}
            </Button>
          </div>
        </form>
      </Form>
    </div>
  )
}
