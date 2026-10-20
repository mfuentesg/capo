import CapoDesign
import SwiftUI

/// WP0 stub. WP6 owns it.
public struct LibraryView: View {
  @Binding var selection: SongID?
  public init(selection: Binding<SongID?>) { _selection = selection }
  public var body: some View { StubScreen("Library") }
}

/// WP0 stub. WP6 owns it.
public struct SongPickerView: View {
  let excluding: Set<SongID>
  let onPick: ([SongID]) -> Void

  public init(excluding: Set<SongID> = [], onPick: @escaping ([SongID]) -> Void) {
    self.excluding = excluding
    self.onPick = onPick
  }

  public var body: some View { StubScreen("Pick songs") }
}
