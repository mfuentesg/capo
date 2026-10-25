import Foundation
import SwiftUI

/// Pure index math for reordering and setlist paging.
nonisolated enum SetlistMath {
  /// Same semantics as `onMove`: `destination` is an index in the original array.
  static func move<T>(_ items: [T], from source: IndexSet, to destination: Int) -> [T] {
    var copy = items
    copy.move(fromOffsets: source, toOffset: destination)
    return copy
  }

  static func clamp(_ index: Int, count: Int) -> Int {
    guard count > 0 else { return 0 }
    return min(max(index, 0), count - 1)
  }

  static func next(_ index: Int, count: Int) -> Int? { index + 1 < count ? index + 1 : nil }
  static func previous(_ index: Int) -> Int? { index > 0 ? index - 1 : nil }

  /// "3 / 12" for a zero-based index.
  static func positionLabel(index: Int, count: Int) -> String { "\(index + 1) / \(count)" }

  /// Pages kept alive around the current one (current +/- 1) so memory stays flat on long sets.
  static func liveWindow(current: Int, count: Int) -> ClosedRange<Int> {
    guard count > 0 else { return 0...0 }
    return max(current - 1, 0)...min(current + 1, count - 1)
  }
}

/// `Playlist.date` is a date-only `yyyy-MM-dd` string.
nonisolated enum PlaylistDate {
  private static func formatter() -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy-MM-dd"
    return f
  }

  static func parse(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    return formatter().date(from: string)
  }

  static func format(_ date: Date) -> String { formatter().string(from: date) }

  static func display(_ string: String?) -> String? {
    parse(string)?.formatted(date: .abbreviated, time: .omitted)
  }
}
