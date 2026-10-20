@_exported import CapoCore
import CapoFakes
import SwiftUI

// Frozen (PLAN §5.7). Changes only via WP0.

public enum SongEditorRequest: Hashable, Sendable {
  case create, edit(SongID)
}

public nonisolated struct CapoActions: Sendable {
  public var openSong: @MainActor (SongID) -> Void
  public var openEditor: @MainActor (SongEditorRequest) -> Void
  public var performSetlist: @MainActor (PlaylistID, Int) -> Void
  public var addSongsToPlaylist: @MainActor ([SongID]) -> Void
  public var showConflicts: @MainActor () -> Void

  public init(
    openSong: @escaping @MainActor (SongID) -> Void = { _ in },
    openEditor: @escaping @MainActor (SongEditorRequest) -> Void = { _ in },
    performSetlist: @escaping @MainActor (PlaylistID, Int) -> Void = { _, _ in },
    addSongsToPlaylist: @escaping @MainActor ([SongID]) -> Void = { _ in },
    showConflicts: @escaping @MainActor () -> Void = {}
  ) {
    self.openSong = openSong
    self.openEditor = openEditor
    self.performSetlist = performSetlist
    self.addSongsToPlaylist = addSongsToPlaylist
    self.showConflicts = showConflicts
  }

  public static let noop = CapoActions()
}

extension EnvironmentValues {
  /// Default: `UserServices.preview` (CapoFakes).
  @Entry public var userServices: UserServices = .preview
  /// Default: `.personal(userID: FakeIDs.user)`.
  @Entry public var appContext: AppContext = .personal(userID: FakeIDs.user)
  /// nil = personal (full rights).
  @Entry public var currentTeamRole: TeamRole? = nil
  @Entry public var capoActions: CapoActions = .noop
}
