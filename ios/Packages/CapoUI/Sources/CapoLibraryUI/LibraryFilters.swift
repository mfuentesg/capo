import CapoDesign
import Foundation

/// BPM bucket: slow < 90, medium 90...120, fast > 120.
nonisolated enum BPMBucket: String, CaseIterable, Hashable, Sendable {
  case slow, medium, fast

  var range: ClosedRange<Int> {
    switch self {
    case .slow: 0...89
    case .medium: 90...120
    case .fast: 121...Int(Int32.max)
    }
  }
}

/// Pure UI filter state. Everything the library screen lets the user change lives here, so the
/// mapping to a `SongQuery` can be unit-tested without a view.
nonisolated struct LibraryFilters: Equatable, Sendable {
  static let defaultStatuses: Set<SongStatus> = [.published, .draft]

  var searchText = ""
  var tagIDs: Set<TagID> = []
  var statuses: Set<SongStatus> = LibraryFilters.defaultStatuses
  var bpm: BPMBucket?
  /// nil = automatic: relevance while searching, otherwise most recent.
  var sort: SongSort?

  var trimmedSearch: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
  var isSearching: Bool { !trimmedSearch.isEmpty }

  /// Relevance only makes sense with a search term.
  var effectiveSort: SongSort {
    switch sort {
    case .relevance?: isSearching ? .relevance : .recent
    case let sort?: sort
    case nil: isSearching ? .relevance : .recent
    }
  }

  /// Sort choices offered in the menu.
  var availableSorts: [SongSort] {
    isSearching ? [.relevance, .recent, .title, .artist] : [.recent, .title, .artist]
  }

  /// Number of active non-search filters (badge on the filter button).
  var activeFilterCount: Int {
    (tagIDs.isEmpty ? 0 : 1) + (statuses == Self.defaultStatuses ? 0 : 1) + (bpm == nil ? 0 : 1)
  }

  var hasActiveFilters: Bool { activeFilterCount > 0 }
  var isNarrowed: Bool { hasActiveFilters || isSearching }

  mutating func resetFilters() {
    tagIDs = []
    statuses = Self.defaultStatuses
    bpm = nil
  }

  mutating func toggle(tag id: TagID) {
    if !tagIDs.insert(id).inserted { tagIDs.remove(id) }
  }

  /// Toggles a status but never lets the set become empty (an empty set matches nothing).
  mutating func toggle(status: SongStatus) {
    if statuses.contains(status) {
      if statuses.count > 1 { statuses.remove(status) }
    } else {
      statuses.insert(status)
    }
  }

  func query(context: AppContext) -> SongQuery {
    SongQuery(
      context: context, searchText: trimmedSearch, tagIDs: tagIDs, statuses: statuses,
      bpmRange: bpm?.range, sort: effectiveSort)
  }
}

/// Debounce shared by the library and the picker: waits `delay`, then commits `input` to `output`.
/// Cancellation (a newer keystroke restarting `.task(id:)`) skips the commit.
@MainActor
func debouncedCommit(
  _ input: String, to output: @MainActor (String) -> Void, delay: Duration = LibraryDebounce.search
) async -> Bool {
  do { try await Task.sleep(for: delay) } catch { return false }
  output(input)
  return true
}

enum LibraryDebounce {
  static let search: Duration = .milliseconds(150)
}
