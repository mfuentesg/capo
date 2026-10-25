import CapoDesign
import Foundation

/// Library copy; thin wrappers over the generated `L10n.Ios.Library`.
enum LibraryStrings {
  static var title: String { L10n.Ios.Library.title }
  static var searchPrompt: String {
    L10n.Ios.Library.searchPrompt
  }
  static var pickerTitle: String {
    L10n.Ios.Library.pickerTitle
  }
  static var filters: String { L10n.Ios.Library.filters }
  static var sort: String { L10n.Ios.Library.sortLabel }
  static var tempo: String { L10n.Ios.Library.tempo }
  static var resetFilters: String {
    L10n.Ios.Library.resetFilters
  }
  static var manageTags: String {
    L10n.Ios.Library.manageTags
  }
  static var tags: String { L10n.Ios.Library.tags }
  static var assignTags: String {
    L10n.Ios.Library.assignTags
  }
  static var newSong: String { L10n.Ios.Library.newSong }
  static var editSong: String { L10n.Ios.Library.editSong }
  static var addToSetlist: String {
    L10n.Ios.Library.addToSetlist
  }
  static var pendingChanges: String {
    L10n.Ios.Library.pendingChanges
  }
  static var done: String { L10n.Ios.Library.done }
  static var cancel: String { L10n.Ios.Library.cancel }
  static var delete: String { L10n.Ios.Library.delete }
  static var create: String { L10n.Ios.Library.create }
  static var newTag: String { L10n.Ios.Library.newTag }
  static var tagName: String { L10n.Ios.Library.tagName }
  static var color: String { L10n.Ios.Library.color }
  static var noTags: String {
    L10n.Ios.Library.noTags
  }
  static var noTagsHint: String {
    L10n.Ios.Library.noTagsHint
  }
  static var emptyTitle: String {
    L10n.Ios.Library.emptyTitle
  }
  static var emptyMessage: String {
    L10n.Ios.Library.emptyMessage
  }
  static var noResultsTitle: String {
    L10n.Ios.Library.noResultsTitle
  }
  static var noResultsMessage: String {
    L10n.Ios.Library.noResultsMessage
  }
  static var addToCart: String { L10n.Songs.addToPlaylist }
  static var removeFromCart: String { L10n.Ios.Library.removeFromCart }
  static var clearCart: String { L10n.Ios.Library.clearCart }
  static func cartAdd(_ count: Int) -> String { L10n.Ios.Library.cartAddCount(count: String(count)) }
  static var songsTitle: String { L10n.Songs.title }
  static var addSong: String { L10n.Songs.addSong }
  static var searchSongs: String { L10n.Ios.Library.searchPrompt }
  static var filtersTitle: String { L10n.Songs.filters }
  static var filtersDescription: String { L10n.Songs.filtersDescription }
  static var clearAll: String { L10n.Filters.clearAll }
  static var bpmRange: String { L10n.Songs.bpmRange }
  static var groupBy: String { L10n.Songs.groupBy }
  static var noSongs: String { L10n.Songs.noSongs }
  static var tryDifferentSearch: String { L10n.Common.tryDifferentSearch }
  static var all: String { L10n.Songs.all }
  static var me: String { L10n.Ios.Library.meOwner }
  static var bpmHelp: String {
    BPMBucket.description(slow: L10n.Songs.slow, medium: L10n.Songs.medium, fast: L10n.Songs.fast)
  }
  static func groupName(_ grouping: SongGrouping) -> String {
    switch grouping {
    case .none: L10n.Songs.none
    case .key: L10n.Songs.byKey
    case .artist: L10n.Songs.byArtist
    }
  }
  /// Web filter button labels (`songs.slow` / `medium` / `fast`).
  static func webBucketName(_ bucket: BPMBucket) -> String {
    switch bucket {
    case .slow: L10n.Songs.slow
    case .medium: L10n.Songs.medium
    case .fast: L10n.Songs.fast
    }
  }
  static func addCount(_ count: Int) -> String {
    L10n.Ios.Library.addCount(count: String(count))
  }
  static func moreTags(_ count: Int) -> String {
    L10n.Ios.Library.moreTags(count: String(count))
  }
  static func bpm(_ value: Int) -> String {
    L10n.Ios.Library.bpmValue(value: String(value))
  }
  static func sortName(_ sort: SongSort) -> String {
    switch sort {
    case .recent: L10n.Ios.Library.Sort.recent
    case .title: L10n.Ios.Library.Sort.title
    case .artist: L10n.Ios.Library.Sort.artist
    case .relevance: L10n.Ios.Library.Sort.relevance
    }
  }
  static func bucketName(_ bucket: BPMBucket) -> String {
    switch bucket {
    case .slow: L10n.Ios.Library.Bpm.slow
    case .medium: L10n.Ios.Library.Bpm.medium
    case .fast: L10n.Ios.Library.Bpm.fast
    }
  }
  static func columnName(_ column: SongColumn) -> String {
    switch column {
    case .title: L10n.Ios.Table.colTitle
    case .artist: L10n.Ios.Library.Sort.artist
    case .key: L10n.Ios.Table.colKey
    case .bpm: L10n.Ios.Table.colBpm
    case .tags: L10n.Ios.Table.colTags
    case .played: L10n.Ios.Table.colPlayed
    case .owner: L10n.Ios.Table.colOwner
    case .recent: L10n.Ios.Table.sortRecent
    }
  }
}
