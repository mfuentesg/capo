import type { Song } from "@/features/songs"

export interface Playlist {
  id: string
  userId?: string | null
  teamId?: string | null
  name: string
  description?: string
  date?: string
  songs: string[] // Array of song IDs
  createdAt: string
  updatedAt: string
  visibility?: "private" | "public"
  allowGuestEditing?: boolean
  shareCode?: string
  archivedAt?: string
}

export interface PlaylistWithSongs extends Omit<Playlist, "songs"> {
  songs: Song[]
}

export interface PlaylistDetailProps {
  playlist: Playlist
  onClose: () => void
  onUpdate: (playlistId: string, updates: Partial<Playlist>) => void
}

export interface PlaylistListProps {
  playlists: Playlist[]
  selectedPlaylistId?: string | null
  searchQuery: string
  onSelectPlaylist: (playlist: Playlist) => void
}
