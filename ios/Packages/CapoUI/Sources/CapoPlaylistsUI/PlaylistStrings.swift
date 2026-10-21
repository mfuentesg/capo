import CapoDesign
import Foundation

/// Setlist copy; thin wrappers over the generated `L10n.Ios.Playlists`.
enum PlaylistStrings {
  static var title: String { L10n.Ios.Playlists.title }
  static var active: String { L10n.Ios.Playlists.active }
  static var archived: String { L10n.Ios.Playlists.archived }
  static var newSetlist: String {
    L10n.Ios.Playlists.new
  }
  static var editDetails: String {
    L10n.Ios.Playlists.editDetails
  }
  static var name: String { L10n.Ios.Playlists.name }
  static var descriptionLabel: String {
    L10n.Ios.Playlists.description
  }
  static var hasDate: String { L10n.Ios.Playlists.hasDate }
  static var date: String { L10n.Ios.Playlists.date }
  static var save: String { L10n.Ios.Playlists.save }
  static var create: String { L10n.Ios.Playlists.create }
  static var cancel: String { L10n.Ios.Playlists.cancel }
  static var delete: String { L10n.Ios.Playlists.delete }
  static var remove: String { L10n.Ios.Playlists.remove }
  static var archive: String { L10n.Ios.Playlists.archive }
  static var unarchive: String {
    L10n.Ios.Playlists.unarchive
  }
  static var pin: String {
    L10n.Ios.Playlists.pin
  }
  static var unpin: String { L10n.Ios.Playlists.unpin }
  static var offlineReady: String {
    L10n.Ios.Playlists.offlineReady
  }
  static var pinned: String { L10n.Ios.Playlists.pinned }
  static var share: String { L10n.Ios.Playlists.share }
  static var shareOffline: String {
    L10n.Ios.Playlists.shareOffline
  }
  static var copyLink: String { L10n.Ios.Playlists.copyLink }
  static var perform: String { L10n.Ios.Playlists.perform }
  static var addSongs: String { L10n.Ios.Playlists.addSongs }
  static var reorder: String { L10n.Ios.Playlists.reorder }
  static var done: String { L10n.Ios.Playlists.done }
  static var close: String { L10n.Ios.Playlists.close }
  static var emptyTitle: String {
    L10n.Ios.Playlists.emptyTitle
  }
  static var emptyMessage: String {
    L10n.Ios.Playlists.emptyMessage
  }
  static var emptyArchived: String {
    L10n.Ios.Playlists.emptyArchived
  }
  static var emptySongsTitle: String {
    L10n.Ios.Playlists.emptySongsTitle
  }
  static var emptySongsMessage: String {
    L10n.Ios.Playlists.emptySongsMessage
  }
  static var notFound: String {
    L10n.Ios.Playlists.notFound
  }
  static var chooseSetlist: String {
    L10n.Ios.Playlists.chooseSetlist
  }
  static func songCount(_ n: Int) -> String {
    L10n.Ios.Playlists.songCount(n: String(n))
  }
  static func nextSong(_ title: String) -> String {
    L10n.Ios.Playlists.nextSong(title: String(title))
  }
  static func deleteConfirm(_ name: String) -> String {
    L10n.Ios.Playlists.deleteConfirm(name: String(name))
  }
}
