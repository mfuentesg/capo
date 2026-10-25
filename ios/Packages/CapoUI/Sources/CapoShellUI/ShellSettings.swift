import CapoDesign
import CapoSettingsUI
import Foundation

/// Builds the `SettingsContext` the shell injects into Settings.
enum ShellSettings {
  /// Account deletion ships in every build: App Store guideline 5.1.1(v) requires it in the app.
  static let allowsAccountDeletion = true

  static func context(
    session: AuthSession, services: UserServices, config: AppConfig?, isDemo: Bool,
    allowsAccountDeletion: Bool = ShellSettings.allowsAccountDeletion,
    signOut: @escaping @MainActor @Sendable (_ erase: Bool) -> Void
  ) -> SettingsContext {
    SettingsContext(
      email: session.email, fullName: session.fullName, avatarURL: session.avatarURL,
      provider: session.provider, environmentName: config?.environmentName,
      serverURL: config?.supabaseURL, isDemo: isDemo, signOut: signOut,
      deleteAccount: allowsAccountDeletion ? services.deleteAccount : nil,
      submitFeedback: services.submitFeedback)
  }
}
