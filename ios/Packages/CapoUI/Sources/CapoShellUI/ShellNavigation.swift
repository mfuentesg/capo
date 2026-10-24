import CapoDesign
import CapoIcons
import Foundation
import Observation

/// Top-level destinations; exactly the web navbar's Songs, Playlists, Chords and Teams.
/// Shown in the bottom bar at every size.
enum ShellTab: String, Hashable, CaseIterable {
  case songs, playlists, chords, teams

  /// The web navbar's lucide icon.
  var icon: CapoIconName {
    switch self {
    case .songs: .music
    case .playlists: .listMusic
    case .chords: .guitar
    case .teams: .users
    }
  }

  var title: String {
    switch self {
    case .songs: L10n.Nav.songs
    case .playlists: L10n.Nav.playlists
    case .chords: L10n.Nav.chords
    case .teams: L10n.Nav.teams
    }
  }

  /// Parses the DEBUG `-CapoTab <name>` (or legacy `-CapoSidebar`) launch argument. `settings` is not a destination.
  static func debug(_ name: String) -> ShellTab? { ShellTab(rawValue: name.lowercased()) }
}

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

/// Navigation and presentation state: the selected tab plus one stack path per tab.
@Observable
@MainActor
final class ShellNavigation {
  var destination: ShellTab = .songs
  /// Pushed song pages of the Songs tab (the library table is the root).
  var songPath: [SongID] = []
  /// Pushed playlist pages of the Playlists tab.
  var playlistPath: [PlaylistID] = []
  var editor: EditorItem?
  var setlistRun: SetlistRun?
  var pendingAdd: PendingAdd?
  var pendingShare: PendingShare?
  var showConflicts = false
  var showSettings = false
  var showInvitations = false
  var showSignOut = false

  /// Pushes the song onto the Songs stack, switching to that tab first.
  func openSong(_ id: SongID) {
    destination = .songs
    if songPath.last != id { songPath.append(id) }
  }

  func openPlaylist(_ id: PlaylistID) {
    destination = .playlists
    if playlistPath.last != id { playlistPath.append(id) }
  }

  /// Switches tab; selecting the tab you are already on pops its stack to the root.
  func open(_ tab: ShellTab) {
    if destination == tab {
      switch tab {
      case .songs: songPath = []
      case .playlists: playlistPath = []
      case .chords, .teams: break
      }
    }
    destination = tab
  }

  func resetSelections() {
    songPath = []
    playlistPath = []
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
