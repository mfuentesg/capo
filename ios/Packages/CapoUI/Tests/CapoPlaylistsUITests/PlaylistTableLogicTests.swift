import CapoCore
import Foundation
import Testing

@testable import CapoPlaylistsUI

private func summary(
  _ name: String, date: String? = nil, songs: Int = 0, isPublic: Bool = false, archived: Bool = false
) -> PlaylistSummary {
  let user = UUID()
  let playlist = Playlist(
    id: UUID(), name: name, description: nil, date: date, isPublic: isPublic,
    allowGuestEditing: false, shareCode: nil, shareExpiresAt: nil,
    archivedAt: archived ? .now() : nil, userID: user, teamID: nil, createdBy: user,
    createdAt: .now(), updatedAt: .now())
  return PlaylistSummary(playlist: playlist, songCount: songs, isPinned: false, isFullyAvailableOffline: false)
}

@Suite struct PlaylistTableLogicTests {
  @Test func defaultIsNewestDateFirstWithUndatedLast() {
    let items = [summary("a", date: "2026-01-02"), summary("none"), summary("b", date: "2026-03-01")]
    let sorted = PlaylistTableLogic.sorted(items, by: .default)
    #expect(sorted.map(\.playlist.name) == ["b", "a", "none"])
    let ascending = PlaylistTableLogic.sorted(items, by: PlaylistTableSort(column: .date, ascending: true))
    #expect(ascending.map(\.playlist.name) == ["a", "b", "none"])
  }

  @Test func nameSongsAndSharingSort() {
    let items = [summary("Beta", songs: 5, isPublic: true), summary("alpha", songs: 9), summary("Gamma", songs: 5)]
    #expect(PlaylistTableLogic.sorted(items, by: PlaylistTableSort(column: .name, ascending: true)).map(\.playlist.name) == ["alpha", "Beta", "Gamma"])
    #expect(PlaylistTableLogic.sorted(items, by: PlaylistTableSort(column: .songs, ascending: false)).map(\.playlist.name) == ["alpha", "Beta", "Gamma"])
    #expect(PlaylistTableLogic.sorted(items, by: PlaylistTableSort(column: .sharing, ascending: false)).map(\.playlist.name) == ["Beta", "alpha", "Gamma"])
  }

  @Test func headerTapRules() {
    var sort = PlaylistTableSort.default
    sort = sort.tapped(.date)
    #expect(sort.ascending)
    sort = sort.tapped(.name)
    #expect(sort.column == .name && sort.ascending)
    sort = sort.tapped(.songs)
    #expect(sort.column == .songs && !sort.ascending)
  }

  @Test func activeAndArchivedTabsAreSeparateAndFiltered() {
    let items = [summary("Live", isPublic: true), summary("Old", archived: true), summary("Private")]
    let active = PlaylistTableLogic.rows(items, query: "", visibility: .all, archived: false, sort: PlaylistTableSort(column: .name, ascending: true))
    #expect(active.map(\.playlist.name) == ["Live", "Private"])
    let archived = PlaylistTableLogic.rows(items, query: "", visibility: .all, archived: true, sort: .default)
    #expect(archived.map(\.playlist.name) == ["Old"])
    let publicOnly = PlaylistTableLogic.rows(items, query: "li", visibility: .public, archived: false, sort: .default)
    #expect(publicOnly.map(\.playlist.name) == ["Live"])
  }
}
