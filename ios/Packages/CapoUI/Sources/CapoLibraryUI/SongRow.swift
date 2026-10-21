import CapoDesign
import SwiftUI

/// One library row: title, artist, key badge, bpm, up to three tag chips and a pending dot.
struct SongRow: View {
  let item: SongListItem
  var showsSelection: Bool = false
  var isSelected: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      if showsSelection {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? CapoTheme.primary : CapoTheme.subtext)
      }
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 8) {
          Text(item.title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
          if item.hasPendingChanges {
            Circle().fill(CapoTheme.primary).frame(width: 8, height: 8)
              .accessibilityLabel(LibraryStrings.pendingChanges)
          }
        }
        if let artist = item.artist, !artist.isEmpty {
          Text(artist).font(.system(size: 14)).foregroundStyle(CapoTheme.subtext).lineLimit(1)
        }
        if !item.tags.isEmpty {
          HStack(spacing: 5) {
            ForEach(item.tags.prefix(3)) { SongRowTag(name: $0.name, colorHex: $0.color) }
            if item.tags.count > 3 {
              Text(LibraryStrings.moreTags(item.tags.count - 3))
                .font(.caption).foregroundStyle(CapoTheme.subtext)
            }
          }
        }
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 6) {
        if let key = item.key, !key.isEmpty { KeyBadge(key) }
        if let bpm = item.bpm, bpm > 0 {
          Text(LibraryStrings.bpm(bpm)).font(.system(size: 13)).foregroundStyle(CapoTheme.subtext)
        }
      }
    }
    .foregroundStyle(CapoTheme.text)
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(minHeight: 80)
    .background(
      CapoTheme.card,
      in: RoundedRectangle(cornerRadius: CapoRadius.medium + 2, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: CapoRadius.medium + 2, style: .continuous)
        .strokeBorder(isSelected ? CapoTheme.primary : Color.clear, lineWidth: 2)
    )
    .contentShape(Rectangle())
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
    .font(.system(size: 11, weight: .medium))
    .foregroundStyle(CapoTheme.text)
    .padding(.horizontal, 8)
    .frame(height: 20)
    .background(color.opacity(0.16), in: Capsule())
  }
}
