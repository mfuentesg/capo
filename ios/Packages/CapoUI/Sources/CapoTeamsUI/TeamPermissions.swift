import CapoCore

/// Which team actions the signed-in member's role offers. UI gating only; the server enforces.
nonisolated struct TeamPermissions: Equatable {
  var role: TeamRole

  var canManageMembers: Bool { role.canManageMembers }
  var canTransferOwnership: Bool { role == .owner }
  var canDeleteTeam: Bool { role == .owner }
  /// Owners must transfer ownership first (or delete the team).
  var canLeave: Bool { role != .owner }

  /// Roles this member may hand out when inviting or changing a role.
  var assignableRoles: [TeamRole] {
    switch role {
    case .owner: [.admin, .member, .viewer]
    case .admin: [.member, .viewer]
    case .member, .viewer: []
    }
  }

  /// The owner is never editable; admins cannot touch other admins.
  func canModify(_ target: TeamRole) -> Bool {
    guard canManageMembers, target != .owner else { return false }
    return role == .owner || target != .admin
  }
}
