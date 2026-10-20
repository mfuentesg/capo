import Foundation

/// Setlist copy. `L10n` has no setlist keys yet; see WP6 notes for why there is no `bundle:`.
enum PlaylistStrings {
  // TODO(i18n)
  static var title: String { String(localized: "ios.playlists.title", defaultValue: "Setlists") }
  // TODO(i18n)
  static var active: String { String(localized: "ios.playlists.active", defaultValue: "Active") }
  // TODO(i18n)
  static var archived: String { String(localized: "ios.playlists.archived", defaultValue: "Archived") }
  // TODO(i18n)
  static var newSetlist: String {
    String(localized: "ios.playlists.new", defaultValue: "New setlist")
  }
  // TODO(i18n)
  static var editDetails: String {
    String(localized: "ios.playlists.editDetails", defaultValue: "Edit details")
  }
  // TODO(i18n)
  static var name: String { String(localized: "ios.playlists.name", defaultValue: "Name") }
  // TODO(i18n)
  static var descriptionLabel: String {
    String(localized: "ios.playlists.description", defaultValue: "Description")
  }
  // TODO(i18n)
  static var hasDate: String { String(localized: "ios.playlists.hasDate", defaultValue: "Set a date") }
  // TODO(i18n)
  static var date: String { String(localized: "ios.playlists.date", defaultValue: "Date") }
  // TODO(i18n)
  static var save: String { String(localized: "ios.playlists.save", defaultValue: "Save") }
  // TODO(i18n)
  static var create: String { String(localized: "ios.playlists.create", defaultValue: "Create") }
  // TODO(i18n)
  static var cancel: String { String(localized: "ios.playlists.cancel", defaultValue: "Cancel") }
  // TODO(i18n)
  static var delete: String { String(localized: "ios.playlists.delete", defaultValue: "Delete") }
  // TODO(i18n)
  static var remove: String { String(localized: "ios.playlists.remove", defaultValue: "Remove") }
  // TODO(i18n)
  static var archive: String { String(localized: "ios.playlists.archive", defaultValue: "Archive") }
  // TODO(i18n)
  static var unarchive: String {
    String(localized: "ios.playlists.unarchive", defaultValue: "Unarchive")
  }
  // TODO(i18n)
  static var pin: String {
    String(localized: "ios.playlists.pin", defaultValue: "Keep available offline")
  }
  // TODO(i18n)
  static var unpin: String { String(localized: "ios.playlists.unpin", defaultValue: "Remove offline copy") }
  // TODO(i18n)
  static var offlineReady: String {
    String(localized: "ios.playlists.offlineReady", defaultValue: "Ready offline")
  }
  // TODO(i18n)
  static var pinned: String { String(localized: "ios.playlists.pinned", defaultValue: "Pinned") }
  // TODO(i18n)
  static var share: String { String(localized: "ios.playlists.share", defaultValue: "Share") }
  // TODO(i18n)
  static var shareOffline: String {
    String(localized: "ios.playlists.shareOffline", defaultValue: "Sharing needs a connection")
  }
  // TODO(i18n)
  static var copyLink: String { String(localized: "ios.playlists.copyLink", defaultValue: "Copy link") }
  // TODO(i18n)
  static var perform: String { String(localized: "ios.playlists.perform", defaultValue: "Perform") }
  // TODO(i18n)
  static var addSongs: String { String(localized: "ios.playlists.addSongs", defaultValue: "Add songs") }
  // TODO(i18n)
  static var reorder: String { String(localized: "ios.playlists.reorder", defaultValue: "Reorder") }
  // TODO(i18n)
  static var done: String { String(localized: "ios.playlists.done", defaultValue: "Done") }
  // TODO(i18n)
  static var close: String { String(localized: "ios.playlists.close", defaultValue: "Close") }
  // TODO(i18n)
  static var emptyTitle: String {
    String(localized: "ios.playlists.emptyTitle", defaultValue: "No setlists yet")
  }
  // TODO(i18n)
  static var emptyMessage: String {
    String(localized: "ios.playlists.emptyMessage", defaultValue: "Create a setlist to plan your next service or gig.")
  }
  // TODO(i18n)
  static var emptyArchived: String {
    String(localized: "ios.playlists.emptyArchived", defaultValue: "No archived setlists")
  }
  // TODO(i18n)
  static var emptySongsTitle: String {
    String(localized: "ios.playlists.emptySongsTitle", defaultValue: "This setlist is empty")
  }
  // TODO(i18n)
  static var emptySongsMessage: String {
    String(localized: "ios.playlists.emptySongsMessage", defaultValue: "Add songs from your library.")
  }
  // TODO(i18n)
  static var notFound: String {
    String(localized: "ios.playlists.notFound", defaultValue: "Setlist not found")
  }
  // TODO(i18n)
  static var chooseSetlist: String {
    String(localized: "ios.playlists.chooseSetlist", defaultValue: "Add to setlist")
  }
  // TODO(i18n)
  static func songCount(_ n: Int) -> String {
    String(localized: "ios.playlists.songCount", defaultValue: "\(n) songs")
  }
  // TODO(i18n)
  static func nextSong(_ title: String) -> String {
    String(localized: "ios.playlists.nextSong", defaultValue: "Next: \(title)")
  }
  // TODO(i18n)
  static func deleteConfirm(_ name: String) -> String {
    String(localized: "ios.playlists.deleteConfirm", defaultValue: "Delete \"\(name)\"? This can't be undone.")
  }
}
