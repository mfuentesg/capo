import CapoCore
import Foundation
import Testing

@testable import CapoPerformanceUI

@Suite struct SongQueueTests {
  private let ids = (0..<4).map { _ in UUID() }
  private var queue: SongQueue {
    SongQueue(
      items: [
        SongQueueItem(id: ids[0], title: "Amazing Grace", artist: "John Newton", key: "G"),
        SongQueueItem(id: ids[1], title: "Puente de Fuego", artist: "Miel San Marcos", key: "D"),
        SongQueueItem(id: ids[2], title: "Cómo Zacarías", artist: nil, key: nil),
        SongQueueItem(id: ids[3], title: "Océanos", artist: "Hillsong", key: "Bm")
      ], title: "Setlist", buttonLabel: "Setlist", isNumbered: true)
  }

  @Test func middleSongHasBothNeighbours() throws {
    let n = try #require(SongNeighbors(queue: queue, current: ids[1]))
    #expect(n.previous?.id == ids[0])
    #expect(n.next?.id == ids[2])
    #expect(n.index == 1)
    #expect(n.count == 4)
    #expect(n.positionLabel == "2 / 4")
  }

  @Test func edgesHaveNoNeighbourBeyondThem() throws {
    let first = try #require(SongNeighbors(queue: queue, current: ids[0]))
    #expect(first.previous == nil)
    #expect(first.next?.id == ids[1])
    let last = try #require(SongNeighbors(queue: queue, current: ids[3]))
    #expect(last.next == nil)
    #expect(last.previous?.id == ids[2])
    #expect(last.positionLabel == "4 / 4")
  }

  @Test func songOutsideTheQueueHasNoNeighbours() {
    #expect(SongNeighbors(queue: queue, current: UUID()) == nil)
  }

  @Test func singleSongQueueIsInert() throws {
    let single = SongQueue(items: [queue.items[0]])
    let n = try #require(SongNeighbors(queue: single, current: ids[0]))
    #expect(n.previous == nil && n.next == nil)
    #expect(n.positionLabel == "1 / 1")
  }

  @Test func filterIgnoresCaseAndDiacritics() {
    #expect(queue.filtered(by: "oceanos").map(\.id) == [ids[3]])
    #expect(queue.filtered(by: "COMO").map(\.id) == [ids[2]])
    #expect(queue.filtered(by: "miel").map(\.id) == [ids[1]])
  }

  @Test func blankFilterKeepsOrder() {
    #expect(queue.filtered(by: "  ").map(\.id) == ids)
    #expect(queue.filtered(by: "zzz").isEmpty)
  }

  @Test func indexLookup() {
    #expect(queue.index(of: ids[2]) == 2)
    #expect(queue.index(of: UUID()) == nil)
  }
}

@MainActor @Suite struct PerformanceNavigationNeighborTests {
  @Test func wiresPreviousNextAndPosition() throws {
    let a = SongQueueItem(id: UUID(), title: "A")
    let b = SongQueueItem(id: UUID(), title: "B")
    let c = SongQueueItem(id: UUID(), title: "C")
    let queue = SongQueue(items: [a, b, c])
    var picked: [SongID] = []
    let neighbors = try #require(SongNeighbors(queue: queue, current: b.id))
    let nav = PerformanceNavigation.standalone.applying(
      neighbors: neighbors, onSelectSong: { picked.append($0) })
    #expect(nav.positionLabel == "2 / 3")
    #expect(nav.previousTitle == "A")
    #expect(nav.nextTitle == "C")
    nav.onPrevious?()
    nav.onNext?()
    #expect(picked == [a.id, c.id])
  }

  @Test func withoutSelectionCallbackNothingIsWired() throws {
    let a = SongQueueItem(id: UUID(), title: "A")
    let b = SongQueueItem(id: UUID(), title: "B")
    let neighbors = try #require(SongNeighbors(queue: SongQueue(items: [a, b]), current: a.id))
    let nav = PerformanceNavigation.standalone.applying(neighbors: neighbors, onSelectSong: nil)
    #expect(nav.onNext == nil && nav.onPrevious == nil && nav.positionLabel == nil)
  }

  @Test func firstSongOnlyGetsNext() throws {
    let a = SongQueueItem(id: UUID(), title: "A")
    let b = SongQueueItem(id: UUID(), title: "B")
    let neighbors = try #require(SongNeighbors(queue: SongQueue(items: [a, b]), current: a.id))
    let nav = PerformanceNavigation.standalone.applying(neighbors: neighbors, onSelectSong: { _ in })
    #expect(nav.onPrevious == nil)
    #expect(nav.onNext != nil)
  }
}
