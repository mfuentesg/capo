import CapoDesign
import CapoRendering
import SwiftUI

/// WP0 stub. WP9 owns it.
public struct SongEditorView: View {
  let request: SongEditorRequest
  let onFinish: (SongID?) -> Void

  public init(request: SongEditorRequest, onFinish: @escaping (SongID?) -> Void) {
    self.request = request
    self.onFinish = onFinish
  }

  public var body: some View { StubScreen("Editor") }
}

/// WP0 stub. WP9 owns it.
public struct ConflictsView: View {
  public init() {}
  public var body: some View { StubScreen("Conflicts") }
}
