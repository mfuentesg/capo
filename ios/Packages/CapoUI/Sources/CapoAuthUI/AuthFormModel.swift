import CapoDesign
import Foundation
import Observation

/// Form state and validation for AuthView; kept free of SwiftUI so it can be unit tested.
@Observable
@MainActor
public final class AuthFormModel {
  public enum Mode: Hashable, Sendable { case signIn, signUp }

  public var mode: Mode = .signIn
  public var email = ""
  public var password = ""
  public private(set) var isBusy = false
  public var errorMessage: String?

  public init() {}

  public var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

  public var isEmailValid: Bool {
    let parts = trimmedEmail.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains("."), !parts[1].hasPrefix("."),
      !parts[1].hasSuffix("."), !trimmedEmail.contains(" ")
    else { return false }
    return true
  }

  public var isPasswordValid: Bool { password.count >= (mode == .signUp ? 6 : 1) }

  public var canSubmit: Bool { isEmailValid && isPasswordValid && !isBusy }

  public func toggleMode() {
    mode = mode == .signIn ? .signUp : .signIn
    errorMessage = nil
  }

  public func submit(with actions: AuthActions) async {
    guard canSubmit else { return }
    await run {
      if self.mode == .signUp {
        guard actions.allowsSignUp else { throw CapoError.permissionDenied }
        try await actions.signUp(self.trimmedEmail, self.password)
      } else {
        try await actions.signIn(self.trimmedEmail, self.password)
      }
    }
  }

  public func signInWithGoogle(with actions: AuthActions) async {
    guard !isBusy else { return }
    await run { try await actions.signInWithGoogle() }
  }

  private func run(_ work: () async throws -> Void) async {
    isBusy = true
    errorMessage = nil
    defer { isBusy = false }
    do {
      try await work()
    } catch is CancellationError {
      // User dismissed the web sign-in sheet; nothing to report.
    } catch {
      errorMessage = Self.message(for: error)
    }
  }

  static func message(for error: Error) -> String {
    switch error as? CapoError {
    case .offlineUnavailable:
      return L10n.Ios.Auth.Error.offline
    case .invalidInput:
      return L10n.Ios.Auth.Error.invalid
    case .permissionDenied:
      return L10n.Ios.Auth.Error.denied
    default:
      let text = error.localizedDescription
      return text.isEmpty
        ? L10n.Ios.Auth.Error.generic
        : text
    }
  }
}
