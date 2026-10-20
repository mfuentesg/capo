import CapoDesign
import CapoLibraryUI
import CapoPerformanceUI
import SwiftUI

/// WP0 stub. WP8 owns it.
public struct PlaylistsView: View {
  @Binding var selection: PlaylistID?
  public init(selection: Binding<PlaylistID?>) { _selection = selection }
  public var body: some View { StubScreen("Setlists") }
}

/// WP0 stub. Perform via `capoActions.performSetlist`.
public struct PlaylistDetailView: View {
  let playlistID: PlaylistID
  public init(playlistID: PlaylistID) { self.playlistID = playlistID }
  public var body: some View { StubScreen("Setlist") }
}

/// WP0 stub. WP8 owns it.
public struct SetlistPerformanceView: View {
  let playlistID: PlaylistID
  let startIndex: Int
  let onClose: () -> Void

  public init(playlistID: PlaylistID, startIndex: Int = 0, onClose: @escaping () -> Void) {
    self.playlistID = playlistID
    self.startIndex = startIndex
    self.onClose = onClose
  }

  public var body: some View { StubScreen("Setlist performance") }
}
