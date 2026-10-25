import CoreGraphics
import Testing

@testable import CapoRendering

@Suite struct LayoutMathTests {
  @Test func wrapsAtPairBoundaries() {
    let rows = LineWrapper.rows(widths: [40, 40, 40, 40, 40], maxWidth: 100)
    #expect(rows == [0..<2, 2..<4, 4..<5])
  }

  @Test func exactFitStaysOnRow() {
    #expect(LineWrapper.rows(widths: [50, 50, 50], maxWidth: 100) == [0..<2, 2..<3])
  }

  @Test func oversizedItemGetsOwnRow() {
    #expect(LineWrapper.rows(widths: [10, 300, 10], maxWidth: 100) == [0..<1, 1..<2, 2..<3])
  }

  @Test func emptyAndUnbounded() {
    #expect(LineWrapper.rows(widths: [], maxWidth: 100).isEmpty)
    #expect(LineWrapper.rows(widths: [500, 500], maxWidth: .infinity) == [0..<2])
  }

  @Test func arrangePlacesRowsAndSpacing() {
    let sizes = [CGSize(width: 40, height: 30), CGSize(width: 40, height: 20), CGSize(width: 40, height: 25)]
    let result = ChordLyricsArrangeMath.arrange(sizes: sizes, maxWidth: 90, rowSpacing: 2)
    #expect(result.rowCount == 2)
    #expect(result.frames[1].origin == CGPoint(x: 40, y: 0))
    #expect(result.frames[2].origin == CGPoint(x: 0, y: 32))
    #expect(result.size == CGSize(width: 80, height: 57))
  }

  @Test func splitNearestHalf() {
    // total 100 + 3*0 spacing; boundary after [30,30] = 60, after [30] = 30, after 3 = 90
    #expect(ColumnBalance.splitIndex(heights: [30, 30, 30, 10], spacing: 0) == 2)
    #expect(ColumnBalance.splitIndex(heights: [100], spacing: 0) == 1)
    #expect(ColumnBalance.splitIndex(heights: [], spacing: 0) == 0)
  }

  @Test func splitKeepsLargeSegmentAtomic() {
    // One huge first segment: the break goes right after it.
    #expect(ColumnBalance.splitIndex(heights: [200, 20, 20, 20], spacing: 0) == 1)
  }

  @Test func splitAccountsForSpacing() {
    // totals: 10*4 + 3*20 = 100, half 50. First col after 2 items = 20+20 = 40, after 3 = 70+... 
    #expect(ColumnBalance.splitIndex(heights: [10, 10, 10, 10], spacing: 20) == 2)
  }

  @Test func planTwoColumns() {
    let plan = ColumnBalance.plan(
      heights: [30, 30, 30, 10], count: 2, width: 1000, gap: 40, spacing: 0)
    #expect(plan.columnWidth == 480)
    #expect(plan.split == 2)
    #expect(plan.placements.map(\.column) == [0, 0, 1, 1])
    #expect(plan.placements.map(\.y) == [0, 30, 0, 30])
    #expect(plan.height == 60)
  }

  @Test func singleColumnBelowThreshold() {
    #expect(ColumnBalance.columnCount(requested: 2, width: 500, gap: 40, minTwoColumnWidth: 640) == 1)
    #expect(ColumnBalance.columnCount(requested: 2, width: 700, gap: 40, minTwoColumnWidth: 640) == 2)
    let plan = ColumnBalance.plan(heights: [10, 20], count: 1, width: 500, gap: 40, spacing: 5)
    #expect(plan.placements.map(\.y) == [0, 15])
    #expect(plan.height == 35)
  }
}
