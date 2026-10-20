import CapoDesign
import Observation
import SwiftUI

/// Library screen model. Streams are consumed by `.task(id:)` in the view; this type only holds
/// state and the pure mapping from UI state to a `SongQuery`.
@Observable @MainActor
final class LibraryModel {
  var filters = LibraryFilters()
  /// Raw text from the search field; committed to `filters.searchText` after the debounce.
  var searchInput = ""
  var songs: [SongListItem] = []
  var tags: [SongTag] = []
  var hasLoaded = false

  func query(context: AppContext) -> SongQuery { filters.query(context: context) }

  /// Waits 150 ms, then commits the search text. Returns false when cancelled by a newer keystroke.
  @discardableResult
  func commitSearchAfterDebounce(delay: Duration = LibraryDebounce.search) async -> Bool {
    await debouncedCommit(searchInput, to: { [self] text in
      if filters.searchText != text { filters.searchText = text }
    }, delay: delay)
  }
}
