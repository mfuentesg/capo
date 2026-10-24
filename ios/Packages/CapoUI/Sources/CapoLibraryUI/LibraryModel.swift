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
  /// Songs queued to add to a playlist (the web's draft cart), in tap order.
  var cart: [SongID] = []

  func toggleCart(_ id: SongID) {
    if let index = cart.firstIndex(of: id) { cart.remove(at: index) } else { cart.append(id) }
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
