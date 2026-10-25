import CapoCore
import Foundation
import GRDB

struct GRDBTeamRepository: TeamRepository {
  let database: CapoDatabase
  let remote: (any TeamsRemote)?
  let onRemoteMutation: @Sendable () async -> Void

  func teams() -> AsyncStream<[TeamWithRole]> {
    let userID = database.userID
    return database.stream { db in
      try Row.fetchAll(
        db,
        sql: """
          SELECT t.*, m.role AS member_role FROM team_members m JOIN teams t ON t.id = m.team_id
          WHERE m.user_id = ? ORDER BY t.name COLLATE NOCASE, t.id
          """,
        arguments: [userID.dbString]
      ).map { row in
        TeamWithRole(
          team: Team(
            id: row.uuid("id"), name: row["name"], icon: row["icon"], avatarURL: row["avatar_url"],
            isPublic: row["is_public"], createdBy: row.uuid("created_by"),
            createdAt: row.timestamp("created_at"), updatedAt: row.timestamp("updated_at")),
          role: TeamRole(rawValue: row["member_role"]) ?? .member)
      }
    }
  }

  // MARK: Online-only reads

  func members(teamID: TeamID) async throws -> [TeamMember] {
    try await online { try await $0.members(teamID: teamID) }
  }

  func invitations(teamID: TeamID) async throws -> [TeamInvitation] {
    try await online { try await $0.invitations(teamID: teamID) }
  }

  func pendingInvitationsForMe() async throws -> [PendingInvitation] {
    try await online { try await $0.pendingInvitations() }
  }

  // MARK: Online-only mutations (the sync engine pulls the result afterwards)

  func createTeam(name: String, icon: String?, isPublic: Bool) async throws -> Team {
    try await mutate { try await $0.createTeam(name: name, icon: icon, isPublic: isPublic) }
  }

  func updateTeam(id: TeamID, name: String, icon: String?) async throws {
    try await mutate { try await $0.updateTeam(id: id, name: name, icon: icon) }
  }

  func deleteTeam(id: TeamID) async throws {
    try await mutate { try await $0.deleteTeam(id: id) }
  }

  func leaveTeam(id: TeamID) async throws {
    try await mutate { try await $0.leaveTeam(id: id) }
  }

  func invite(email: String, role: TeamRole, teamID: TeamID) async throws -> TeamInvitation {
    try await mutate { try await $0.invite(email: email, role: role, teamID: teamID) }
  }

  func revokeInvitation(id: UUID) async throws {
    try await mutate { try await $0.revokeInvitation(id: id) }
  }

  func declineInvitation(token: String) async throws {
    try await mutate { try await $0.declineInvitation(token: token) }
  }

  func resendInvitation(id: UUID) async throws -> TeamInvitation {
    try await mutate { try await $0.resendInvitation(id: id) }
  }

  func acceptInvitation(token: String) async throws -> TeamID {
    try await mutate { try await $0.acceptInvitation(token: token) }
  }

  func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws {
    try await mutate { try await $0.changeRole(userID: userID, teamID: teamID, role: role) }
  }

  func removeMember(userID: UserID, teamID: TeamID) async throws {
    try await mutate { try await $0.removeMember(userID: userID, teamID: teamID) }
  }

  func transferOwnership(teamID: TeamID, to userID: UserID) async throws {
    try await mutate { try await $0.transferOwnership(teamID: teamID, to: userID) }
  }

  // MARK: Helpers

  private func online<T: Sendable>(
    _ body: (any TeamsRemote) async throws -> T
  ) async throws -> T {
    guard let remote else { throw CapoError.offlineUnavailable }
    do {
      return try await body(remote)
    } catch let error as URLError where Self.offlineCodes.contains(error.code) {
      throw CapoError.offlineUnavailable
    }
  }

  private func mutate<T: Sendable>(
    _ body: (any TeamsRemote) async throws -> T
  ) async throws -> T {
    let result = try await online(body)
    await onRemoteMutation()
    return result
  }

  private static let offlineCodes: Set<URLError.Code> = [
    .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost,
    .cannotFindHost, .dataNotAllowed, .internationalRoamingOff
  ]
}
