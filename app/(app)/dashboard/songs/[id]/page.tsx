import type { Metadata } from "next"
import { api as songsApi, getUserProfileData as getUserProfileDataApi, getSongTagsAction } from "@/features/songs"
import { createClient } from "@/lib/supabase/server"
import { notFound } from "next/navigation"
import { LyricsPageClient } from "./lyrics-page-client"

export async function generateMetadata({
  params
}: {
  params: Promise<{ id: string }>
}): Promise<Metadata> {
  const { id } = await params
  const song = await songsApi.getSong(id)

  if (!song) {
    return { title: "Song Not Found", robots: { index: false, follow: false } }
  }

  return {
    title: `${song.title} — ${song.artist}`,
    robots: { index: false, follow: false }
  }
}

export default async function SongLyricsPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()

  // 1. Get user first (verified, secure)
  const {
    data: { user: authUser }
  } = await supabase.auth.getUser()

  // 2. Fetch song, profile data, and tags in parallel
  const [song, profileData, songTags] = await Promise.all([
    songsApi.getSong(id),
    authUser ? getUserProfileDataApi(supabase, authUser.id).catch(() => null) : Promise.resolve(null),
    getSongTagsAction(id).catch(() => [])
  ])

  if (!song) {
    notFound()
  }

  const initialUserSettings = profileData?.songSettings.find((s) => s.songId === id) ?? null

  return (
    <LyricsPageClient
      song={{ ...song, tags: songTags }}
      initialUserSettings={initialUserSettings}
      initialLyricsColumns={profileData?.preferences.lyricsColumns ?? 2}
    />
  )
}
