import CapoDesign
import Foundation

/// Library copy. `L10n` has no library keys yet, so each string is declared once here with its
/// English default; WP12 harvests the `ios.library.*` keys in Wave 3.
/// No `bundle:` argument: CapoLibraryUI has no resources, so there is no `Bundle.module`.
enum LibraryStrings {
  // TODO(i18n)
  static var title: String { String(localized: "ios.library.title", defaultValue: "Library") }
  // TODO(i18n)
  static var searchPrompt: String {
    String(localized: "ios.library.searchPrompt", defaultValue: "Search title, artist, lyrics")
  }
  // TODO(i18n)
  static var pickerTitle: String {
    String(localized: "ios.library.pickerTitle", defaultValue: "Add songs")
  }
  // TODO(i18n)
  static var filters: String { String(localized: "ios.library.filters", defaultValue: "Filters") }
  // TODO(i18n)
  static var sort: String { String(localized: "ios.library.sort", defaultValue: "Sort") }
  // TODO(i18n)
  static var status: String { String(localized: "ios.library.status", defaultValue: "Status") }
  // TODO(i18n)
  static var tempo: String { String(localized: "ios.library.tempo", defaultValue: "Tempo") }
  // TODO(i18n)
  static var resetFilters: String {
    String(localized: "ios.library.resetFilters", defaultValue: "Reset filters")
  }
  // TODO(i18n)
  static var manageTags: String {
    String(localized: "ios.library.manageTags", defaultValue: "Manage tags")
  }
  // TODO(i18n)
  static var tags: String { String(localized: "ios.library.tags", defaultValue: "Tags") }
  // TODO(i18n)
  static var assignTags: String {
    String(localized: "ios.library.assignTags", defaultValue: "Assign tags")
  }
  // TODO(i18n)
  static var newSong: String { String(localized: "ios.library.newSong", defaultValue: "New song") }
  // TODO(i18n)
  static var editSong: String { String(localized: "ios.library.editSong", defaultValue: "Edit") }
  // TODO(i18n)
  static var addToSetlist: String {
    String(localized: "ios.library.addToSetlist", defaultValue: "Add to setlist")
  }
  // TODO(i18n)
  static var pendingChanges: String {
    String(localized: "ios.library.pendingChanges", defaultValue: "Not synced yet")
  }
  // TODO(i18n)
  static var done: String { String(localized: "ios.library.done", defaultValue: "Done") }
  // TODO(i18n)
  static var cancel: String { String(localized: "ios.library.cancel", defaultValue: "Cancel") }
  // TODO(i18n)
  static var delete: String { String(localized: "ios.library.delete", defaultValue: "Delete") }
  // TODO(i18n)
  static var create: String { String(localized: "ios.library.create", defaultValue: "Create") }
  // TODO(i18n)
  static var newTag: String { String(localized: "ios.library.newTag", defaultValue: "New tag") }
  // TODO(i18n)
  static var tagName: String { String(localized: "ios.library.tagName", defaultValue: "Tag name") }
  // TODO(i18n)
  static var color: String { String(localized: "ios.library.color", defaultValue: "Color") }
  // TODO(i18n)
  static var noTags: String {
    String(localized: "ios.library.noTags", defaultValue: "No tags yet")
  }
  // TODO(i18n)
  static var noTagsHint: String {
    String(localized: "ios.library.noTagsHint", defaultValue: "Create a tag to organize your songs.")
  }
  // TODO(i18n)
  static var emptyTitle: String {
    String(localized: "ios.library.emptyTitle", defaultValue: "No songs yet")
  }
  // TODO(i18n)
  static var emptyMessage: String {
    String(localized: "ios.library.emptyMessage", defaultValue: "Songs you add will show up here, ready offline.")
  }
  // TODO(i18n)
  static var noResultsTitle: String {
    String(localized: "ios.library.noResultsTitle", defaultValue: "No matching songs")
  }
  // TODO(i18n)
  static var noResultsMessage: String {
    String(localized: "ios.library.noResultsMessage", defaultValue: "Try a different search or clear the filters.")
  }
  // TODO(i18n)
  static func addCount(_ count: Int) -> String {
    String(localized: "ios.library.addCount", defaultValue: "Add (\(count))")
  }
  // TODO(i18n)
  static func moreTags(_ count: Int) -> String {
    String(localized: "ios.library.moreTags", defaultValue: "+\(count)")
  }
  // TODO(i18n)
  static func bpm(_ value: Int) -> String {
    String(localized: "ios.library.bpm", defaultValue: "\(value) BPM")
  }

  // TODO(i18n)
  static func sortName(_ sort: SongSort) -> String {
    switch sort {
    case .recent: String(localized: "ios.library.sort.recent", defaultValue: "Recently added")
    case .title: String(localized: "ios.library.sort.title", defaultValue: "Title")
    case .artist: String(localized: "ios.library.sort.artist", defaultValue: "Artist")
    case .relevance: String(localized: "ios.library.sort.relevance", defaultValue: "Relevance")
    }
  }

  // TODO(i18n)
  static func bucketName(_ bucket: BPMBucket) -> String {
    switch bucket {
    case .slow: String(localized: "ios.library.bpm.slow", defaultValue: "Slow (< 90)")
    case .medium: String(localized: "ios.library.bpm.medium", defaultValue: "Medium (90–120)")
    case .fast: String(localized: "ios.library.bpm.fast", defaultValue: "Fast (> 120)")
    }
  }

  // TODO(i18n)
  static func statusName(_ status: SongStatus) -> String {
    switch status {
    case .published: String(localized: "ios.library.status.published", defaultValue: "Published")
    case .draft: String(localized: "ios.library.status.draft", defaultValue: "Draft")
    case .archived: String(localized: "ios.library.status.archived", defaultValue: "Archived")
    }
  }
}
