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
  /// Teams the user belongs to, sorted by name (bucket colours and names for the "All" view).
  var teams: [Team] = []
  /// Column the table is sorted by. Until the user picks one, a search keeps its relevance order.
  var tableSort = SongTableSort.default
  var sortChosen = false
  /// "Select" mode: row taps toggle the selection instead of opening the song.
  var selecting = false

  /// Sort actually applied to the table; nil keeps the service order (relevance while searching).
  var effectiveTableSort: SongTableSort? {
    filters.isSearching && !sortChosen ? nil : tableSort
  }

  func sort(by column: SongColumn) {
    tableSort = tableSort.tapped(column)
    sortChosen = true
  }

  func setSort(_ sort: SongTableSort) {
    tableSort = sort
    sortChosen = true
  }

  /// Leaves select mode; the queued songs stay in the shared playlist draft.
  func finishSelecting() {
    selecting = false
  }

  /// Songs in table order for the current sort.
  func displayedSongs(context: AppContext) -> [SongListItem] {
    guard let sort = effectiveTableSort else { return songs }
    return SongTableLogic.sorted(songs, by: sort) { [self] in ownership(for: $0, in: context)?.label ?? "" }
  }

  /// Ownership chip for a row; only the "All" view shows it.
  func ownership(for item: SongListItem, in context: AppContext) -> OwnershipChip? {
    guard context.isAll else { return nil }
    guard let teamID = item.teamID else {
      return OwnershipChip(label: LibraryStrings.me, icon: nil, color: SongTone.bucket(.personal, teams: []))
    }
    let ids = teams.map(\.id)
    let team = teams.first { $0.id == teamID }
    return OwnershipChip(
      label: team?.name ?? "", icon: team?.icon, color: SongTone.bucket(.team(teamID), teams: ids))
  }

  func query(context: AppContext) -> SongQuery { filters.query(context: context) }

  /// Waits 150 ms, then commits the search text. Returns false when cancelled by a newer keystroke.
  @discardableResult
  func commitSearchAfterDebounce(delay: Duration = LibraryDebounce.search) async -> Bool {
    await debouncedCommit(searchInput, to: { [self] text in
      if filters.searchText != text { filters.searchText = text }
    }, delay: delay)
  }
}
