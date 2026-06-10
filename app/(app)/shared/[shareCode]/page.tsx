import { cache } from "react"
import type { Metadata } from "next"
import { notFound } from "next/navigation"
import { PlaylistShareView } from "@/features/playlist-sharing"
import { api } from "@/features/playlists"

// Deduplicates the fetch between generateMetadata and the page render
const getPlaylistByShareCode = cache((shareCode: string) =>
  api.getPlaylistByShareCode(shareCode)
)

export async function generateMetadata({
  params
}: {
  params: Promise<{ shareCode: string }>
}): Promise<Metadata> {
  const { shareCode } = await params
  const playlist = await getPlaylistByShareCode(shareCode)

  if (!playlist) {
    return { title: "Playlist Not Found" }
  }

  const songCount = playlist.songs.length
  const description =
    playlist.description ?? `${songCount} song${songCount !== 1 ? "s" : ""} — shared on Capo`

  return {
    title: playlist.name,
    description,
    openGraph: {
      title: playlist.name,
      description,
      type: "website"
    },
    twitter: {
      card: "summary",
      title: playlist.name,
      description
    }
  }
}

export default async function SharedPlaylistPage({
  params
}: {
  params: Promise<{ shareCode: string }>
}) {
  const { shareCode } = await params
  const playlist = await getPlaylistByShareCode(shareCode)

  if (!playlist) {
    notFound()
  }

  return <PlaylistShareView playlist={playlist} />
}
