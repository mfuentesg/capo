import CapoCore
import Foundation

/// One entry of the song list shown in the setlist slide-over.
public nonisolated struct SongQueueItem: Identifiable, Hashable, Sendable {
  public let id: SongID
  public let title: String
  public let artist: String?
  public let key: String?

  public init(id: SongID, title: String, artist: String? = nil, key: String? = nil) {
    self.id = id
    self.title = title
    self.artist = artist
    self.key = key
  }

  public init(_ item: SongListItem) {
    self.init(id: item.id, title: item.title, artist: item.artist, key: item.key)
  }
}

/// The songs of the current context: a playlist (numbered) or the visible library order.
public nonisolated struct SongQueue: Equatable, Sendable {
  public var items: [SongQueueItem]
  /// Heading of the slide-over ("Setlist · Sunday service").
  public var title: String?
  /// Label of the header button that opens the slide-over ("Setlist" / "Songs").
  public var buttonLabel: String?
  public var isNumbered: Bool

  public init(
    items: [SongQueueItem], title: String? = nil, buttonLabel: String? = nil,
    isNumbered: Bool = false
  ) {
    self.items = items
    self.title = title
    self.buttonLabel = buttonLabel
    self.isNumbered = isNumbered
  }

  public func index(of id: SongID) -> Int? { items.firstIndex { $0.id == id } }

  /// Case- and diacritic-insensitive match on title and artist; an empty query keeps everything.
  public func filtered(by query: String) -> [SongQueueItem] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return items }
    let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return items.filter {
      $0.title.range(of: needle, options: options) != nil
        || ($0.artist?.range(of: needle, options: options) != nil)
    }
  }
}

/// Where the current song sits in its queue: the songs on either side and "3 / 6".
public nonisolated struct SongNeighbors: Equatable, Sendable {
  public let previous: SongQueueItem?
  public let next: SongQueueItem?
  /// Zero-based position of the current song.
  public let index: Int
  public let count: Int

  public init(previous: SongQueueItem?, next: SongQueueItem?, index: Int, count: Int) {
    self.previous = previous
    self.next = next
    self.index = index
    self.count = count
  }

  /// Nil when `current` is not in the queue.
  public init?(queue: SongQueue, current: SongID) {
    guard let index = queue.index(of: current) else { return nil }
    let items = queue.items
    self.init(
      previous: index > 0 ? items[index - 1] : nil,
      next: index + 1 < items.count ? items[index + 1] : nil,
      index: index, count: items.count)
  }

  public var positionLabel: String { "\(index + 1) / \(count)" }
}
