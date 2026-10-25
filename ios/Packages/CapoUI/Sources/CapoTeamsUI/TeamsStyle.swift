import CapoDesign
import CapoIcons
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
    capoText(.px12, weight: .bold, tracking: 0.05).foregroundStyle(CapoTheme.subtext)
  }

  /// `rounded-2xl border bg-card p-6` surface used by the team detail sections.
  func teamSurface(border: Color = CapoTheme.border, fill: Color = CapoTheme.card) -> some View {
    padding(24)
      .background(fill, in: RoundedRectangle(cornerRadius: CapoRadius.xxl, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.xxl, style: .continuous).strokeBorder(border, lineWidth: 1))
  }
}

extension TeamRole {
  /// `features/teams/constants.ts`: owner UserLock, admin KeyRound, member User, viewer UserSearch.
  var iconName: CapoIconName {
    switch self {
    case .owner: .userLock
    case .admin: .keyRound
    case .member: .user
    case .viewer: .userSearch
    }
  }

  /// Top bar / icon tint of the team card: owner primary, admin songs accent, the rest activity accent.
  var cardAccent: Color {
    switch self {
    case .owner: CapoTheme.primary
    case .admin: CapoTheme.accentSongs
    case .member, .viewer: CapoTheme.accentActivity
    }
  }
}

/// Outline role pill: role icon + label, 10 px text (web `RoleBadge`).
struct RoleBadge: View {
  let role: TeamRole

  var body: some View {
    HStack(spacing: 4) {
      CapoIcon(role.iconName, size: 12)
      Text(TeamsStrings.roleName(role)).capoText(.px10, weight: .medium)
    }
    .foregroundStyle(CapoTheme.text)
    .padding(.horizontal, 8).frame(height: 20)
    .overlay(Capsule().strokeBorder(CapoTheme.border, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }
}

/// Filled status pill (web `Badge` default / secondary): "Active", "Public", "Private".
struct StatusPill: View {
  let text: String
  var prominent = false

  var body: some View {
    Text(text)
      .capoText(.xs, weight: .medium)
      .foregroundStyle(prominent ? CapoTheme.primaryForeground : CapoTheme.text)
      .padding(.horizontal, 8).frame(height: 22)
      .background(prominent ? CapoTheme.primary : CapoTheme.accent, in: Capsule())
  }
}

/// Rounded tile with a team's stored lucide icon, tinted with the role colour.
struct TeamIconTile: View {
  let icon: String?
  var tint: Color
  var size: CGFloat = 36
  var iconSize: CGFloat = 20
  var ring = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: CapoRadius.base, style: .continuous)
    CapoIcon.named(icon, size: iconSize)
      .foregroundStyle(CapoTheme.text)
      .frame(width: size, height: size)
      .background(tint.opacity(0.1), in: shape)
      .overlay(shape.strokeBorder(tint.opacity(0.2), lineWidth: 1))
      .overlay { if ring { shape.inset(by: -3).strokeBorder(tint.opacity(0.5), lineWidth: 3) } }
  }
}
