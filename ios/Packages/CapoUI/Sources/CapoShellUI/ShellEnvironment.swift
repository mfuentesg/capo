import CapoDesign
import CapoSettingsUI
import SwiftUI

/// Injects services, context, role and actions. Applied to the main content and to every
/// sheet/cover, because presented content does not reliably inherit modifiers applied above it.
struct ShellEnvironment: ViewModifier {
  let model: ShellModel

  func body(content: Content) -> some View {
    content
      .environment(\.userServices, model.services)
      .environment(\.appContext, model.context)
      .environment(\.currentTeamRole, model.contextStore.role)
      .environment(\.settingsContext, model.settingsContext)
      .environment(\.capoActions, model.navigation.makeActions())
      .preferredColorScheme(model.theme.flatMap(Self.scheme))
  }

  static func scheme(_ theme: AppTheme) -> ColorScheme? {
    switch theme {
    case .light: .light
    case .dark: .dark
    case .system: nil
    }
  }
}

extension View {
  func shellEnvironment(_ model: ShellModel) -> some View { modifier(ShellEnvironment(model: model)) }
}
