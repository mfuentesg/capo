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
    String(localized: "ios.shell.context.personal", defaultValue: "Personal", bundle: .capoDesign)  // TODO(i18n)
  }
  static var teams: String {
    String(localized: "ios.shell.teams", defaultValue: "Teams", bundle: .capoDesign)  // TODO(i18n)
  }
  static var invitations: String {
    String(localized: "ios.shell.invitations", defaultValue: "Invitations", bundle: .capoDesign)  // TODO(i18n)
  }
  static var conflicts: String {
    String(localized: "ios.shell.conflicts", defaultValue: "Conflicts", bundle: .capoDesign)  // TODO(i18n)
  }
  static var signOut: String {
    String(localized: "ios.shell.signOut", defaultValue: "Sign out", bundle: .capoDesign)  // TODO(i18n)
  }
  static var library: String {
    String(localized: "ios.shell.library", defaultValue: "Library", bundle: .capoDesign)  // TODO(i18n)
  }
  static var setlists: String {
    String(localized: "ios.shell.setlists", defaultValue: "Setlists", bundle: .capoDesign)  // TODO(i18n)
  }
  static var settings: String {
    String(localized: "ios.shell.settings", defaultValue: "Settings", bundle: .capoDesign)  // TODO(i18n)
  }
  static var done: String {
    String(localized: "ios.shell.done", defaultValue: "Done", bundle: .capoDesign)  // TODO(i18n)
  }
  static func syncNow() -> String {
    String(localized: "ios.shell.syncNow", defaultValue: "Sync now", bundle: .capoDesign)  // TODO(i18n)
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
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Image(systemName: "chevron.up.chevron.down").font(.caption2)
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
