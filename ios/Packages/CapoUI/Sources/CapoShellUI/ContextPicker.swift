import CapoDesign
import SwiftUI

/// Rows for Personal plus each team, used in the compact menu and the regular sidebar.
struct ContextRows: View {
  let model: ShellModel

  var body: some View {
    let personal = AppContext.personal(userID: model.session.userID)
    Button {
      model.select(personal)
    } label: {
      if model.context == personal {
        Label(ContextStrings.personal, systemImage: "checkmark")
      } else {
        Label(ContextStrings.personal, systemImage: "person")
      }
    }
    ForEach(model.contextStore.teams) { entry in
      Button {
        model.select(.team(teamID: entry.id))
      } label: {
        let title = [entry.team.icon, entry.team.name].compactMap { $0 }.joined(separator: " ")
        if model.context.teamID == entry.id {
          Label(title, systemImage: "checkmark")
        } else {
          Label(title, systemImage: "person.2")
        }
      }
    }
  }
}

enum ContextStrings {
  static var personal: String {
    L10n.Ios.Shell.Context.personal
  }
  static var teams: String {
    L10n.Ios.Shell.teams
  }
  static var invitations: String {
    L10n.Ios.Shell.invitations
  }
  static var conflicts: String {
    L10n.Ios.Shell.conflicts
  }
  static var signOut: String {
    L10n.Ios.Shell.signOutButton
  }
  static var library: String {
    L10n.Ios.Shell.library
  }
  static var setlists: String {
    L10n.Ios.Shell.setlists
  }
  static var settings: String {
    L10n.Ios.Shell.settings
  }
  static var done: String {
    L10n.Ios.Shell.done
  }
  static func syncNow() -> String {
    L10n.Ios.Shell.syncNow
  }
}

/// Compact-width toolbar pill: current context, with switcher, teams, conflicts and sign-out.
struct ContextPill: View {
  let model: ShellModel

  var body: some View {
    Menu {
      ContextRows(model: model)
      Divider()
      Button(ContextStrings.teams, systemImage: "person.3") { model.navigation.showTeams = true }
      Button(ContextStrings.invitations, systemImage: "envelope") { model.navigation.showInvitations = true }
      if model.conflictCount > 0 {
        Button("\(ContextStrings.conflicts) (\(model.conflictCount))", systemImage: "exclamationmark.triangle") {
          model.navigation.showConflicts = true
        }
      }
      Divider()
      Button(ContextStrings.signOut, systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
        model.navigation.showSignOut = true
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: model.context.teamID == nil ? "person.fill" : "person.2.fill")
        Text(model.contextStore.selectedTeam?.name ?? ContextStrings.personal)
          .font(CapoFont.style(.subheadline, weight: .semibold))
          .lineLimit(1)
        Image(systemName: "chevron.up.chevron.down").font(CapoFont.style(.caption2))
      }
      .frame(minHeight: CapoMetrics.minTouchTarget)
    }
    .accessibilityLabel(model.contextStore.selectedTeam?.name ?? ContextStrings.personal)
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
