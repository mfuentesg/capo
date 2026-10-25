import CapoCore
import CapoDesign
import Foundation
import Observation

/// Shared error handling: offline gets its own banner, everything else a toast message.
@MainActor @Observable
class OnlineActionModel {
  var message: String?
  var isOffline = false
  var isBusy = false

  /// Runs an online-only action. Returns true on success.
  @discardableResult
  func perform(failure: String, _ body: () async throws -> Void) async -> Bool {
    isBusy = true
    defer { isBusy = false }
    do {
      try await body()
      isOffline = false
      return true
    } catch let error as CapoError where error == .offlineUnavailable {
      isOffline = true
      message = TeamsStrings.offline
    } catch let error as CapoError where error == .permissionDenied {
      message = L10n.Toasts.roleChangePermissionDenied
    } catch is CancellationError {
    } catch {
      message = failure
    }
    return false
  }
}

@MainActor @Observable
final class TeamsModel: OnlineActionModel {
  var teams: [TeamWithRole] = []
  var loaded = false
  var search = ""
  /// Member counts are online-only, so they fill in when reachable and stay blank otherwise.
  var memberCounts: [TeamID: Int] = [:]
  var pendingInvitationCount = 0

  var filtered: [TeamWithRole] { Self.filter(teams, search: search) }

  nonisolated static func filter(_ teams: [TeamWithRole], search: String) -> [TeamWithRole] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return teams }
    return teams.filter { $0.team.name.localizedCaseInsensitiveContains(query) }
  }

  func create(_ repo: any TeamRepository, name: String, icon: String?, isPublic: Bool = false) async
    -> Bool
  {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let cleanIcon = icon?.trimmingCharacters(in: .whitespaces)
    return await perform(failure: L10n.Toasts.teamCreatedFailed) {
      _ = try await repo.createTeam(
        name: trimmed, icon: (cleanIcon?.isEmpty ?? true) ? nil : cleanIcon, isPublic: isPublic)
    }
  }

  func setIcon(_ repo: any TeamRepository, team: Team, icon: String) async {
    await perform(failure: L10n.Toasts.error) {
      try await repo.updateTeam(id: team.id, name: team.name, icon: icon)
    }
  }

  func leave(_ repo: any TeamRepository, teamID: TeamID) async {
    await perform(failure: L10n.Toasts.teamLeftFailed) { try await repo.leaveTeam(id: teamID) }
  }

  func delete(_ repo: any TeamRepository, teamID: TeamID) async {
    await perform(failure: L10n.Toasts.teamDeletedFailed) { try await repo.deleteTeam(id: teamID) }
  }

  func loadCounts(_ repo: any TeamRepository) async {
    for item in teams where memberCounts[item.id] == nil {
      if let members = try? await repo.members(teamID: item.id) { memberCounts[item.id] = members.count }
    }
    if let pending = try? await repo.pendingInvitationsForMe() { pendingInvitationCount = pending.count }
  }
}

@MainActor @Observable
final class TeamDetailModel: OnlineActionModel {
  var members: [TeamMember] = []
  var invitations: [TeamInvitation] = []
  var loaded = false

  func load(_ repo: any TeamRepository, teamID: TeamID) async {
    await perform(failure: L10n.Invitations.loadFailed) {
      async let fetchedMembers = repo.members(teamID: teamID)
      async let fetchedInvitations = repo.invitations(teamID: teamID)
      let (m, i) = try await (fetchedMembers, fetchedInvitations)
      self.members = m.sorted { $0.membership.joinedAt < $1.membership.joinedAt }
      self.invitations = i
      self.loaded = true
    }
  }

  func invite(_ repo: any TeamRepository, teamID: TeamID, email: String, role: TeamRole) async -> Bool {
    let trimmed = email.trimmingCharacters(in: .whitespaces)
    guard trimmed.contains("@") else { return false }
    let ok = await perform(failure: L10n.Toasts.error) {
      _ = try await repo.invite(email: trimmed, role: role, teamID: teamID)
    }
    if ok { await load(repo, teamID: teamID) }
    return ok
  }

  func revoke(_ repo: any TeamRepository, teamID: TeamID, invitation: TeamInvitation) async {
    if await perform(failure: L10n.Toasts.error, { try await repo.revokeInvitation(id: invitation.id) }) {
      await load(repo, teamID: teamID)
    }
  }

  func changeRole(_ repo: any TeamRepository, teamID: TeamID, member: TeamMember, to role: TeamRole)
    async
  {
    let userID = member.membership.userID
    if await perform(
      failure: L10n.Toasts.roleChangeFailed,
      { try await repo.changeRole(userID: userID, teamID: teamID, role: role) })
    {
      await load(repo, teamID: teamID)
    }
  }

  func remove(_ repo: any TeamRepository, teamID: TeamID, member: TeamMember) async {
    let userID = member.membership.userID
    if await perform(
      failure: L10n.Toasts.memberRemovalFailed,
      { try await repo.removeMember(userID: userID, teamID: teamID) })
    {
      await load(repo, teamID: teamID)
    }
  }

  func transfer(_ repo: any TeamRepository, teamID: TeamID, to member: TeamMember) async {
    let userID = member.membership.userID
    if await perform(
      failure: L10n.Toasts.ownershipTransferFailed,
      { try await repo.transferOwnership(teamID: teamID, to: userID) })
    {
      await load(repo, teamID: teamID)
    }
  }

  func leave(_ repo: any TeamRepository, teamID: TeamID) async -> Bool {
    await perform(failure: L10n.Toasts.teamLeftFailed) { try await repo.leaveTeam(id: teamID) }
  }

  /// Hands ownership to `member`, then leaves (the previous owner would otherwise stay as admin).
  func transferAndLeave(_ repo: any TeamRepository, teamID: TeamID, to member: TeamMember) async
    -> Bool
  {
    let userID = member.membership.userID
    return await perform(failure: L10n.Toasts.ownershipTransferFailed) {
      try await repo.transferOwnership(teamID: teamID, to: userID)
      try await repo.leaveTeam(id: teamID)
    }
  }

  func rename(_ repo: any TeamRepository, team: Team, name: String, icon: String?) async -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    return await perform(failure: L10n.Toasts.error) {
      try await repo.updateTeam(id: team.id, name: trimmed, icon: icon)
    }
  }

  /// Replaces the invitation with a fresh one in a single server transaction.
  func resend(_ repo: any TeamRepository, teamID: TeamID, invitation: TeamInvitation) async {
    let ok = await perform(failure: L10n.Toasts.error) {
      _ = try await repo.resendInvitation(id: invitation.id)
    }
    if ok { await load(repo, teamID: teamID) }
  }

  var activeInvitations: [TeamInvitation] { invitations.filter { !Self.isExpired($0) } }
  var expiredInvitations: [TeamInvitation] { invitations.filter { Self.isExpired($0) } }

  nonisolated static func isExpired(_ invitation: TeamInvitation, now: Date = .now) -> Bool {
    (invitation.expiresAt.date ?? .distantFuture) < now
  }

  func delete(_ repo: any TeamRepository, teamID: TeamID) async -> Bool {
    await perform(failure: L10n.Toasts.teamDeletedFailed) { try await repo.deleteTeam(id: teamID) }
  }

  func displayName(_ member: TeamMember) -> String {
    member.profile?.fullName ?? member.profile?.email ?? L10n.Teams.user
  }
}

@MainActor @Observable
final class PendingInvitationsModel: OnlineActionModel {
  var items: [PendingInvitation] = []
  var loaded = false

  func load(_ repo: any TeamRepository) async {
    await perform(failure: L10n.Invitations.loadFailed) {
      items = try await repo.pendingInvitationsForMe()
      loaded = true
    }
  }

  func accept(_ repo: any TeamRepository, _ item: PendingInvitation) async {
    if await perform(failure: L10n.Invitations.failedToAccept, {
      _ = try await repo.acceptInvitation(token: item.invitation.token)
    }) {
      items.removeAll { $0.id == item.id }
    }
  }

  /// Declining goes through its own RPC: RLS only lets team admins delete invitation rows.
  func decline(_ repo: any TeamRepository, _ item: PendingInvitation) async {
    if await perform(failure: L10n.Toasts.error, {
      try await repo.declineInvitation(token: item.invitation.token)
    }) {
      items.removeAll { $0.id == item.id }
    }
  }
}
