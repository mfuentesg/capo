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
        .onOpenURL { url in
          let auth = dependencies.auth
          Task { _ = await auth.handleOpenURL(url) }
        }
    }
  }
}
