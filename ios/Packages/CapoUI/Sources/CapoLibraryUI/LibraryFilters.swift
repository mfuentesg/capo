import CapoDesign
import Foundation

/// BPM filter bucket with the web's thresholds (`lib/bpm.ts`): slow < 90, medium 90...120, fast > 120.
nonisolated enum BPMBucket: String, CaseIterable, Hashable, Sendable {
  case slow, medium, fast

  var range: ClosedRange<Int> {
    switch self {
    case .slow: 0...89
    case .medium: 90...120
    case .fast: 121...Int(Int32.max)
    }
  }

  /// Help text matching the applied thresholds.
  static func description(slow: String, medium: String, fast: String) -> String {
    "\(slow): <90 • \(medium): 90-120 • \(fast): >120"
  }
}

/// Group-by option of the filters popover (web `groupBy`).
nonisolated enum SongGrouping: String, CaseIterable, Hashable, Sendable {
  case none, key, artist

  /// Groups in the web order: keys sorted with `localeCompare`; songs missing the field go last.
  static func groups(_ items: [SongListItem], by grouping: SongGrouping) -> [(title: String?, items: [SongListItem])] {
    guard grouping != .none else { return [(nil, items)] }
    var buckets: [String: [SongListItem]] = [:]
    for item in items {
      let value = (grouping == .key ? item.key : item.artist)?.trimmingCharacters(in: .whitespaces) ?? ""
      buckets[value, default: []].append(item)
    }
    let titles = buckets.keys.sorted {
      if $0.isEmpty != $1.isEmpty { return !$0.isEmpty }
      return $0.localizedStandardCompare($1) == .orderedAscending
    }
    return titles.map { ($0.isEmpty ? "—" : $0, buckets[$0] ?? []) }
  }
}

/// Pure UI filter state. Everything the library screen lets the user change lives here, so the
/// mapping to a `SongQuery` can be unit-tested without a view.
nonisolated struct LibraryFilters: Equatable, Sendable {
  /// Every status, like the web list, which has no status filter (and no way to set a status).
  static let defaultStatuses = Set(SongStatus.allCases)

  var searchText = ""
  var tagIDs: Set<TagID> = []
  let statuses: Set<SongStatus> = LibraryFilters.defaultStatuses
  var bpm: BPMBucket?
  var grouping: SongGrouping = .none
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
    (tagIDs.isEmpty ? 0 : 1) + (bpm == nil ? 0 : 1)
      + (grouping == .none ? 0 : 1)
  }

  var hasActiveFilters: Bool { activeFilterCount > 0 }
  var isNarrowed: Bool { hasActiveFilters || isSearching }

  mutating func resetFilters() {
    tagIDs = []
    bpm = nil
    grouping = .none
  }

  mutating func toggle(tag id: TagID) {
    if !tagIDs.insert(id).inserted { tagIDs.remove(id) }
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
