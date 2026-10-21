import CapoDesign
import SwiftUI

extension View {
  func capoList() -> some View {
    scrollContentBackground(.hidden)
      .background(CapoTheme.background)
      .tint(CapoTheme.primary)
  }

  /// Card-coloured grouped-list row.
  func capoRowBackground() -> some View { listRowBackground(CapoTheme.card) }

  /// Uppercase subtext section header.
  func capoSectionHeader() -> some View {
    font(.system(size: 13, weight: .bold)).tracking(0.8).foregroundStyle(CapoTheme.subtext)
  }
}

/// Role pill: owner peach, admin mauve, member blue, viewer grey.
struct RoleBadge: View {
  let role: TeamRole

  private var color: Color {
    switch role {
    case .owner: CapoTheme.primary
    case .admin: CapoTheme.chord
    case .member: CapoTheme.info
    case .viewer: CapoTheme.subtext
    }
  }

  var body: some View {
    Text(TeamsStrings.roleName(role))
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 10).frame(minHeight: 28)
      .background(color.opacity(0.16), in: Capsule())
  }
}
