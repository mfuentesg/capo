import CapoDesign
import SwiftUI

public nonisolated struct SongRenderStyle: Hashable, Sendable {
  public var fontScale = 1.0, columns = 1, showChords = true, showLyrics = true, collapsible = true
  /// Header text of comment cards (localized "Comment"); empty hides the header.
  public var commentLabel = ""
  public init() {}
}

/// Native renderer for a `RenderedSong`. Non-scrolling; the caller owns the scroll view.
public struct ChordProContentView: View {
  let rendered: RenderedSong
  let style: SongRenderStyle
  let onChordTap: ((String) -> Void)?

  @State private var collapsed: Set<Int> = []

  public init(rendered: RenderedSong, style: SongRenderStyle, onChordTap: ((String) -> Void)? = nil) {
    self.rendered = rendered
    self.style = style
    self.onChordTap = onChordTap
  }

  public var body: some View {
    let context = RenderContext(style: style, accent: nil, onChordTap: onChordTap)
    BalancedColumnsLayout(columns: style.columns) {
      ForEach(RenderUnit.units(for: rendered)) { unit in
        unitView(unit, context: context)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func unitView(_ unit: RenderUnit, context: RenderContext) -> some View {
    switch unit.content {
    case .lines(let lines):
      LinesView(lines: lines, context: context)
        .frame(maxWidth: .infinity, alignment: .leading)
    case .segment(let index, let segment):
      SegmentView(
        segment: segment, context: context,
        isCollapsed: collapsed.contains(index),
        onToggle: style.collapsible ? { toggle(index) } : nil
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, 24 * style.fontScale.clamped(to: 0.75...1.5))
    }
  }

  private func toggle(_ index: Int) {
    if collapsed.contains(index) { collapsed.remove(index) } else { collapsed.insert(index) }
  }
}

extension Double {
  fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

/// A top-level, column-atomic piece of the song.
nonisolated struct RenderUnit: Identifiable {
  enum Content {
    case lines([BodyLine])
    case segment(index: Int, LyricsSegment)
  }
  let id: Int
  let content: Content

  /// Sections, repeats and extends are atomic. A `.normal` segment is split after each blank line
  /// so that songs without sections can still be balanced across two columns.
  static func units(for song: RenderedSong) -> [RenderUnit] {
    var units: [RenderUnit] = []
    for (index, segment) in song.segments.enumerated() {
      if case .normal(let body) = segment {
        for chunk in chunks(of: body.lines) {
          units.append(RenderUnit(id: units.count, content: .lines(chunk)))
        }
      } else {
        units.append(RenderUnit(id: units.count, content: .segment(index: index, segment)))
      }
    }
    return units
  }

  static func chunks(of lines: [BodyLine]) -> [[BodyLine]] {
    var chunks: [[BodyLine]] = []
    var current: [BodyLine] = []
    for line in lines {
      current.append(line)
      if case .text(let text) = line, text.isEmpty {
        chunks.append(current)
        current = []
      }
    }
    if !current.isEmpty { chunks.append(current) }
    return chunks
  }
}
