import CapoAuthUI
import CapoDesign
import CapoEditorUI
import CapoLibraryUI
import CapoPerformanceUI
import CapoPlaylistsUI
import CapoRendering
import CapoSettingsUI
import CapoTeamsUI
import SwiftUI

/// WP0 stub: shows which mode the app runs in. WP5 owns it.
public struct CapoRootView: View {
  let dependencies: AppDependencies

  public init(dependencies: AppDependencies) {
    self.dependencies = dependencies
  }

  public var body: some View {
    NavigationStack {
      StubScreen(dependencies.isDemo ? "Capo (demo)" : "Capo")
        .navigationTitle("Capo")
    }
  }
}
