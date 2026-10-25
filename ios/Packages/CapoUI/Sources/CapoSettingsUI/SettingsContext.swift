import CapoCore
import SwiftUI

/// What `SettingsView` needs from the shell. `SettingsView` keeps its frozen no-argument init, so
/// the shell injects this through the environment (`.environment(\.settingsContext, ...)`).
public nonisolated struct SettingsContext: Sendable {
  public var email: String?
  public var fullName: String?
  public var avatarURL: URL?
  public var provider: String?
  public var environmentName: String?
  public var serverURL: URL?
  public var isDemo: Bool
  /// Signs out of the account. `erase == true` also removes the local database. Settings shows its
  /// own confirmation first, so the shell must call straight through to its sign-out.
  public var signOut: @MainActor @Sendable (_ erase: Bool) -> Void
  /// Calls the `delete_user_account` RPC. nil hides the "Delete account" button (the shell passes
  /// nil in production builds until the human approves).
  public var deleteAccount: (@Sendable () async throws -> Void)?
  /// Sends the feedback form. nil hides the Feedback row.
  public var submitFeedback: (@Sendable (FeedbackDraft) async throws -> Void)?

  public init(
    email: String? = nil,
    fullName: String? = nil,
    avatarURL: URL? = nil,
    provider: String? = nil,
    environmentName: String? = nil,
    serverURL: URL? = nil,
    isDemo: Bool = false,
    signOut: @escaping @MainActor @Sendable (Bool) -> Void = { _ in },
    deleteAccount: (@Sendable () async throws -> Void)? = nil,
    submitFeedback: (@Sendable (FeedbackDraft) async throws -> Void)? = nil
  ) {
    self.email = email
    self.fullName = fullName
    self.avatarURL = avatarURL
    self.provider = provider
    self.environmentName = environmentName
    self.serverURL = serverURL
    self.isDemo = isDemo
    self.signOut = signOut
    self.deleteAccount = deleteAccount
    self.submitFeedback = submitFeedback
  }

  public static let empty = SettingsContext()
}

extension EnvironmentValues {
  @Entry public var settingsContext: SettingsContext = .empty
}
