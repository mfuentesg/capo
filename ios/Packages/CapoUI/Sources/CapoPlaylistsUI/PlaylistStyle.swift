import CapoDesign
import SwiftUI

extension View {
  /// Catppuccin list: themed background, no system chrome, peach tint.
  func capoList() -> some View {
    scrollContentBackground(.hidden)
      .background(CapoTheme.background)
      .tint(CapoTheme.primary)
      .listRowSpacing(6)
  }

  /// Card-style list row: rounded card on the page background, 48pt minimum.
  func capoCardRow() -> some View {
    listRowSeparator(.hidden)
      .listRowBackground(
        RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous)
          .fill(CapoTheme.card)
          .overlay(
            RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous)
              .strokeBorder(CapoTheme.border.opacity(0.6), lineWidth: 1))
          .padding(.vertical, 2))
  }
}
