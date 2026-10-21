import CapoCore
import CapoShellUI
import SwiftUI

/// The whole app scene. `CapoApp.swift` only instantiates this.
public struct CapoAppScene: Scene {
  private let dependencies: AppDependencies

  public init() {
    dependencies = CapoComposition.make(config: AppConfig.load(from: .main))
  }

  public var body: some Scene {
    WindowGroup {
      CapoRootView(dependencies: dependencies)
        .modifier(StageManagerMinimumSize())
        .onOpenURL { url in
          let auth = dependencies.auth
          Task { _ = await auth.handleOpenURL(url) }
        }
    }
    .windowResizability(.contentMinSize)
  }
}

/// iPad windows (Stage Manager, Split View) stay large enough for the shell's split layout.
private struct StageManagerMinimumSize: ViewModifier {
  func body(content: Content) -> some View {
    if UIDevice.current.userInterfaceIdiom == .pad {
      content.frame(minWidth: 480, minHeight: 560)
    } else {
      content
    }
  }
}
