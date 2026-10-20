import CoreGraphics

/// Pure layout math, kept free of SwiftUI so it can be unit-tested with fixed sizes.
nonisolated enum LineWrapper {
  /// Greedy wrap at item boundaries. Every row holds at least one item, even if it is wider than
  /// `maxWidth`. Returns the item index range of each row.
  static func rows(widths: [CGFloat], spacing: CGFloat = 0, maxWidth: CGFloat) -> [Range<Int>] {
    guard !widths.isEmpty else { return [] }
    var rows: [Range<Int>] = []
    var start = 0
    var x: CGFloat = 0
    for (index, width) in widths.enumerated() {
      if index == start {
        x = width
        continue
      }
      let next = x + spacing + width
      if next > maxWidth + 0.001 {
        rows.append(start..<index)
        start = index
        x = width
      } else {
        x = next
      }
    }
    rows.append(start..<widths.count)
    return rows
  }
}

nonisolated struct ChordLyricsArrangement: Equatable {
  var frames: [CGRect]
  var size: CGSize
  var rowCount: Int
}

nonisolated enum ChordLyricsArrangeMath {
  /// Places pair columns left to right, wrapping at pair boundaries when a row would exceed `maxWidth`.
  static func arrange(sizes: [CGSize], maxWidth: CGFloat, rowSpacing: CGFloat)
    -> ChordLyricsArrangement
  {
    let rows = LineWrapper.rows(widths: sizes.map(\.width), maxWidth: maxWidth)
    var frames = [CGRect](repeating: .zero, count: sizes.count)
    var y: CGFloat = 0
    var maxRowWidth: CGFloat = 0
    for (rowIndex, row) in rows.enumerated() {
      let height = row.map { sizes[$0].height }.max() ?? 0
      var x: CGFloat = 0
      for index in row {
        frames[index] = CGRect(x: x, y: y, width: sizes[index].width, height: sizes[index].height)
        x += sizes[index].width
      }
      maxRowWidth = max(maxRowWidth, x)
      y += height + (rowIndex < rows.count - 1 ? rowSpacing : 0)
    }
    return ChordLyricsArrangement(
      frames: frames, size: CGSize(width: maxRowWidth, height: y), rowCount: rows.count)
  }
}

nonisolated struct ColumnPlacement: Equatable {
  var column: Int
  var y: CGFloat
}

nonisolated struct ColumnPlan: Equatable {
  var columnCount: Int
  var columnWidth: CGFloat
  /// Number of items in the first column (== item count for a single column).
  var split: Int
  var placements: [ColumnPlacement]
  var height: CGFloat
}

nonisolated enum ColumnBalance {
  /// Index at which the second column starts: the item boundary whose first-column height is
  /// nearest half of the total height. Ties go to the earlier boundary. Items stay atomic.
  static func splitIndex(heights: [CGFloat], spacing: CGFloat) -> Int {
    let count = heights.count
    guard count > 1 else { return count }
    let total = heights.reduce(0, +) + spacing * CGFloat(count - 1)
    let half = total / 2
    var best = 1
    var bestDiff = CGFloat.infinity
    var accumulated: CGFloat = 0
    for boundary in 1..<count {
      accumulated += heights[boundary - 1]
      let firstColumn = accumulated + spacing * CGFloat(boundary - 1)
      let diff = abs(firstColumn - half)
      if diff < bestDiff - 0.001 {
        bestDiff = diff
        best = boundary
      }
    }
    return best
  }

  /// `heights` must be measured at the resulting column width; use `columnWidth(...)` first.
  static func columnCount(requested: Int, width: CGFloat, gap: CGFloat, minTwoColumnWidth: CGFloat)
    -> Int
  {
    requested >= 2 && width >= minTwoColumnWidth ? 2 : 1
  }

  static func columnWidth(count: Int, width: CGFloat, gap: CGFloat) -> CGFloat {
    count == 2 ? max(0, (width - gap) / 2) : width
  }

  static func plan(heights: [CGFloat], count: Int, width: CGFloat, gap: CGFloat, spacing: CGFloat)
    -> ColumnPlan
  {
    let columnWidth = columnWidth(count: count, width: width, gap: gap)
    let split = count == 2 ? splitIndex(heights: heights, spacing: spacing) : heights.count
    var placements: [ColumnPlacement] = []
    var y: CGFloat = 0
    var columnHeights: [CGFloat] = [0, 0]
    for (index, height) in heights.enumerated() {
      let column = index < split ? 0 : 1
      if index == split { y = 0 }
      placements.append(ColumnPlacement(column: column, y: y))
      y += height + spacing
      columnHeights[column] = y - spacing
    }
    return ColumnPlan(
      columnCount: count, columnWidth: columnWidth, split: split, placements: placements,
      height: max(columnHeights[0], columnHeights[1]))
  }
}
