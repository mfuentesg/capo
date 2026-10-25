import CapoCore
import CapoIcons
import Foundation
import Testing

@testable import CapoTeamsUI

@Suite struct TeamPermissionsTests {
  @Test func ownerManagesEveryoneButOwner() {
    let p = TeamPermissions(role: .owner)
    #expect(p.canModify(.admin) && p.canModify(.member) && p.canModify(.viewer))
    #expect(!p.canModify(.owner))
    #expect(p.assignableRoles == [.admin, .member, .viewer])
    #expect(p.canDeleteTeam && p.canTransferOwnership && !p.canLeave)
  }

  @Test func adminOnlyTouchesMembersAndViewers() {
    let p = TeamPermissions(role: .admin)
    #expect(p.canModify(.member) && p.canModify(.viewer))
    #expect(!p.canModify(.admin) && !p.canModify(.owner))
    #expect(p.assignableRoles == [.member, .viewer])
    #expect(!p.canDeleteTeam && !p.canTransferOwnership && p.canLeave)
  }

  @Test func membersAndViewersCannotManage() {
    for role in [TeamRole.member, .viewer] {
      let p = TeamPermissions(role: role)
      #expect(!p.canManageMembers && p.assignableRoles.isEmpty)
      #expect(!p.canModify(.viewer) && p.canLeave)
    }
  }
}

@Suite struct TeamsUILogicTests {
  private func team(_ name: String, role: TeamRole) -> TeamWithRole {
    let stamp = ServerTimestamp("2024-01-01T00:00:00Z")
    return TeamWithRole(
      team: Team(
        id: UUID(), name: name, icon: nil, avatarURL: nil, isPublic: false, createdBy: UUID(),
        createdAt: stamp, updatedAt: stamp),
      role: role)
  }

  @MainActor @Test func roleIconsMatchWebConstants() {
    #expect(TeamRole.owner.iconName == .userLock)
    #expect(TeamRole.admin.iconName == .keyRound)
    #expect(TeamRole.member.iconName == .user)
    #expect(TeamRole.viewer.iconName == .userSearch)
  }

  @Test func iconCatalogHasEightyResolvableUniqueNames() {
    #expect(TeamIconCatalog.names.count == 80)
    #expect(Set(TeamIconCatalog.names).count == 80)
    for name in TeamIconCatalog.names { #expect(CapoIconName.lookup(name) != nil, "\(name)") }
  }

  @Test func searchFiltersByNameCaseInsensitively() {
    let teams = [team("Banda del Domingo", role: .owner), team("Coro Juvenil", role: .admin)]
    #expect(TeamsModel.filter(teams, search: "  coro ").map(\.team.name) == ["Coro Juvenil"])
    #expect(TeamsModel.filter(teams, search: "").count == 2)
  }

  @Test func transferTargetsExcludeViewers() {
    let teams = [team("A", role: .owner), team("B", role: .viewer), team("C", role: .member)]
    #expect(TransferSongToTeamSheet.targets(teams).map(\.team.name) == ["A", "C"])
  }

  @Test func invitationExpiryUsesExpiresAt() {
    let past = ServerTimestamp("2020-01-01T00:00:00Z")
    let future = ServerTimestamp("2999-01-01T00:00:00Z")
    func invitation(_ expires: ServerTimestamp) -> TeamInvitation {
      TeamInvitation(
        id: UUID(), teamID: UUID(), email: "a@b.c", role: .member, invitedBy: UUID(), token: "t",
        expiresAt: expires, acceptedAt: nil, createdAt: past)
    }
    #expect(TeamDetailModel.isExpired(invitation(past)))
    #expect(!TeamDetailModel.isExpired(invitation(future)))
  }

  @Test func invitationLinkKeepsOriginAndCarriesToken() {
    let share = URL(string: "https://capo.example/shared/x")!
    #expect(
      TeamInvitationLink.url(token: "abc", base: share)?.absoluteString
        == "https://capo.example/teams/accept-invitation?token=abc")
  }
}
