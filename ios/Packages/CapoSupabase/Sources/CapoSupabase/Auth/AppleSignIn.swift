import CapoCore
import CryptoKit
import Foundation

/// Nonce handling for Sign in with Apple: the raw nonce goes to Supabase, its SHA-256 to Apple,
/// which embeds it in the identity token so Supabase can verify the token was minted for this call.
enum AppleNonce {
  private static let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

  static func random(length: Int = 32) -> String {
    var generator = SystemRandomNumberGenerator()
    return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
  }

  static func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

/// What Apple returned, reduced to what the app needs.
struct AppleCredential: Sendable {
  var identityToken: String
  /// Apple only sends the name on the very first authorization.
  var fullName: String?
}

#if canImport(AuthenticationServices) && canImport(UIKit)
  import AuthenticationServices
  import UIKit

  /// Runs one `ASAuthorizationController` request for name and email.
  @MainActor
  final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
  {
    private var continuation: CheckedContinuation<AppleCredential, Error>?
    private var controller: ASAuthorizationController?

    static func authorize(hashedNonce: String) async throws -> AppleCredential {
      let coordinator = AppleSignInCoordinator()
      return try await coordinator.run(hashedNonce: hashedNonce)
    }

    private func run(hashedNonce: String) async throws -> AppleCredential {
      try await withCheckedThrowingContinuation { continuation in
        self.continuation = continuation
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        controller.performRequests()
      }
    }

    func authorizationController(
      controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
    ) {
      defer { finish() }
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let data = credential.identityToken, let token = String(data: data, encoding: .utf8)
      else {
        continuation?.resume(throwing: CapoError.invalidInput("apple identity token"))
        return
      }
      let name = credential.fullName.flatMap {
        PersonNameComponentsFormatter().string(from: $0).trimmingCharacters(in: .whitespaces)
      }
      continuation?.resume(
        returning: AppleCredential(identityToken: token, fullName: name?.isEmpty == false ? name : nil))
    }

    func authorizationController(
      controller: ASAuthorizationController, didCompleteWithError error: Error
    ) {
      defer { finish() }
      if let authError = error as? ASAuthorizationError, authError.code == .canceled {
        continuation?.resume(throwing: CancellationError())
      } else {
        continuation?.resume(throwing: error)
      }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    private func finish() {
      continuation = nil
      controller = nil
    }
  }
#endif
