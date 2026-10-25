import CapoDesign
import CapoIcons
import SwiftUI

/// Ownership chip shown in the "All" view (web `song-item.tsx`): "Me" or the team name.
struct OwnershipChip: Equatable {
  let label: String
  /// Stored lucide name of the team icon; nil renders the colour dot.
  let icon: String?
  let color: Color
}

/// One library row, exactly the web `SongItem`: 44 px cart toggle, bold title, artist + ownership
/// chip, then key / BPM / frequency / tag badges. Rounded-xl card, selected = accent-songs/8 + ring.
struct SongRow: View {
  let item: SongListItem
  var showsSelection: Bool = false
  var isSelected: Bool = false
  var inCart: Bool = false
  var ownership: OwnershipChip?
  var onToggleCart: (() -> Void)?

  @Environment(\.capoUIScale) private var scale
  private var card: RoundedRectangle { RoundedRectangle(cornerRadius: CapoRadius.xl * scale, style: .continuous) }

  var body: some View {
    let highlighted = isSelected && !showsSelection
    HStack(spacing: 12) {
      cartToggle
      VStack(alignment: .leading, spacing: 4) {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 8) {
            Text(item.title).capoText(.sm, weight: .bold).lineLimit(1)
            if item.hasPendingChanges {
              Circle().fill(CapoTheme.primary).frame(width: 8, height: 8)
                .accessibilityLabel(LibraryStrings.pendingChanges)
            }
          }
          HStack(spacing: 6) {
            if let artist = item.artist, !artist.isEmpty {
              Text(artist).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(1)
            }
            if let ownership { OwnerChipView(chip: ownership) }
          }
        }
        badges
      }
      Spacer(minLength: 0)
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(highlighted ? CapoTheme.accentSongs.opacity(0.08) : Color.clear, in: card)
    .background(CapoTheme.card, in: card)
    .overlay(card.strokeBorder(highlighted ? CapoTheme.accentSongs.opacity(0.5) : Color.clear, lineWidth: 2))
    .shadow(color: .black.opacity(highlighted ? 0.12 : 0.06), radius: highlighted ? 4 : 1.5, y: highlighted ? 2 : 1)
    .contentShape(card)
  }

  // MARK: Cart toggle

  @ViewBuilder private var cartToggle: some View {
    let active = showsSelection ? isSelected : inCart
    let circle = ZStack {
      Circle().fill(active ? CapoTheme.accentPlaylists : CapoTheme.accentSongs.opacity(0.12))
      CapoIcon(active ? .check : .plus, size: 16)
        .foregroundStyle(active ? Color.white : CapoTheme.accentSongs)
    }
    .frame(width: 44, height: 44)
    if let onToggleCart, !showsSelection {
      Button(action: onToggleCart) { circle }
        .buttonStyle(CartToggleStyle())
        .accessibilityLabel(inCart ? LibraryStrings.removeFromCart : LibraryStrings.addToCart)
    } else {
      circle.accessibilityHidden(true)
    }
  }

  // MARK: Badges

  private var badges: some View {
    FlowLayout(spacing: 6) {
      if let key = item.key, !key.isEmpty {
        KeyBadge(key: key)
      }
      if let bpm = item.bpm, bpm > 0 { BPMBadge(bpm: bpm) }
      PlayedBadge(item: item)
      ForEach(item.tags.prefix(3)) { SongRowTag(name: $0.name, colorHex: $0.color) }
      if item.tags.count > 3 {
        Text(LibraryStrings.moreTags(item.tags.count - 3))
          .capoText(.px11).foregroundStyle(CapoTheme.mutedForeground)
      }
    }
  }
}

/// `active:scale-90`.
private struct CartToggleStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : 1)
      .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
  }
}

/// Compact tag chip for list rows: coloured dot plus name on a tinted fill.
struct SongRowTag: View {
  let name: String
  let colorHex: String?

  var body: some View {
    let color = HexColor.tagColor(colorHex)
    HStack(spacing: 5) {
      Circle().fill(color).frame(width: 7, height: 7)
      Text(name).lineLimit(1)
    }
    .capoText(.px11, weight: .medium)
    .foregroundStyle(CapoTheme.foreground)
    .padding(.horizontal, 8)
    .frame(height: 22)
    .background(color.opacity(0.16), in: Capsule())
  }
}
