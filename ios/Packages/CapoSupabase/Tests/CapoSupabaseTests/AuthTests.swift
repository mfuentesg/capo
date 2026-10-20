import CapoCore
import Foundation
import Supabase
import Testing

@testable import CapoSupabase

@Suite struct AuthTests {
  private let callback = URL(string: "capo://auth/callback")!

  /// Storage pre-seeded with an expired session, under the key the client derives from the host.
  private func seeded(_ server: StubServer) throws -> MemoryAuthStorage {
    let key = "sb-\(server.host.split(separator: ".")[0])-auth-token"
    return MemoryAuthStorage([key: try fixture("session")])
  }

  @Test func expiredStoredSessionRestoresOfflineAsFirstElement() async throws {
    let server = StubServer()
    server.handle { _ in .failure(.notConnectedToInternet) }
    let service = SupabaseAuthService(
      client: makeClient(server, storage: try seeded(server)), callbackURL: callback)

    var iterator = service.sessionStream().makeAsyncIterator()
    let first = try #require(await iterator.next())
    let session = try #require(first)
    #expect(session.userID == Ids.user)
    #expect(session.email == "a@example.test")
    #expect(session.fullName == "Ana Perez")
    #expect(session.avatarURL == URL(string: "https://x.test/a.png"))
    #expect(session.provider == "google")

    #expect(await service.currentSession()?.userID == Ids.user)
  }

  @Test func noStoredSessionYieldsNilFirst() async throws {
    let server = StubServer()
    let service = SupabaseAuthService(client: makeClient(server), callbackURL: callback)
    var iterator = service.sessionStream().makeAsyncIterator()
    let first = await iterator.next()
    #expect(first == .some(nil))
    #expect(await service.currentSession() == nil)
  }

  @Test func handleOpenURLIgnoresForeignURLs() async throws {
    let server = StubServer()
    let service = SupabaseAuthService(client: makeClient(server), callbackURL: callback)
    #expect(await service.handleOpenURL(URL(string: "https://example.test/auth/callback")!) == false)
    #expect(await service.handleOpenURL(URL(string: "capo://invite/abc")!) == false)
    #expect(server.requests.isEmpty)
  }

  @Test func callbackMatching() {
    #expect(SupabaseAuthService.matches(URL(string: "capo://auth/callback?code=1")!, callback: callback))
    #expect(!SupabaseAuthService.matches(URL(string: "capo://auth/other")!, callback: callback))
  }

  @Test func signOutIsLocalAndWorksOffline() async throws {
    let server = StubServer()
    server.handle { _ in .failure(.notConnectedToInternet) }
    let storage = try seeded(server)
    let service = SupabaseAuthService(
      client: makeClient(server, storage: storage), callbackURL: callback)
    try await service.signOut()
    #expect(await service.currentSession() == nil)
  }
}
