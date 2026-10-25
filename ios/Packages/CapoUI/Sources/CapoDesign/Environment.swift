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
  /// nil = the screen presents its own share sheet.
  public var sharePlaylist: (@MainActor (PlaylistID) -> Void)?

  public init(
    openSong: @escaping @MainActor (SongID) -> Void = { _ in },
    openEditor: @escaping @MainActor (SongEditorRequest) -> Void = { _ in },
    performSetlist: @escaping @MainActor (PlaylistID, Int) -> Void = { _, _ in },
    addSongsToPlaylist: @escaping @MainActor ([SongID]) -> Void = { _ in },
    showConflicts: @escaping @MainActor () -> Void = {},
    sharePlaylist: (@MainActor (PlaylistID) -> Void)? = nil
  ) {
    self.openSong = openSong
    self.openEditor = openEditor
    self.performSetlist = performSetlist
    self.addSongsToPlaylist = addSongsToPlaylist
    self.showConflicts = showConflicts
    self.sharePlaylist = sharePlaylist
  }

  public static let noop = CapoActions()
}

extension EnvironmentValues {
  /// Default: `UserServices.preview` (CapoFakes).
  @Entry public var userServices: UserServices = .preview
  /// Default: `.personal(userID: FakeIDs.user)`.
  @Entry public var appContext: AppContext = .personal(userID: FakeIDs.user)
  /// Where new songs, playlists and tags are created. Unlike `appContext` (the view filter, which can
  /// be "All") this is always personal or a team, as on the web where the creation context survives
  /// switching the view to "All".
  @Entry public var creationContext: AppContext = .personal(userID: FakeIDs.user)
  /// nil = personal (full rights).
  @Entry public var currentTeamRole: TeamRole? = nil
  /// Roles per team; permissions of an item come from its own team, not from the view filter.
  @Entry public var teamRoles: TeamRoles = TeamRoles()
  @Entry public var capoActions: CapoActions = .noop
}
