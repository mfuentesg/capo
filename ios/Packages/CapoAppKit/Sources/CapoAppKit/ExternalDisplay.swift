import CapoDesign
import CapoRendering
import SwiftUI
import UIKit

/// Hosts `ExternalDisplayView` on a connected external display (AirPlay, HDMI).
/// Registered in Info.plist for `UIWindowSceneSessionRoleExternalDisplayNonInteractive`.
@objc(CapoExternalDisplaySceneDelegate)
public final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
  public var window: UIWindow?

  public func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = UIHostingController(rootView: ExternalDisplayView())
    window.isHidden = false
    self.window = window
  }

  public func sceneDidDisconnect(_ scene: UIScene) {
    window = nil
  }
}
