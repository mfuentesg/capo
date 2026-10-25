import CapoCore
import Foundation
import Testing

@testable import CapoSupabase

/// Only ever talks to the in-process stub server.
@Suite struct AccountTests {
  @Test func deleteAccountCallsRpcWithOwnUserID() async throws {
    let server = StubServer()
    server.handle { _ in .ok("") }
    try await SupabaseAccountRemote(client: makeClient(server)).deleteAccount(userID: Ids.user)
    let request = try #require(server.restRequests.first)
    #expect(request.path == "/rest/v1/rpc/delete_user_account")
    #expect(request.jsonObject?["p_user_id"] as? String == Ids.user.uuidString.lowercased())
  }

  @Test func failuresMapToCapoError() async {
    let denied = StubServer()
    denied.handle { _ in .postgrestError(400, code: "P0001", message: "Not authorized to delete this account") }
    await #expect(throws: CapoError.server("Not authorized to delete this account")) {
      try await SupabaseAccountRemote(client: makeClient(denied)).deleteAccount(userID: Ids.user)
    }
    let offline = StubServer()
    offline.handle { _ in .failure(.notConnectedToInternet) }
    await #expect(throws: CapoError.offlineUnavailable) {
      try await SupabaseAccountRemote(client: makeClient(offline)).deleteAccount(userID: Ids.user)
    }
  }
}
