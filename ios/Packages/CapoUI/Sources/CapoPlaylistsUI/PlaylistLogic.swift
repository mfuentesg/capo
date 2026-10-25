import CapoCore
import Foundation

/// Pure rules of the playlist screens (list filter, reorder by drop, draft cart add).
nonisolated enum PlaylistLogic {
  enum Visibility: String, CaseIterable, Sendable { case all, `public`, `private` }

  /// Client-side search plus the visibility filter of `playlists-client.tsx`; active playlists come
  /// first, archived ones (shown dimmed) after them, each group keeping the incoming order.
  static func visible(
    _ items: [PlaylistSummary], query: String, visibility: Visibility
  ) -> [PlaylistSummary] {
    let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
    let matches = items.filter { item in
      let byVisibility =
        switch visibility {
        case .all: true
        case .public: item.playlist.isPublic
        case .private: !item.playlist.isPublic
        }
      guard byVisibility else { return false }
      guard !needle.isEmpty else { return true }
      return item.playlist.name.lowercased().contains(needle)
        || (item.playlist.description ?? "").lowercased().contains(needle)
    }
    return matches.filter { $0.playlist.archivedAt == nil }
      + matches.filter { $0.playlist.archivedAt != nil }
  }

  /// Drops the dragged item onto `target`, taking its place (down the list it lands after it, up
  /// the list before it); an unknown id or a drop on itself changes nothing.
  static func move<ID: Hashable, T: Identifiable>(
    _ items: [T], dragged: ID, onto target: ID
  ) -> [T] where T.ID == ID {
    guard dragged != target, let from = items.firstIndex(where: { $0.id == dragged }),
      let to = items.firstIndex(where: { $0.id == target })
    else { return items }
    var copy = items
    let item = copy.remove(at: from)
    copy.insert(item, at: to)
    return copy
  }

  /// Songs of the cart that are not in the playlist yet, in cart order and without repeats.
  static func newSongs(adding cart: [SongID], to existing: [SongID]) -> [SongID] {
    var seen = Set(existing)
    return cart.filter { seen.insert($0).inserted }
  }

  /// "Songs": "1 song" / "3 songs" from the web's `song` / `songsPlural` words.
  static func countLabel(_ count: Int, singular: String, plural: String) -> String {
    "\(count) \(count == 1 ? singular : plural)"
  }
}
