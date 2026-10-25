import SwiftUI

/// What AuthView needs from the shell. AuthView has a frozen no-argument init, so the shell injects
/// this through the environment (the frozen Environment.swift has no auth entry).
public struct AuthActions: Sendable {
  public var signInWithGoogle: @Sendable () async throws -> Void
  public var signIn: @Sendable (_ email: String, _ password: String) async throws -> Void
  public var signUp: @Sendable (_ email: String, _ password: String) async throws -> Void
  /// Sign-up is offered only when the environment is not production.
  public var allowsSignUp: Bool
  /// DEBUG builds only: sign in with the bundled local dev session.
  public var devSignIn: (@Sendable () async throws -> Void)?

  public init(
    signInWithGoogle: @escaping @Sendable () async throws -> Void = {},
    signIn: @escaping @Sendable (String, String) async throws -> Void = { _, _ in },
    signUp: @escaping @Sendable (String, String) async throws -> Void = { _, _ in },
    allowsSignUp: Bool = false,
    devSignIn: (@Sendable () async throws -> Void)? = nil
  ) {
    self.devSignIn = devSignIn
    self.signInWithGoogle = signInWithGoogle
    self.signIn = signIn
    self.signUp = signUp
    self.allowsSignUp = allowsSignUp
  }

  public static let noop = AuthActions()
}

extension EnvironmentValues {
  @Entry public var authActions: AuthActions = .noop
}
