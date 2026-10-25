/// Server limits for playlists (`playlistSchema` in `features/playlists/api/actions.ts`).
enum PlaylistLimits {
  static let name = 200
  static let description = 2000
}
