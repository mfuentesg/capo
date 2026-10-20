import CapoCore
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
