import CapoDesign
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
  let label: String
  /// A team is selected: the pill gets the accent tint, like the web's non-"All" state.
  let isFiltered: Bool
  let teamID: TeamID?

  /// Label truncation widths from the web: 80 pt, 120 pt from `sm` up.
  static func maxLabelWidth(compact: Bool) -> CGFloat { compact ? 80 : 120 }

  static func make(context: AppContext, team: Team?, personalName: String?) -> ContextPillState {
    switch context {
    case .personal:
      let name = personalName?.trimmingCharacters(in: .whitespacesAndNewlines)
      let label = (name?.isEmpty == false ? name : nil) ?? ContextStrings.personal
      return ContextPillState(label: label, isFiltered: false, teamID: nil)
    case .team(let id):
      return ContextPillState(label: team?.name ?? ContextStrings.personal, isFiltered: true, teamID: id)
    }
  }
}

extension ShellModel {
  var pillState: ContextPillState {
    ContextPillState.make(
      context: context, team: contextStore.selectedTeam, personalName: session.fullName)
  }
}

/// Context switcher. `compact` is the iPhone toolbar pill; `sidebar` fills the expanded sidebar;
/// `rail` is the round button in the collapsed sidebar.
struct ContextPill: View {
  enum Style { case compact, sidebar, rail }

  let model: ShellModel
  var style: Style = .compact
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

  @ViewBuilder
  private func label(_ state: ContextPillState) -> some View {
    switch style {
    case .rail:
      ContextAvatar(model: model, teamID: state.teamID, size: 36)
        .frame(width: 56, height: 56)
        .background(state.isFiltered ? CapoTheme.selection : CapoTheme.card, in: Circle())
        .overlay(Circle().strokeBorder(CapoTheme.border, lineWidth: 1))
    case .compact:
      HStack(spacing: 6) {
        ContextAvatar(model: model, teamID: state.teamID, size: 22)
        Text(state.label)
          .font(CapoFont.style(.footnote, weight: .medium))
          .lineLimit(1)
          .frame(maxWidth: ContextPillState.maxLabelWidth(compact: true), alignment: .leading)
        Image(systemName: "chevron.down").font(CapoFont.style(.caption2)).foregroundStyle(CapoTheme.subtext)
      }
      .foregroundStyle(CapoTheme.text)
      .padding(.horizontal, 10)
      .frame(minHeight: CapoMetrics.minTouchTarget)
      .background(state.isFiltered ? CapoTheme.selection : Color.clear, in: Capsule())
      .contentShape(Capsule())
    case .sidebar:
      HStack(spacing: 10) {
        ContextAvatar(model: model, teamID: state.teamID, size: 28)
        Text(state.label)
          .font(CapoFont.style(.subheadline, weight: .medium))
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: 0)
        Image(systemName: "chevron.down").font(CapoFont.style(.caption)).foregroundStyle(CapoTheme.subtext)
      }
      .foregroundStyle(CapoTheme.text)
      .padding(.horizontal, 12)
      .frame(minHeight: CapoMetrics.minTouchTarget + 4)
      .background(
        state.isFiltered ? CapoTheme.selection : CapoTheme.card,
        in: RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous)
          .strokeBorder(CapoTheme.border, lineWidth: 1))
      .contentShape(RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous))
    }
  }
}

/// Avatar for personal (profile photo or initial) or a team (emoji icon or initial).
struct ContextAvatar: View {
  let model: ShellModel
  let teamID: TeamID?
  var size: CGFloat

  var body: some View {
    if let teamID, let team = model.contextStore.teams.first(where: { $0.id == teamID })?.team {
      InitialAvatar(url: team.avatarURL.flatMap(URL.init(string:)), text: team.icon ?? team.name, size: size, tinted: true)
    } else {
      InitialAvatar(
        url: model.session.avatarURL, text: model.session.fullName ?? model.session.email ?? "?",
        size: size, tinted: false)
    }
  }
}

struct InitialAvatar: View {
  let url: URL?
  let text: String
  var size: CGFloat
  var tinted: Bool

  var body: some View {
    ZStack {
      Circle().fill(tinted ? CapoTheme.primary.opacity(0.2) : CapoTheme.surface)
      Text(Self.initial(text))
        .font(CapoFont.ui(size * 0.45, weight: .semibold))
        .foregroundStyle(tinted ? CapoTheme.primary : CapoTheme.subtext)
      if let url {
        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .accessibilityHidden(true)
  }

  static func initial(_ text: String) -> String {
    guard let first = text.trimmingCharacters(in: .whitespaces).first else { return "?" }
    return String(first).uppercased()
  }
}

/// Popover content: "Filter view" caption, Personal and team rows, "Manage teams" footer.
private struct ContextPopover: View {
  let model: ShellModel
  let dismiss: () -> Void

  var body: some View {
    let personal = AppContext.personal(userID: model.session.userID)
    VStack(alignment: .leading, spacing: 2) {
      Text(L10n.Nav.filterContext)
        .font(CapoFont.style(.caption, weight: .semibold))
        .foregroundStyle(CapoTheme.subtext)
        .padding(.horizontal, 8).padding(.vertical, 4)
      row(
        avatar: ContextAvatar(model: model, teamID: nil, size: 32), title: model.session.fullName ?? ContextStrings.personal,
        subtitle: L10n.Nav.personalAccount, selected: model.context == personal
      ) { model.select(personal) }
      ForEach(model.contextStore.teams) { entry in
        row(
          avatar: ContextAvatar(model: model, teamID: entry.id, size: 32), title: entry.team.name,
          subtitle: nil, selected: model.context.teamID == entry.id
        ) { model.select(.team(teamID: entry.id)) }
      }
      CapoTheme.border.frame(height: 1).padding(.top, 4)
      Button {
        model.navigation.open(.teams)
        dismiss()
      } label: {
        Text(L10n.Nav.manageTeams)
          .font(CapoFont.style(.subheadline, weight: .medium))
          .foregroundStyle(CapoTheme.text)
          .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget, alignment: .leading)
          .padding(.horizontal, 8)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(8)
    .frame(width: 288)
    .background(CapoTheme.card)
  }

  private func row(
    avatar: ContextAvatar, title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button {
      action()
      dismiss()
    } label: {
      HStack(spacing: 12) {
        avatar
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(CapoFont.style(.subheadline, weight: .medium)).lineLimit(1)
          if let subtitle {
            Text(subtitle).font(CapoFont.style(.caption)).foregroundStyle(CapoTheme.subtext).lineLimit(1)
          }
        }
        if selected {
          Image(systemName: "checkmark").font(CapoFont.ui(14, weight: .semibold)).foregroundStyle(CapoTheme.primary)
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(CapoTheme.text)
      .padding(.horizontal, 8)
      .frame(minHeight: CapoMetrics.minTouchTarget + 4)
      .background(selected ? CapoTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
