import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

/// Web `team-card.tsx`: 4 px role-coloured bar, tinted icon tile, name link, status pills, member count
/// and a leave (or, for the owner, delete) action.
struct TeamCard: View {
  let item: TeamWithRole
  let isActive: Bool
  let memberCount: Int?
  var onIconTap: () -> Void
  var onLeaveOrDelete: () -> Void

  private var accent: Color { item.role.cardAccent }
  private var canEditIcon: Bool { item.role.canManageMembers }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: CapoRadius.xl, style: .continuous)
    VStack(spacing: 0) {
      Rectangle().fill(accent).frame(height: 4)
      VStack(alignment: .leading, spacing: 0) {
        header
        HStack(spacing: 8) {
          RoleBadge(role: item.role)
          if item.team.isPublic { StatusPill(text: L10n.Filters.public) }
        }
        .padding(.top, 4)
        Divider().overlay(CapoTheme.border).padding(.vertical, 8)
        footer
      }
      .padding(24)
    }
    .background(CapoTheme.card, in: shape)
    .clipShape(shape)
    .overlay(shape.strokeBorder(isActive ? CapoTheme.primary : CapoTheme.border, lineWidth: isActive ? 2 : 1))
    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 8) {
      HStack(spacing: 12) {
        Button(action: onIconTap) {
          TeamIconTile(icon: item.team.icon, tint: accent, ring: isActive)
        }
        .buttonStyle(.plain)
        .disabled(!canEditIcon)
        .accessibilityLabel(TeamsStrings.iconPickerTitle)
        NavigationLink(value: item) {
          Text(item.team.name)
            .capoText(.lg, weight: .bold, tracking: -0.025)
            .foregroundStyle(CapoTheme.text)
            .lineLimit(1)
            .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
      }
      Spacer(minLength: 8)
      if isActive { StatusPill(text: L10n.Teams.active, prominent: true) }
    }
  }

  private var footer: some View {
    HStack {
      HStack(spacing: 4) {
        CapoIcon(.users, size: 16)
        if let memberCount { Text(TeamsStrings.memberCount(memberCount)) }
      }
      .capoText(.sm)
      .foregroundStyle(CapoTheme.subtext)
      Spacer()
      Button(action: onLeaveOrDelete) {
        CapoIcon(item.role == .owner ? .trash2 : .logOut, size: 16)
          .foregroundStyle(CapoTheme.destructive)
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(item.role == .owner ? L10n.Teams.deleteTeam : L10n.Teams.leaveTeam)
    }
  }
}
