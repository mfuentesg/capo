import CapoDesign
import Foundation
import Observation

enum SidebarItem: Hashable, CaseIterable {
  case library, setlists, teams, conflicts, settings
}

enum CompactTab: Hashable { case library, setlists, settings }

struct EditorItem: Identifiable {
  let request: SongEditorRequest
  var id: SongEditorRequest { request }
}

struct SetlistRun: Identifiable {
  let playlistID: PlaylistID
  let startIndex: Int
  var id: PlaylistID { playlistID }
}

struct PendingShare: Identifiable {
  let playlistID: PlaylistID
  var id: PlaylistID { playlistID }
}

struct PendingAdd: Identifiable {
  let songIDs: [SongID]
  let id = UUID()
}

/// Navigation and presentation state shared by the compact and regular layouts.
@Observable
@MainActor
final class ShellNavigation {
  var sidebar: SidebarItem? = .library
  var tab: CompactTab = .library
  var songSelection: SongID?
  var playlistSelection: PlaylistID?
  var editor: EditorItem?
  var setlistRun: SetlistRun?
  var pendingAdd: PendingAdd?
  var pendingShare: PendingShare?
  var showConflicts = false
  var showTeams = false
  var showInvitations = false
  var showSignOut = false

  func openSong(_ id: SongID) {
    sidebar = .library
    tab = .library
    songSelection = id
  }

  func resetSelections() {
    songSelection = nil
    playlistSelection = nil
  }

  func makeActions() -> CapoActions {
    CapoActions(
      openSong: { [self] id in openSong(id) },
      openEditor: { [self] request in editor = EditorItem(request: request) },
      performSetlist: { [self] id, index in setlistRun = SetlistRun(playlistID: id, startIndex: index) },
      addSongsToPlaylist: { [self] ids in pendingAdd = PendingAdd(songIDs: ids) },
      showConflicts: { [self] in showConflicts = true },
      sharePlaylist: { [self] id in pendingShare = PendingShare(playlistID: id) })
  }
}
