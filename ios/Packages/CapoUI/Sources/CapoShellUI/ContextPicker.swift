import CapoDesign
import CapoIcons
import SwiftUI

enum ContextStrings {
  static var personal: String { L10n.Ios.Shell.Context.personal }
  static var invitations: String { L10n.Ios.Shell.invitations }
  static var conflicts: String { L10n.Ios.Shell.conflicts }
  static var signOut: String { L10n.Ios.Shell.signOutButton }
  static var settings: String { L10n.Ios.Shell.settings }
  static var done: String { L10n.Ios.Shell.done }
  static func syncNow() -> String { L10n.Ios.Shell.syncNow }
}

/// What the context pill shows for the current selection (web `context-pill.tsx`).
struct ContextPillState: Equatable {
  enum Kind: Equatable { case all, personal, team }

  let kind: Kind
  let label: String
  /// A team is selected: the pill gets the accent tint, like the web's non-"All" state.
  let isFiltered: Bool
  let teamID: TeamID?

  /// Label truncation widths from the web: 80 pt, 120 pt from `sm` up.
  static func maxLabelWidth(compact: Bool) -> CGFloat { compact ? 80 : 120 }

  static func make(context: AppContext, team: Team?, personalName: String?) -> ContextPillState {
    switch context {
    case .all:
      return ContextPillState(kind: .all, label: L10n.Nav.viewAll, isFiltered: false, teamID: nil)
    case .personal:
      let name = personalName?.trimmingCharacters(in: .whitespacesAndNewlines)
      let label = (name?.isEmpty == false ? name : nil) ?? ContextStrings.personal
      return ContextPillState(kind: .personal, label: label, isFiltered: true, teamID: nil)
    case .team(let id):
      return ContextPillState(
        kind: .team, label: team?.name ?? ContextStrings.personal, isFiltered: true, teamID: id)
    }
  }
}

extension ShellModel {
  var pillState: ContextPillState {
    ContextPillState.make(
      context: context, team: contextStore.selectedTeam, personalName: session.fullName)
  }

  var hasTeams: Bool { !contextStore.teams.isEmpty }
}

/// Context switcher pill of the top bar.
struct ContextPill: View {
  let model: ShellModel
  @State private var open = false

  var body: some View {
    let state = model.pillState
    Button { open = true } label: { label(state) }
      .buttonStyle(.plain)
      .accessibilityLabel(state.label)
      .popover(isPresented: $open) {
        ContextPopover(model: model) { open = false }
          .presentationCompactAdaptation(.popover)
      }
  }

  /// "All" with teams shows two overlapping 20 px avatars (user, first team); without teams the
  /// Layers glyph. Otherwise one avatar.
  @ViewBuilder
  private func leading(_ state: ContextPillState, size: CGFloat) -> some View {
    switch state.kind {
    case .all where model.hasTeams:
      HStack(spacing: -size * 0.3) {
        ContextAvatar(model: model, teamID: nil, size: size)
        ContextAvatar(model: model, teamID: model.contextStore.teams.first?.id, size: size)
      }
    case .all:
      CapoIcon(.layers, size: 14).foregroundStyle(CapoTheme.foreground)
        .frame(width: size, height: size)
    default:
      ContextAvatar(model: model, teamID: state.teamID, size: size)
    }
  }

  private func label(_ state: ContextPillState) -> some View {
    HStack(spacing: 6) {
      leading(state, size: 20)
      Text(state.label)
        .capoText(.xs, weight: .medium)
        .lineLimit(1)
        .frame(maxWidth: ContextPillState.maxLabelWidth(compact: true), alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
      CapoIcon(.chevronDown, size: 12).foregroundStyle(CapoTheme.mutedForeground)
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(.horizontal, 10)
    .frame(height: 32)
    .background(state.isFiltered ? CapoTheme.accent.opacity(0.6) : Color.clear, in: Capsule())
    .frame(minHeight: CapoMetrics.minTouchTarget)
    .contentShape(Capsule())
  }
}

/// Avatar for the user (photo or the web's `CircleUserRound` fallback) or a team (photo or its
/// stored lucide icon on a primary tint). `teamID == nil` is the user.
struct ContextAvatar: View {
  let model: ShellModel
  let teamID: TeamID?
  var size: CGFloat
  /// The ring that separates overlapping avatars (`ring-2 ring-background`).
  var ringed = true

  var body: some View {
    if let teamID, let team = model.contextStore.teams.first(where: { $0.id == teamID })?.team {
      ProfileAvatar(
        url: team.avatarURL.flatMap(URL.init(string:)), teamIcon: team.icon ?? "Users", size: size,
        ringed: ringed)
    } else {
      ProfileAvatar(url: model.session.avatarURL, teamIcon: nil, size: size, ringed: ringed)
    }
  }
}

/// Round avatar (web `Avatar`): image if any, else `CircleUserRound` on `primary/10` for users or
/// the team's lucide icon on `primary/20` for teams.
struct ProfileAvatar: View {
  let url: URL?
  /// Stored lucide name for team avatars; nil for the user.
  let teamIcon: String?
  var size: CGFloat
  var ringed = false

  var body: some View {
    ZStack {
      Circle().fill(CapoTheme.primary.opacity(teamIcon == nil ? 0.10 : 0.20))
      if let teamIcon {
        CapoIcon.named(teamIcon, size: max(12, size * 0.5)).foregroundStyle(CapoTheme.primary)
      } else {
        CapoIcon(.circleUserRound, size: size * 0.6).foregroundStyle(CapoTheme.foreground)
      }
      if let url {
        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .overlay { if ringed { Circle().strokeBorder(CapoTheme.background, lineWidth: 2).padding(-1) } }
    .accessibilityHidden(true)
  }
}

/// Popover content: "Filter view" caption, All / Personal / team rows, "Manage teams" footer.
private struct ContextPopover: View {
  let model: ShellModel
  let dismiss: () -> Void

  var body: some View {
    let personal = AppContext.personal(userID: model.session.userID)
    let all = AppContext.all(userID: model.session.userID)
    VStack(alignment: .leading, spacing: 2) {
      Text(L10n.Nav.filterContext)
        .capoText(.xs, weight: .semibold)
        .foregroundStyle(CapoTheme.mutedForeground)
        .padding(.horizontal, 8).padding(.vertical, 4)
      if model.hasTeams {
        row(
          avatar: AnyView(
            CapoIcon(.layers, size: 16).foregroundStyle(CapoTheme.foreground)
              .frame(width: 32, height: 32)
              .background(CapoTheme.primary.opacity(0.10), in: Circle())),
          title: L10n.Nav.viewAll, subtitle: L10n.Nav.viewAllDescription,
          selected: model.context == all
        ) { model.select(all) }
      }
      row(
        avatar: AnyView(ContextAvatar(model: model, teamID: nil, size: 32, ringed: false)),
        title: model.session.fullName ?? ContextStrings.personal,
        subtitle: L10n.Nav.personalAccount, selected: model.context == personal
      ) { model.select(personal) }
      ForEach(model.contextStore.teams) { entry in
        row(
          avatar: AnyView(ContextAvatar(model: model, teamID: entry.id, size: 32, ringed: false)),
          title: entry.team.name, subtitle: nil, selected: model.context.teamID == entry.id
        ) { model.select(.team(teamID: entry.id)) }
      }
      CapoTheme.border.frame(height: 1).padding(.top, 4)
      Button {
        model.navigation.open(.teams)
        dismiss()
      } label: {
        Text(L10n.Nav.manageTeams)
          .capoText(.sm, weight: .medium)
          .foregroundStyle(CapoTheme.foreground)
          .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget, alignment: .leading)
          .padding(.horizontal, 8)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(8)
    .frame(width: 256)
    .background(CapoTheme.popover)
  }

  private func row(
    avatar: AnyView, title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button {
      action()
      dismiss()
    } label: {
      HStack(spacing: 12) {
        avatar
        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 6) {
            Text(title).capoText(.sm, weight: .medium).lineLimit(1)
            if selected { CapoIcon(.check, size: 16).foregroundStyle(CapoTheme.primary) }
          }
          if let subtitle {
            Text(subtitle).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(2)
          }
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(CapoTheme.foreground)
      .padding(.horizontal, 8)
      .frame(minHeight: CapoMetrics.minTouchTarget + 4)
      .background(selected ? CapoTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct SyncButton: View {
  let model: ShellModel

  var body: some View {
    Button {
      model.syncNow(.manual)
    } label: {
      SyncStatusBadge(status: model.syncStatus)
        .frame(minWidth: CapoMetrics.minTouchTarget, minHeight: CapoMetrics.minTouchTarget)
    }
    .accessibilityHint(ContextStrings.syncNow())
  }
}
