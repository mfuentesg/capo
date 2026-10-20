import CapoCore
import CapoDesign
import Foundation

/// Copy for the Teams screens. Existing web keys come from `L10n`; the rest are iOS-only
/// fallbacks until the generator learns them.
enum TeamsStrings {
  static var title: String { L10n.Teams.title }
  static var roleOwner: String { String(localized: "ios.teams.roleOwner", defaultValue: "Owner") }  // TODO(i18n)

  static func roleName(_ role: TeamRole) -> String {
    switch role {
    case .owner: roleOwner
    case .admin: L10n.Teams.roleAdmin
    case .member: L10n.Teams.roleMember
    case .viewer: L10n.Teams.roleViewer
    }
  }

  static var offline: String {  // TODO(i18n)
    String(
      localized: "ios.teams.offline", defaultValue: "You are offline. Team changes need a connection.")
  }
  static var icon: String { String(localized: "ios.teams.icon", defaultValue: "Icon (emoji)") }  // TODO(i18n)
  static var email: String { String(localized: "ios.teams.email", defaultValue: "Email") }  // TODO(i18n)
  static var role: String { String(localized: "ios.teams.role", defaultValue: "Role") }  // TODO(i18n)
  static var noInvitations: String {  // TODO(i18n)
    String(localized: "ios.teams.noInvitations", defaultValue: "No pending invitations")
  }
  static var decline: String { String(localized: "ios.teams.decline", defaultValue: "Decline") }  // TODO(i18n)
  static var shareTitle: String {  // TODO(i18n)
    String(localized: "ios.teams.shareTitle", defaultValue: "Share setlist")
  }
  static var shareHint: String {  // TODO(i18n)
    String(
      localized: "ios.teams.shareHint",
      defaultValue: "Anyone with this link can view the setlist.")
  }
  static var shareLink: String {  // TODO(i18n)
    String(localized: "ios.teams.shareLink", defaultValue: "Share link")
  }
  static var retry: String { String(localized: "ios.teams.retry", defaultValue: "Try again") }  // TODO(i18n)
  static var cancel: String { L10n.Common.cancel }
}
