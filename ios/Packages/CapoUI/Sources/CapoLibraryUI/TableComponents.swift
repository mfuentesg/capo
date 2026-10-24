import CapoDesign
import CapoIcons
import SwiftUI

/// Glyphs the table chrome needs that the generated lucide set does not carry (same 24 grid,
/// 2 pt round strokes).
public enum TableGlyph: Sendable {
  case arrowUp, arrowDown, arrowUpDown, chevronsUpDown, listChecks

  nonisolated var paths: [String] {
    switch self {
    case .arrowUp: ["m5 12 7-7 7 7", "M12 19V5"]
    case .arrowDown: ["M12 5v14", "m19 12-7 7-7-7"]
    case .arrowUpDown: ["m21 16-4 4-4-4", "M17 20V4", "m3 8 4-4 4 4", "M7 4v16"]
    case .chevronsUpDown: ["m7 15 5 5 5-5", "m7 9 5-5 5 5"]
    case .listChecks: ["m3 17 2 2 4-4", "m3 7 2 2 4-4", "M13 6h8", "M13 12h8", "M13 18h8"]
    }
  }
}

nonisolated struct TableGlyphShape: Shape {
  let glyph: TableGlyph

  func path(in rect: CGRect) -> Path {
    let side = min(rect.width, rect.height)
    let scale = side / 24
    var path = Path()
    for d in glyph.paths { path.addPath(CapoSVGPath.path(from: d)) }
    return path.applying(CGAffineTransform(scaleX: scale, y: scale))
      .offsetBy(dx: rect.midX - side / 2, dy: rect.midY - side / 2)
  }
}

public struct TableGlyphView: View {
  let glyph: TableGlyph
  var size: CGFloat

  public init(_ glyph: TableGlyph, size: CGFloat = 16) {
    self.glyph = glyph
    self.size = size
  }

  public var body: some View {
    TableGlyphShape(glyph: glyph)
      .stroke(style: StrokeStyle(lineWidth: 2 * size / 24, lineCap: .round, lineJoin: .round))
      .frame(width: size, height: size)
  }
}

/// Sort indicator state of a column header.
public enum TableSortState: Equatable, Sendable {
  case unsorted, ascending, descending
}

/// Column header cell: uppercase caption plus a sort indicator. Tapping it asks the caller to sort.
public struct TableColumnHeader: View {
  let title: String
  let state: TableSortState
  let action: (() -> Void)?

  public init(_ title: String, state: TableSortState = .unsorted, action: (() -> Void)? = nil) {
    self.title = title
    self.state = state
    self.action = action
  }

  public var body: some View {
    if let action {
      Button(action: action) { label }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(
          state == .ascending ? L10n.Ios.Table.sortAscending
            : state == .descending ? L10n.Ios.Table.sortDescending : "")
        .accessibilityAddTraits(state == .unsorted ? [] : .isSelected)
    } else {
      label
    }
  }

  private var label: some View {
    HStack(spacing: 4) {
      Text(title.uppercased()).capoText(.xs, weight: .semibold, tracking: 0.05).lineLimit(1)
      if action != nil {
        switch state {
        case .unsorted: TableGlyphView(.chevronsUpDown, size: 12).opacity(0.55)
        case .ascending: TableGlyphView(.arrowUp, size: 12)
        case .descending: TableGlyphView(.arrowDown, size: 12)
        }
      }
    }
    .foregroundStyle(state == .unsorted ? CapoTheme.mutedForeground : CapoTheme.foreground)
    .frame(minHeight: 36)
    .contentShape(Rectangle())
  }
}

public extension View {
  /// Header strip of a table: muted band with a bottom hairline.
  func tableHeaderStrip() -> some View {
    self
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(CapoTheme.muted.opacity(0.35))
      .overlay(alignment: .top) { CapoTheme.border.frame(height: 1) }
      .overlay(alignment: .bottom) { CapoTheme.border.frame(height: 1) }
  }
}

/// A-Z index on the trailing edge. Dragging across it reports the letter under the finger.
struct LetterIndexScrubber: View {
  let letters: [String]
  let available: Set<String>
  let active: String?
  let onScrub: (String) -> Void

  init(
    letters: [String] = SongTableLogic.indexLetters, available: Set<String>, active: String?,
    onScrub: @escaping (String) -> Void
  ) {
    self.letters = letters
    self.available = available
    self.active = active
    self.onScrub = onScrub
  }

  var body: some View {
    GeometryReader { proxy in
      VStack(spacing: 0) {
        ForEach(letters, id: \.self) { letter in
          Text(letter)
            .capoText(.px10, weight: letter == active ? .bold : .medium)
            .foregroundStyle(
              letter == active ? CapoTheme.primary
                : available.contains(letter) ? CapoTheme.mutedForeground
                : CapoTheme.mutedForeground.opacity(0.4)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let height = max(proxy.size.height, 1)
            onScrub(SongTableLogic.scrubLetter(fraction: Double(value.location.y / height)))
          })
    }
    .frame(width: 20)
    .accessibilityElement()
    .accessibilityLabel(L10n.Ios.Table.indexLabel)
    .accessibilityAdjustableAction { direction in
      guard let current = active, let index = letters.firstIndex(of: current) else { return }
      let next = direction == .increment ? index + 1 : index - 1
      if letters.indices.contains(next) { onScrub(letters[next]) }
    }
  }
}

/// Floating pill with the selection summary: "3 selected · Clear · Add to Playlist".
struct SelectionBar: View {
  let count: Int
  let onClear: () -> Void
  let onAdd: () -> Void

  init(count: Int, onClear: @escaping () -> Void, onAdd: @escaping () -> Void) {
    self.count = count
    self.onClear = onClear
    self.onAdd = onAdd
  }

  var body: some View {
    HStack(spacing: 14) {
      Text(L10n.Ios.Table.selectedCount(count: String(count)))
        .capoText(.sm, weight: .medium).monospacedDigit()
        .padding(.leading, 6)
      Button(action: onClear) {
        Text(L10n.Ios.Table.clear).capoText(.sm, weight: .medium)
          .foregroundStyle(CapoTheme.mutedForeground)
          .frame(minHeight: 36)
      }
      .buttonStyle(.plain)
      Button(action: onAdd) {
        HStack(spacing: 8) {
          CapoIcon(.listMusic, size: 16)
          Text(L10n.Ios.Table.addToPlaylist).capoText(.sm, weight: .medium).lineLimit(1)
        }
        .foregroundStyle(CapoTheme.primaryForeground)
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
        .background(CapoTheme.primary, in: Capsule())
      }
      .buttonStyle(.plain)
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(6)
    .background(CapoTheme.card, in: Capsule())
    .overlay(Capsule().strokeBorder(CapoTheme.border, lineWidth: 1))
    .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
  }
}
