import CapoCore
import Foundation
import Testing

@testable import CapoSupabase

@Suite struct AppleSignInTests {
  @Test func nonceIsRandomAndUrlSafe() {
    let first = AppleNonce.random()
    let second = AppleNonce.random()
    #expect(first.count == 32 && first != second)
    #expect(first.allSatisfy { $0.isLetter || $0.isNumber || "-._".contains($0) })
  }

  @Test func hashIsHexSha256() {
    // SHA-256("abc")
    #expect(
      AppleNonce.sha256("abc")
        == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  }

  @Test func feedbackIsInsertedLikeTheWeb() async throws {
    let server = StubServer()
    server.handle { _ in .json(201, "") }
    let remote = SupabaseAccountRemote(client: makeClient(server))
    try await remote.submitFeedback(
      FeedbackDraft(name: " Ana ", email: "", message: "  hello world ", newsletterOptIn: true))
    let request = try #require(server.restRequests.first)
    #expect(request.method == "POST" && request.path == "/rest/v1/feedback")
    #expect(request.jsonObject?["message"] as? String == "hello world")
    #expect(request.jsonObject?["name"] as? String == "Ana")
    #expect(request.jsonObject?["email"] is NSNull)
    #expect(request.jsonObject?["newsletter_opt_in"] as? Bool == true)
    #expect(request.jsonObject?["opt_in_at"] is String)
  }

  @Test func invalidFeedbackNeverReachesTheServer() async {
    let server = StubServer()
    let remote = SupabaseAccountRemote(client: makeClient(server))
    await #expect(throws: CapoError.self) {
      try await remote.submitFeedback(FeedbackDraft(message: "hey"))
    }
    #expect(server.restRequests.isEmpty)
  }
}
