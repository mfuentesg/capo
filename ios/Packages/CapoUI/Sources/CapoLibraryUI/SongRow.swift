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
          .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
      }
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(item.title).font(.headline).lineLimit(1)
          if item.hasPendingChanges {
            Circle().fill(.orange).frame(width: 8, height: 8)
              .accessibilityLabel(LibraryStrings.pendingChanges)
          }
        }
        if let artist = item.artist, !artist.isEmpty {
          Text(artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
        if !item.tags.isEmpty {
          HStack(spacing: 4) {
            ForEach(item.tags.prefix(3)) { TagChip(name: $0.name, colorHex: $0.color) }
            if item.tags.count > 3 {
              Text(LibraryStrings.moreTags(item.tags.count - 3))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 4) {
        if let key = item.key, !key.isEmpty {
          Text(key)
            .font(.subheadline.weight(.semibold).monospaced())
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        if let bpm = item.bpm, bpm > 0 {
          Text(LibraryStrings.bpm(bpm)).font(.caption).foregroundStyle(.secondary)
        }
      }
    }
    .frame(minHeight: 56)
    .contentShape(Rectangle())
  }
}
