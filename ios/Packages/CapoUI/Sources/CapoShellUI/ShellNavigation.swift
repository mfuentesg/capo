import CapoDesign
import Foundation
import Observation

/// Top-level destinations; exactly the web navbar's Songs, Playlists, Chords and Teams.
/// Used by the regular sidebar and the compact tab bar alike.
enum SidebarItem: String, Hashable, CaseIterable {
  case songs, playlists, chords, teams

  /// SF Symbol stand-in for the web's lucide icon; the single place to swap icons later.
  var symbol: String {
    switch self {
    case .songs: "music.note"
    case .playlists: "music.note.list"
    case .chords: "guitars"
    case .teams: "person.3"
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

  /// Parses the DEBUG `-CapoSidebar <name>` launch argument. `settings` is not a destination.
  static func debug(_ name: String) -> SidebarItem? { SidebarItem(rawValue: name.lowercased()) }
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

/// Navigation and presentation state shared by the compact and regular layouts.
@Observable
@MainActor
final class ShellNavigation {
  /// Selected destination for both layouts (sidebar row and compact tab).
  var destination: SidebarItem = .songs
  var songSelection: SongID?
  var playlistSelection: PlaylistID?
  var editor: EditorItem?
  var setlistRun: SetlistRun?
  var pendingAdd: PendingAdd?
  var pendingShare: PendingShare?
  var showConflicts = false
  var showSettings = false
  var showInvitations = false
  var showSignOut = false

  func openSong(_ id: SongID) {
    destination = .songs
    songSelection = id
  }

  func open(_ item: SidebarItem) { destination = item }

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
