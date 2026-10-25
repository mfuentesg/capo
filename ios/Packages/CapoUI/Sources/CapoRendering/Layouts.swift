import SwiftUI

/// Lays out chord-over-lyric columns left to right, wrapping at pair boundaries. Each subview is
/// one pair, whose width is already `max(chord width + gap, fragment width)` via its own VStack.
struct ChordLyricsLineLayout: Layout {
  var rowSpacing: CGFloat = 2

  /// Ideal sizes don't depend on the proposal, so measure once instead of on every probe.
  /// SwiftUI rebuilds the cache whenever the subviews change.
  func makeCache(subviews: Subviews) -> [CGSize] {
    subviews.map { $0.sizeThatFits(.unspecified) }
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize])
    -> CGSize
  {
    arrange(proposal: proposal, sizes: cache).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout [CGSize]
  ) {
    let arrangement = arrange(proposal: proposal, sizes: cache)
    for (index, frame) in arrangement.frames.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        anchor: .topLeading,
        proposal: ProposedViewSize(frame.size))
    }
  }

  private func arrange(proposal: ProposedViewSize, sizes: [CGSize]) -> ChordLyricsArrangement {
    ChordLyricsArrangeMath.arrange(
      sizes: sizes, maxWidth: proposal.width ?? .infinity, rowSpacing: rowSpacing)
  }
}

/// Top-level units flow into one or two columns. Units are atomic; with two columns the break goes
/// at the unit boundary nearest half the total height. Falls back to one column below
/// `minTwoColumnWidth` (the web does the same under 768px).
struct BalancedColumnsLayout: Layout {
  var columns = 1
  var gap: CGFloat = 40
  var spacing: CGFloat = 0
  var minTwoColumnWidth: CGFloat = 640

  struct Cache {
    var width: CGFloat?
    var heights: [CGFloat] = []
  }

  func makeCache(subviews: Subviews) -> Cache { Cache() }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
    let width = proposal.width ?? 600
    let plan = plan(width: width, subviews: subviews, cache: &cache)
    return CGSize(width: width, height: plan.height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) {
    let plan = plan(width: bounds.width, subviews: subviews, cache: &cache)
    for (index, placement) in plan.placements.enumerated() {
      let x = bounds.minX + CGFloat(placement.column) * (plan.columnWidth + gap)
      subviews[index].place(
        at: CGPoint(x: x, y: bounds.minY + placement.y), anchor: .topLeading,
        proposal: ProposedViewSize(width: plan.columnWidth, height: nil))
    }
  }

  private func plan(width: CGFloat, subviews: Subviews, cache: inout Cache) -> ColumnPlan {
    let count = ColumnBalance.columnCount(
      requested: columns, width: width, gap: gap, minTwoColumnWidth: minTwoColumnWidth)
    let columnWidth = ColumnBalance.columnWidth(count: count, width: width, gap: gap)
    if cache.width != columnWidth || cache.heights.count != subviews.count {
      cache.heights = subviews.map {
        $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
      }
      cache.width = columnWidth
    }
    return ColumnBalance.plan(
      heights: cache.heights, count: count, width: width, gap: gap, spacing: spacing)
  }
}
