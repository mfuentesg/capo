import CapoDesign
import CapoSettingsUI
import Foundation

/// Builds the `SettingsContext` the shell injects into Settings.
enum ShellSettings {
  /// Account deletion is exposed in DEBUG builds only until it is approved for production
  /// (`ios/HUMAN_TODO.md`, item 5); until then release builds pass no closure and Settings hides
  /// the button.
  static let allowsAccountDeletion: Bool = {
    #if DEBUG
      true
    #else
      false
    #endif
  }()

  static func context(
    session: AuthSession, services: UserServices, config: AppConfig?, isDemo: Bool,
    allowsAccountDeletion: Bool = ShellSettings.allowsAccountDeletion,
    signOut: @escaping @MainActor @Sendable (_ erase: Bool) -> Void
  ) -> SettingsContext {
    SettingsContext(
      email: session.email, fullName: session.fullName, avatarURL: session.avatarURL,
      provider: session.provider, environmentName: config?.environmentName,
      serverURL: config?.supabaseURL, isDemo: isDemo, signOut: signOut,
      deleteAccount: allowsAccountDeletion ? services.deleteAccount : nil)
  }
}
