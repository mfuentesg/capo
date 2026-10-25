import Foundation

public enum TeamRole: String, Codable, Sendable, CaseIterable {
  case owner, admin, member, viewer

  public var canEditContent: Bool { self != .viewer }
  public var canManageMembers: Bool { self == .owner || self == .admin }
  /// RLS: team songs and playlists are deleted by admins and owners only.
  public var canDeleteContent: Bool { self == .owner || self == .admin }
}

/// Roles of the signed-in user per team, so permissions follow the item's own bucket instead of
/// the view filter. Personal items (`teamID == nil`) are always fully editable.
public struct TeamRoles: Sendable, Equatable {
  public var roles: [TeamID: TeamRole]

  public init(_ roles: [TeamID: TeamRole] = [:]) { self.roles = roles }

  public func canEdit(teamID: TeamID?) -> Bool {
    guard let teamID else { return true }
    return roles[teamID]?.canEditContent ?? false
  }

  public func canDelete(teamID: TeamID?) -> Bool {
    guard let teamID else { return true }
    return roles[teamID]?.canDeleteContent ?? false
  }

  public func canEdit(in context: AppContext) -> Bool { canEdit(teamID: context.teamID) }
}

public struct Team: Identifiable, Hashable, Sendable, Codable {
  public var id: TeamID
  public var name: String
  public var icon: String?
  public var avatarURL: String?
  public var isPublic: Bool
  public var createdBy: UserID
  public var createdAt: ServerTimestamp
  public var updatedAt: ServerTimestamp

  public init(
    id: TeamID, name: String, icon: String?, avatarURL: String?, isPublic: Bool,
    createdBy: UserID, createdAt: ServerTimestamp, updatedAt: ServerTimestamp
  ) {
    self.id = id
    self.name = name
    self.icon = icon
    self.avatarURL = avatarURL
    self.isPublic = isPublic
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct TeamMembership: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID
  public var teamID: TeamID
  public var userID: UserID
  public var role: TeamRole
  public var joinedAt: ServerTimestamp

  public init(id: UUID, teamID: TeamID, userID: UserID, role: TeamRole, joinedAt: ServerTimestamp) {
    self.id = id
    self.teamID = teamID
    self.userID = userID
    self.role = role
    self.joinedAt = joinedAt
  }
}

public struct TeamWithRole: Identifiable, Hashable, Sendable {
  public var team: Team
  public var role: TeamRole
  public var id: TeamID { team.id }

  public init(team: Team, role: TeamRole) {
    self.team = team
    self.role = role
  }
}

public struct ProfileSummary: Hashable, Sendable, Codable {
  public var id: UserID
  public var email: String?
  public var fullName: String?
  public var avatarURL: String?

  public init(id: UserID, email: String?, fullName: String?, avatarURL: String?) {
    self.id = id
    self.email = email
    self.fullName = fullName
    self.avatarURL = avatarURL
  }
}

public struct TeamMember: Identifiable, Hashable, Sendable {
  public var membership: TeamMembership
  public var profile: ProfileSummary?
  public var id: UUID { membership.id }

  public init(membership: TeamMembership, profile: ProfileSummary?) {
    self.membership = membership
    self.profile = profile
  }
}

public struct TeamInvitation: Identifiable, Hashable, Sendable, Codable {
  public var id: UUID
  public var teamID: TeamID
  public var email: String
  public var role: TeamRole
  public var invitedBy: UserID
  public var token: String
  public var expiresAt: ServerTimestamp
  public var acceptedAt: ServerTimestamp?
  public var createdAt: ServerTimestamp

  public init(
    id: UUID, teamID: TeamID, email: String, role: TeamRole, invitedBy: UserID, token: String,
    expiresAt: ServerTimestamp, acceptedAt: ServerTimestamp?, createdAt: ServerTimestamp
  ) {
    self.id = id
    self.teamID = teamID
    self.email = email
    self.role = role
    self.invitedBy = invitedBy
    self.token = token
    self.expiresAt = expiresAt
    self.acceptedAt = acceptedAt
    self.createdAt = createdAt
  }
}

public struct PendingInvitation: Identifiable, Hashable, Sendable {
  public var invitation: TeamInvitation
  public var teamName: String
  public var inviterName: String?
  public var id: UUID { invitation.id }

  public init(invitation: TeamInvitation, teamName: String, inviterName: String?) {
    self.invitation = invitation
    self.teamName = teamName
    self.inviterName = inviterName
  }
}
