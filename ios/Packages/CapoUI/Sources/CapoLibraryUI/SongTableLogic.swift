import CapoDesign
import Foundation

/// Columns of the songs table that can be sorted by tapping their header.
nonisolated enum SongColumn: String, CaseIterable, Hashable, Sendable {
  case title, artist, key, bpm, tags, played, owner, recent

  /// Direction a column starts in when first tapped: most played first, everything else A-Z / low-high.
  var startsAscending: Bool { self != .played && self != .recent }
}

/// Sort state of the songs table.
nonisolated struct SongTableSort: Equatable, Hashable, Sendable {
  var column: SongColumn
  var ascending: Bool

  init(_ column: SongColumn, ascending: Bool? = nil) {
    self.column = column
    self.ascending = ascending ?? column.startsAscending
  }

  /// Header tap: the active column flips direction, another column starts in its natural direction.
  func tapped(_ other: SongColumn) -> SongTableSort {
    other == column ? SongTableSort(column, ascending: !ascending) : SongTableSort(other)
  }

  static let `default` = SongTableSort(.title)
}

/// Pure ordering, sectioning and index-scrubber rules of the songs table.
nonisolated enum SongTableLogic {
  /// Section index shown on the trailing edge: A-Z then "#".
  static let indexLetters: [String] =
    (UInt8(ascii: "A")...UInt8(ascii: "Z")).map { String(UnicodeScalar($0)) } + ["#"]

  /// Orders `items` by `sort`. Empty values always go last, whatever the direction; ties fall back
  /// to the title so the order is stable.
  static func sorted(
    _ items: [SongListItem], by sort: SongTableSort, ownerLabel: (SongListItem) -> String = { _ in "" }
  ) -> [SongListItem] {
    func text(_ item: SongListItem) -> String? {
      let raw: String?
      switch sort.column {
      case .title: raw = item.title
      case .artist: raw = item.artist
      case .key: raw = item.key
      case .owner: raw = ownerLabel(item)
      case .tags: raw = item.tags.map(\.name).sorted().first
      case .bpm, .played, .recent: raw = nil
      }
      let trimmed = raw?.trimmingCharacters(in: .whitespaces)
      return trimmed?.isEmpty == false ? trimmed : nil
    }
    func number(_ item: SongListItem) -> Double? {
      switch sort.column {
      case .bpm: return item.bpm.flatMap { $0 > 0 ? Double($0) : nil }
      case .played: return SongBadgeLogic.parseDate(item.lastPlayed)?.timeIntervalSince1970
      case .recent: return item.createdAt.date?.timeIntervalSince1970
      default: return nil
      }
    }
    func order<T: Comparable>(_ a: T?, _ b: T?, _ less: (T, T) -> Bool = { $0 < $1 }) -> Bool? {
      switch (a, b) {
      case (nil, nil): return nil
      case (nil, _): return false
      case (_, nil): return true
      case let (x?, y?):
        if x == y { return nil }
        return sort.ascending ? less(x, y) : less(y, x)
      }
    }
    return items.enumerated().sorted { lhs, rhs in
      let a = lhs.element, b = rhs.element
      let primary: Bool?
      switch sort.column {
      case .bpm, .played, .recent: primary = order(number(a), number(b))
      default: primary = order(text(a), text(b)) { $0.localizedStandardCompare($1) == .orderedAscending }
      }
      if let primary { return primary }
      let byTitle = a.title.localizedStandardCompare(b.title)
      if byTitle != .orderedSame { return byTitle == .orderedAscending }
      return lhs.offset < rhs.offset
    }.map(\.element)
  }

  /// Index letter of a value: first letter without diacritics ("Álbum" -> "A"); anything else -> "#".
  static func letter(of text: String?) -> String {
    guard let first = text?.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "#" }
    let folded = String(first).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
      .uppercased()
    guard folded.count == 1, let scalar = folded.unicodeScalars.first,
      ("A"..."Z").contains(scalar)
    else { return "#" }
    return folded
  }

  /// Whether the table offers letter sections and the index for this sort.
  static func usesLetterSections(_ sort: SongTableSort?, grouping: SongGrouping) -> Bool {
    guard grouping == .none, let sort else { return false }
    return sort.column == .title || sort.column == .artist
  }

  /// Consecutive runs of the same letter, in table order ("#" sorts with the rest of the order).
  static func letterSections(
    _ items: [SongListItem], column: SongColumn
  ) -> [(letter: String, items: [SongListItem])] {
    var result: [(letter: String, items: [SongListItem])] = []
    for item in items {
      let key = letter(of: column == .artist ? item.artist : item.title)
      if let last = result.last, last.letter == key {
        result[result.count - 1].items.append(item)
      } else {
        result.append((key, [item]))
      }
    }
    return result
  }

  /// Index letter under a touch: `fraction` is 0 at the top of the index, 1 at the bottom.
  static func scrubLetter(fraction: Double) -> String {
    let count = indexLetters.count
    let index = Int((min(max(fraction, 0), 0.9999999)) * Double(count))
    return indexLetters[index]
  }

  /// Section to jump to for a scrubbed letter: the same letter, else the next one present, else the last.
  static func target(for letter: String, available: [String]) -> String? {
    guard !available.isEmpty else { return nil }
    if available.contains(letter) { return letter }
    guard let from = indexLetters.firstIndex(of: letter) else { return available.last }
    return indexLetters[from...].first(where: available.contains) ?? available.last
  }

  /// One block of the table: a letter or group heading plus its songs. `title` is nil for the flat list.
  struct Section: Equatable {
    let id: String
    let title: String?
    let items: [SongListItem]
  }

  /// Sections for the displayed order: group-by headings win, then letter sections for title/artist
  /// sorts, otherwise one untitled block.
  static func sections(_ items: [SongListItem], sort: SongTableSort?, grouping: SongGrouping) -> [Section] {
    if grouping != .none {
      return SongGrouping.groups(items, by: grouping).map { Section(id: "group-\($0.title ?? "")", title: $0.title, items: $0.items) }
    }
    if usesLetterSections(sort, grouping: grouping), let sort {
      return letterSections(items, column: sort.column).map { Section(id: "letter-\($0.letter)", title: $0.letter, items: $0.items) }
    }
    return [Section(id: "all", title: nil, items: items)]
  }

  /// Table layout decided from the available width and size class.
  struct Layout: Equatable {
    enum Mode: Equatable { case compact, regular }
    let mode: Mode
    /// Owner chip column (landscape iPad); narrower regular widths show a dot before the title.
    let showsOwnerColumn: Bool
    let showsOwnerDot: Bool

    static let regularMinWidth: CGFloat = 600
    static let ownerColumnMinWidth: CGFloat = 1000

    init(width: CGFloat, isRegularSizeClass: Bool, showsOwnership: Bool) {
      mode = isRegularSizeClass && width >= Self.regularMinWidth ? .regular : .compact
      showsOwnerColumn = mode == .regular && showsOwnership && width >= Self.ownerColumnMinWidth
      showsOwnerDot = mode == .regular && showsOwnership && !showsOwnerColumn
    }
  }
}
