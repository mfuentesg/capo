export * from "./components"

export { NewSongsProvider, useNewSongs } from "./contexts"
export type { NewSongsContextType } from "./contexts"

export { useSongs, useAllSongs, useUpdateSong, useTransferSongToTeam } from "./hooks/use-songs"
export { useSongRealtime } from "./hooks/use-song-realtime"
export {
  useUserSongSettings,
  useUpsertUserSongSettings,
  useEffectiveSongSettings,
  useAllUserSongSettings
} from "./hooks/use-user-song-settings"
export { useUserPreferences, useUpsertUserPreferences } from "./hooks/use-user-preferences"
export { songsKeys } from "./hooks/query-keys"

export { api, rawApi, getUserProfileData, getUserPreferences, upsertUserPreferences } from "./api"
export type { UserProfileData } from "./api"

export { getBucketColor } from "./utils"

export type {
  Song,
  SongOwnership,
  UserSongSettings,
  UserPreferences,
  GroupBy,
  SongDetailProps,
  SongListProps,
  SongFilterStatus,
  BPMRange,
  MusicalKey
} from "./types"
