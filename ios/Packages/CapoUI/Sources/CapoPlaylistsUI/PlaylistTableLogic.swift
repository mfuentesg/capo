import CapoCore
import Foundation

/// Sortable columns of the playlists table.
nonisolated enum PlaylistColumn: String, CaseIterable, Hashable, Sendable {
  case name, date, songs, sharing
}

nonisolated struct PlaylistTableSort: Equatable, Sendable {
  var column: PlaylistColumn
  var ascending: Bool

  static let `default` = PlaylistTableSort(column: .date, ascending: false)

  /// Header tap: the active column flips direction; a new column starts A-Z, and the numeric
  /// columns (date, songs) start with the biggest / latest first.
  func tapped(_ other: PlaylistColumn) -> PlaylistTableSort {
    if other == column { return PlaylistTableSort(column: column, ascending: !ascending) }
    return PlaylistTableSort(column: other, ascending: other == .name || other == .sharing)
  }
}

/// Pure rules of the playlists table: search + visibility + Active/Archived tab, then the sort.
nonisolated enum PlaylistTableLogic {
  static func rows(
    _ items: [PlaylistSummary], query: String, visibility: PlaylistLogic.Visibility, archived: Bool,
    sort: PlaylistTableSort
  ) -> [PlaylistSummary] {
    let matches = PlaylistLogic.visible(items, query: query, visibility: visibility)
      .filter { ($0.playlist.archivedAt != nil) == archived }
    return sorted(matches, by: sort)
  }

  static func sorted(_ items: [PlaylistSummary], by sort: PlaylistTableSort) -> [PlaylistSummary] {
    func byName(_ a: PlaylistSummary, _ b: PlaylistSummary) -> ComparisonResult {
      a.playlist.name.localizedStandardCompare(b.playlist.name)
    }
    return items.enumerated().sorted { lhs, rhs in
      let a = lhs.element, b = rhs.element
      var result: ComparisonResult = .orderedSame
      switch sort.column {
      case .name:
        result = byName(a, b)
      case .songs:
        result = a.songCount == b.songCount ? .orderedSame : (a.songCount < b.songCount ? .orderedAscending : .orderedDescending)
      case .sharing:
        let x = a.playlist.isPublic ? 1 : 0, y = b.playlist.isPublic ? 1 : 0
        result = x == y ? .orderedSame : (x < y ? .orderedAscending : .orderedDescending)
      case .date:
        let x = a.playlist.date.flatMap { $0.isEmpty ? nil : $0 }, y = b.playlist.date.flatMap { $0.isEmpty ? nil : $0 }
        // Playlists without a date always go last; yyyy-MM-dd sorts chronologically as text.
        switch (x, y) {
        case (nil, nil): result = .orderedSame
        case (nil, _): return false
        case (_, nil): return true
        case let (x?, y?): result = x == y ? .orderedSame : (x < y ? .orderedAscending : .orderedDescending)
        }
      }
      if result != .orderedSame { return (result == .orderedAscending) == sort.ascending }
      let tie = byName(a, b)
      if tie != .orderedSame { return tie == .orderedAscending }
      return lhs.offset < rhs.offset
    }.map(\.element)
  }
}
