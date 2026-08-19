export * from "./components"

export { NewSongsProvider, useNewSongs } from "./contexts"
export type { NewSongsContextType } from "./contexts"

export { useSongs, useAllSongs, useUpdateSong, useTransferSongToTeam, useDeleteSong } from "./hooks/use-songs"
export { useTags, useCreateTag, useDeleteTag, useSetSongTags } from "./hooks/use-tags"
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
export { getSongsAllBucketsAction, getSongTagsAction, getTagAssignmentsForSongsAction } from "./api/actions"
export type { UserProfileData } from "./api"

export { getBucketColor } from "./utils"

export type {
  Song,
  SongTag,
  SongOwnership,
  UserSongSettings,
  UserPreferences,
  GroupBy,
  SongDetailProps,
  SongListProps,
  BPMRange,
  MusicalKey
} from "./types"
export type { CifraClubParsedSong } from "./types/cifraclub-import.types"
