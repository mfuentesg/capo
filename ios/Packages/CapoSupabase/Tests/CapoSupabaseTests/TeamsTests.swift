import CapoCore
import Foundation
import Testing

@testable import CapoSupabase

@Suite struct TeamsTests {
  private func remote(_ server: StubServer) -> SupabaseTeamsRemote {
    SupabaseTeamsRemote(client: makeClient(server), webBaseURL: URL(string: "https://capo.test")!)
  }

  private let teamJSON = """
    {"id":"22222222-2222-2222-2222-222222222222","name":"Band","icon":null,"avatar_url":null,\
    "is_public":false,"created_by":"11111111-1111-1111-1111-111111111111",\
    "created_at":"2024-01-01T00:00:00+00:00","updated_at":"2024-01-01T00:00:00+00:00"}
    """

  @Test func createTeamDecodesRpcArray() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[" + self.teamJSON + "]") }
    let team = try await remote(server).createTeam(name: "Band", icon: nil, isPublic: false)
    #expect(team.id == Ids.team)
    let request = try #require(server.restRequests.first)
    #expect(request.path == "/rest/v1/rpc/create_team_with_owner")
    #expect(request.jsonObject?["team_name"] as? String == "Band")
    #expect(request.jsonObject?["team_icon"] == nil)
  }

  @Test func membersUseEmbeddedProfiles() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[" + (try! fixtureString("team_member_embedded_object")) + "]") }
    let members = try await remote(server).members(teamID: Ids.team)
    #expect(members.count == 1)
    #expect(members[0].membership.role == .admin)
    #expect(members[0].profile?.fullName == "Ana")
    #expect(server.restRequests[0].query["select"] == "*,profiles(full_name,email,avatar_url)")
  }

  @Test func pendingInvitationsFilterByEmailAndEscapeWildcards() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[" + (try! fixtureString("pending_invitation")) + "]") }
    let pending = try await remote(server).pendingInvitations(email: "a_b@example.test")
    #expect(pending.first?.teamName == "Worship Team")
    let query = server.restRequests[0].query
    #expect(query["email"] == "ilike.a\\_b@example.test")
    #expect(query["accepted_at"]?.lowercased() == "is.null")
    #expect(query["expires_at"]?.hasPrefix("gt.") == true)
  }

  @Test func acceptInvitationDecodesScalarUUID() async throws {
    let server = StubServer()
    server.handle { _ in .ok("\"\(Ids.team.pg)\"") }
    #expect(try await remote(server).acceptInvitation(token: "tok") == Ids.team)
  }

  @Test func ensureShareCodeDecodesScalarString() async throws {
    let server = StubServer()
    server.handle { _ in .ok("\"ABCDEF123456\"") }
    #expect(try await remote(server).ensureShareCode(playlistID: Ids.playlist) == "ABCDEF123456")
  }

  @Test func errorsAreMappedToCapoError() async throws {
    let denied = StubServer()
    denied.handle { _ in .postgrestError(403, code: "42501") }
    await #expect(throws: CapoError.permissionDenied) {
      try await remote(denied).leaveTeam(id: Ids.team)
    }
    let offline = StubServer()
    offline.handle { _ in .failure(.notConnectedToInternet) }
    await #expect(throws: CapoError.offlineUnavailable) {
      try await remote(offline).leaveTeam(id: Ids.team)
    }
    let raised = StubServer()
    raised.handle { _ in .postgrestError(400, code: "P0001", message: "Only owners can do that") }
    await #expect(throws: CapoError.server("Only owners can do that")) {
      try await remote(raised).removeMember(userID: Ids.user, teamID: Ids.team)
    }
  }

  @Test func forbiddenUpdateWithNoRowsIsPermissionDenied() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[]") }
    await #expect(throws: CapoError.permissionDenied) {
      try await remote(server).updateTeam(id: Ids.team, name: "x", icon: nil)
    }
  }
}
