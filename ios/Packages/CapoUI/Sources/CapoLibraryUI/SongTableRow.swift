import CapoDesign
import CapoIcons
import SwiftUI

/// Fixed column widths shared by the header strip and the rows so they line up.
enum SongTableMetrics {
  static let cart: CGFloat = 44
  static let key: CGFloat = 68
  static let bpm: CGFloat = 112
  static let played: CGFloat = 104
  static let owner: CGFloat = 150
  static let rowHeight: CGFloat = 46
  /// Room the A-Z index takes on the trailing edge.
  static let index: CGFloat = 22
  static func tags(showsOwnerColumn: Bool) -> CGFloat { showsOwnerColumn ? 210 : 170 }
}

/// What a row needs besides the song, so the table can pass it without long argument lists.
struct SongTableRowState {
  var inCart: Bool
  var selecting: Bool
  var ownership: OwnershipChip?
  var layout: SongTableLogic.Layout
}

/// `# worship` tag chip of the table: tag colour on a tint.
struct TableTagChip: View {
  let name: String
  let colorHex: String?

  var body: some View {
    let color = HexColor.tagColor(colorHex)
    let shape = RoundedRectangle(cornerRadius: CapoRadius.sm, style: .continuous)
    HStack(spacing: 3) {
      Text("#").opacity(0.7)
      Text(name).lineLimit(1)
    }
    .capoText(.px11, weight: .medium)
    .foregroundStyle(color)
    .padding(.horizontal, 7)
    .frame(height: 22)
    .background(color.opacity(0.13), in: shape)
    .overlay(shape.strokeBorder(color.opacity(0.28), lineWidth: 1))
    .fixedSize()
  }
}

/// Round select toggle of a row: "+" on the songs tint, a check on the playlists accent once chosen.
struct SongSelectToggle: View {
  let active: Bool
  var diameter: CGFloat = 28
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      ZStack {
        Circle().fill(active ? CapoTheme.accentPlaylists : CapoTheme.accentSongs.opacity(0.14))
        CapoIcon(active ? .check : .plus, size: diameter * 0.55)
          .foregroundStyle(active ? Color.white : CapoTheme.accentSongs)
      }
      .frame(width: diameter, height: diameter)
      .frame(width: SongTableMetrics.cart, height: SongTableMetrics.rowHeight)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(active ? LibraryStrings.removeFromCart : LibraryStrings.addToCart)
  }
}

/// Regular-width table row: one line of cart toggle, title + artist, key, tempo, tags, played, owner.
struct SongTableRow: View {
  let item: SongListItem
  let state: SongTableRowState
  let onToggle: () -> Void

  var body: some View {
    let layout = state.layout
    HStack(spacing: 0) {
      SongSelectToggle(active: state.inCart, action: onToggle)
      titleCell.frame(maxWidth: .infinity, alignment: .leading)
      cell(width: SongTableMetrics.key) {
        if let key = item.key, !key.isEmpty { KeyBadge(key: key) } else { dash }
      }
      cell(width: SongTableMetrics.bpm) {
        if let bpm = item.bpm, bpm > 0 { BPMBadge(bpm: bpm) } else { dash }
      }
      cell(width: SongTableMetrics.tags(showsOwnerColumn: layout.showsOwnerColumn)) { tags }
      cell(width: SongTableMetrics.played) {
        if PlayedBadge.value(item) != nil { PlayedBadge(item: item) } else { dash }
      }
      if layout.showsOwnerColumn {
        cell(width: SongTableMetrics.owner) {
          if let chip = state.ownership { OwnerChipView(chip: chip) }
        }
      }
    }
    .padding(.leading, 8)
    .padding(.trailing, 16 + SongTableMetrics.index)
    .frame(minHeight: SongTableMetrics.rowHeight)
    .background(state.inCart ? CapoTheme.accentPlaylists.opacity(0.10) : Color.clear)
    .background(CapoTheme.card)
    .overlay(alignment: .bottom) { CapoTheme.border.opacity(0.6).frame(height: 1) }
    .contentShape(Rectangle())
  }

  private var dash: some View {
    Text("—").capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
  }

  private func cell<Content: View>(width: CGFloat, @ViewBuilder _ content: () -> Content) -> some View {
    content().frame(width: width, alignment: .leading)
  }

  private var titleCell: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      if state.layout.showsOwnerDot, let chip = state.ownership {
        Circle().fill(chip.color).frame(width: 7, height: 7).accessibilityLabel(chip.label)
      }
      Text(item.title).capoText(.sm, weight: .bold).lineLimit(1)
      if let artist = item.artist, !artist.isEmpty {
        Text(artist).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(1)
      }
      if item.hasPendingChanges {
        Circle().fill(CapoTheme.primary).frame(width: 7, height: 7)
          .accessibilityLabel(LibraryStrings.pendingChanges)
      }
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(.trailing, 8)
  }

  @ViewBuilder private var tags: some View {
    let visible = item.tags.prefix(2)
    HStack(spacing: 4) {
      ForEach(visible) { TableTagChip(name: $0.name, colorHex: $0.color) }
      if item.tags.count > visible.count {
        Text(LibraryStrings.moreTags(item.tags.count - visible.count))
          .capoText(.px11).foregroundStyle(CapoTheme.mutedForeground)
      }
    }
    .lineLimit(1)
  }
}

/// Compact-width row (iPhone): title and a meta line on the left, key badge on the right.
struct SongCompactRow: View {
  let item: SongListItem
  let state: SongTableRowState
  let onToggle: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      SongSelectToggle(active: state.inCart, diameter: 32, action: onToggle)
        .frame(width: 44)
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(item.title).capoText(.base, weight: .bold).lineLimit(1)
          if item.hasPendingChanges {
            Circle().fill(CapoTheme.primary).frame(width: 7, height: 7)
              .accessibilityLabel(LibraryStrings.pendingChanges)
          }
        }
        meta
      }
      Spacer(minLength: 8)
      if let key = item.key, !key.isEmpty { KeyBadge(key: key) }
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(.leading, 8)
    .padding(.trailing, 16 + SongTableMetrics.index)
    .padding(.vertical, 8)
    .frame(minHeight: 60)
    .background(state.inCart ? CapoTheme.accentPlaylists.opacity(0.10) : Color.clear)
    .background(CapoTheme.card)
    .overlay(alignment: .bottom) { CapoTheme.border.opacity(0.6).frame(height: 1) }
    .contentShape(Rectangle())
  }

  /// "● Artist · 🐇 96 · ↻ 4× · 1w · #worship"
  private var meta: some View {
    HStack(spacing: 6) {
      if let chip = state.ownership { Circle().fill(chip.color).frame(width: 6, height: 6) }
      if let artist = item.artist, !artist.isEmpty {
        Text(artist).lineLimit(1).foregroundStyle(CapoTheme.mutedForeground)
      }
      if let bpm = item.bpm, bpm > 0 {
        dot
        HStack(spacing: 3) {
          CapoIcon(BPMBadge.icon(bpm), size: 12)
          Text("\(bpm)").monospacedDigit()
        }
        .foregroundStyle(BPMBadge.tone(bpm).0)
      }
      if let played = PlayedBadge.value(item) {
        dot
        HStack(spacing: 3) {
          CapoIcon(.repeat, size: 12)
          Text(played.text).lineLimit(1)
        }
        .foregroundStyle(played.recent ? SongTone.amber() : CapoTheme.mutedForeground)
      }
      if let tag = item.tags.first {
        dot
        Text("#\(tag.name)").lineLimit(1).foregroundStyle(HexColor.tagColor(tag.color))
        if item.tags.count > 1 {
          Text(LibraryStrings.moreTags(item.tags.count - 1)).foregroundStyle(CapoTheme.mutedForeground)
        }
      }
    }
    .capoText(.xs)
    .lineLimit(1)
  }

  private var dot: some View {
    Text("·").foregroundStyle(CapoTheme.mutedForeground)
  }
}

/// Sticky section heading (letter or group name).
struct SongSectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .capoText(.sm, weight: .semibold)
      .foregroundStyle(CapoTheme.mutedForeground)
      .padding(.horizontal, 16)
      .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
      .background(CapoTheme.muted.opacity(0.7))
      .background(CapoTheme.background)
      .overlay(alignment: .bottom) { CapoTheme.border.frame(height: 1) }
      .textCase(nil)
  }
}
