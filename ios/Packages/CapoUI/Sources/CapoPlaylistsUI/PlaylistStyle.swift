import CapoDesign
import CapoIcons
import SwiftUI

extension View {
  /// Themed list: page background, no system chrome, peach tint. Rows draw their own cards.
  func capoList() -> some View {
    scrollContentBackground(.hidden)
      .background(CapoTheme.background)
      .tint(CapoTheme.primary)
      .listStyle(.plain)
  }

  /// A list row that hands its background to the row's own card (web `p-2 space-y-2`).
  func capoCardRow() -> some View {
    listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
  }

  /// `rounded-xl border bg-card shadow-sm`.
  func playlistCard(radius: CGFloat = CapoRadius.xl, fill: Color = CapoTheme.card) -> some View {
    modifier(PlaylistCardStyle(radius: radius, fill: fill))
  }
}

private struct PlaylistCardStyle: ViewModifier {
  @Environment(\.capoUIScale) private var scale
  let radius: CGFloat
  let fill: Color

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius * scale, style: .continuous)
    content
      .background(fill, in: shape)
      .overlay(shape.strokeBorder(CapoTheme.border, lineWidth: 1))
      .shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
  }
}

/// Outline pill with a leading icon (Details row of the detail panel, row meta).
struct PlaylistPill: View {
  let icon: CapoIconName
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      CapoIcon(icon, size: 14)
      Text(text).capoText(.sm, weight: .medium)
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(.horizontal, 12)
    .frame(minHeight: 32)
    .background(CapoTheme.background, in: Capsule())
    .overlay(Capsule().strokeBorder(CapoTheme.input, lineWidth: 1))
  }
}

/// Small muted chip ("Archived").
struct PlaylistChip: View {
  let text: String
  var icon: CapoIconName?

  var body: some View {
    HStack(spacing: 4) {
      if let icon { CapoIcon(icon, size: 10) }
      Text(text).font(CapoFont.ui(10, weight: .medium))
    }
    .foregroundStyle(CapoTheme.mutedForeground)
    .padding(.horizontal, 6)
    .frame(height: 18)
    .background(CapoTheme.muted, in: Capsule())
  }
}
