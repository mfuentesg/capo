import Foundation
import SwiftUI
import Testing

@testable import CapoPlaylistsUI

@Suite struct SetlistMathTests {
  @Test func moveDownUsesOnMoveSemantics() {
    #expect(SetlistMath.move([1, 2, 3, 4], from: IndexSet(integer: 0), to: 3) == [2, 3, 1, 4])
  }

  @Test func moveUp() {
    #expect(SetlistMath.move([1, 2, 3, 4], from: IndexSet(integer: 3), to: 1) == [1, 4, 2, 3])
  }

  @Test func moveToEndAndMulti() {
    #expect(SetlistMath.move([1, 2, 3], from: IndexSet(integer: 0), to: 3) == [2, 3, 1])
    #expect(SetlistMath.move([1, 2, 3, 4], from: [0, 1], to: 4) == [3, 4, 1, 2])
  }

  @Test func navigationBounds() {
    #expect(SetlistMath.next(0, count: 3) == 1)
    #expect(SetlistMath.next(2, count: 3) == nil)
    #expect(SetlistMath.previous(0) == nil)
    #expect(SetlistMath.previous(2) == 1)
    #expect(SetlistMath.clamp(9, count: 3) == 2)
    #expect(SetlistMath.clamp(-1, count: 3) == 0)
    #expect(SetlistMath.clamp(5, count: 0) == 0)
  }

  @Test func positionLabelAndWindow() {
    #expect(SetlistMath.positionLabel(index: 2, count: 12) == "3 / 12")
    #expect(SetlistMath.liveWindow(current: 0, count: 12) == 0...1)
    #expect(SetlistMath.liveWindow(current: 5, count: 12) == 4...6)
    #expect(SetlistMath.liveWindow(current: 11, count: 12) == 10...11)
    #expect(SetlistMath.liveWindow(current: 0, count: 1) == 0...0)
  }

  @Test func dateRoundTrip() {
    let d = PlaylistDate.parse("2026-03-01")
    #expect(d != nil)
    #expect(PlaylistDate.format(d!) == "2026-03-01")
    #expect(PlaylistDate.parse("") == nil)
    #expect(PlaylistDate.parse(nil) == nil)
  }
}
