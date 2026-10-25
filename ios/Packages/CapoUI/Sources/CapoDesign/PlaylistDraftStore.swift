import Observation
import SwiftUI

/// The web's playlist draft (`features/playlist-draft`): songs queued for a playlist, in order. One
/// instance lives in the shell so the selection survives closing the draft dialog, switching tabs
/// and reviewing as often as needed before the playlist is created.
@Observable
@MainActor
public final class PlaylistDraftStore {
  public private(set) var ids: [SongID] = []

  public init(ids: [SongID] = []) { self.ids = ids }

  public func contains(_ id: SongID) -> Bool { ids.contains(id) }

  public func toggle(_ id: SongID) {
    if let index = ids.firstIndex(of: id) { ids.remove(at: index) } else { ids.append(id) }
  }

  /// Appends songs that are not queued yet, keeping the existing order.
  public func add(_ newIDs: [SongID]) {
    for id in newIDs where !ids.contains(id) { ids.append(id) }
  }

  public func remove(_ id: SongID) { ids.removeAll { $0 == id } }

  public func move(from source: IndexSet, to destination: Int) {
    ids.move(fromOffsets: source, toOffset: destination)
  }

  public func clear() { ids = [] }
}

extension EnvironmentValues {
  @Entry public var playlistDraft: PlaylistDraftStore = PlaylistDraftStore()
}
