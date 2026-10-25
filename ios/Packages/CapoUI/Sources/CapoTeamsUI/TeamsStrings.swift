import CapoCore
import CapoDesign
import Foundation

/// Copy for the Teams screens. Existing web keys come from `L10n`; the rest are iOS-only
/// fallbacks until the generator learns them.
enum TeamsStrings {
  static var title: String { L10n.Teams.title }
  static var roleOwner: String { L10n.Ios.Teams.roleOwner }

  static func roleName(_ role: TeamRole) -> String {
    switch role {
    case .owner: roleOwner
    case .admin: L10n.Teams.roleAdmin
    case .member: L10n.Teams.roleMember
    case .viewer: L10n.Teams.roleViewer
    }
  }

  static var offline: String {
    L10n.Ios.Teams.offline
  }
  static var icon: String { L10n.Ios.Teams.icon }
  static var email: String { L10n.Ios.Teams.email }
  static var role: String { L10n.Ios.Teams.role }
  static var noInvitations: String {
    L10n.Ios.Teams.noInvitations
  }
  static var decline: String { L10n.Ios.Teams.decline }
  static var shareTitle: String {
    L10n.Ios.Teams.shareTitle
  }
  static var shareHint: String {
    L10n.Ios.Teams.shareHint
  }
  static var shareLink: String {
    L10n.Ios.Teams.shareLink
  }
  static var searchTeams: String { L10n.Ios.Teams.searchTeams }
  static var iconPickerTitle: String { L10n.Ios.Teams.iconPickerTitle }
  static var noTeamMatches: String { L10n.Ios.Teams.noTeamMatches }
  static var transferNoTeams: String { L10n.Ios.Teams.transferNoTeams }
  static func memberCount(_ count: Int) -> String {
    count == 1 ? L10n.Ios.Teams.memberCountOne : L10n.Ios.Teams.memberCount(count: String(count))
  }
  static var retry: String { L10n.Ios.Teams.retry }
  static var cancel: String { L10n.Common.cancel }
}
