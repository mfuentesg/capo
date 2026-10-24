import CapoCore
import Foundation
import Testing

@testable import CapoPlaylistsUI

private func summary(
  _ name: String, isPublic: Bool = false, archived: Bool = false, description: String? = nil
) -> PlaylistSummary {
  let user = UUID()
  let playlist = Playlist(
    id: UUID(), name: name, description: description, date: nil, isPublic: isPublic,
    allowGuestEditing: false, shareCode: nil, shareExpiresAt: nil,
    archivedAt: archived ? .now() : nil, userID: user, teamID: nil, createdBy: user,
    createdAt: .now(), updatedAt: .now())
  return PlaylistSummary(
    playlist: playlist, songCount: 0, isPinned: false, isFullyAvailableOffline: false)
}

private struct Item: Identifiable, Equatable { let id: Int }

@Suite struct PlaylistListFilterTests {
  let items = [
    summary("Sunday", isPublic: true), summary("Old night", archived: true),
    summary("Youth", description: "friday night"), summary("Advent", isPublic: true)
  ]

  @Test func archivedGoLastKeepingOrder() {
    let names = PlaylistLogic.visible(items, query: "", visibility: .all).map(\.playlist.name)
    #expect(names == ["Sunday", "Youth", "Advent", "Old night"])
  }

  @Test func searchMatchesNameAndDescriptionCaseInsensitively() {
    let names = PlaylistLogic.visible(items, query: " NIGHT ", visibility: .all).map(\.playlist.name)
    #expect(names == ["Youth", "Old night"])
  }

  @Test func visibilityFilter() {
    #expect(PlaylistLogic.visible(items, query: "", visibility: .public).count == 2)
    #expect(
      PlaylistLogic.visible(items, query: "", visibility: .private).map(\.playlist.name)
        == ["Youth", "Old night"])
  }
}

@Suite struct PlaylistReorderTests {
  fileprivate let items = (1...4).map(Item.init)

  @Test func draggingDownTakesTheTargetsPlace() {
    #expect(PlaylistLogic.move(items, dragged: 1, onto: 3).map(\.id) == [2, 3, 1, 4])
  }

  @Test func draggingUpLandsBeforeTheTarget() {
    #expect(PlaylistLogic.move(items, dragged: 4, onto: 2).map(\.id) == [1, 4, 2, 3])
  }

  @Test func noOps() {
    #expect(PlaylistLogic.move(items, dragged: 2, onto: 2) == items)
    #expect(PlaylistLogic.move(items, dragged: 9, onto: 2) == items)
    #expect(PlaylistLogic.move(items, dragged: 2, onto: 9) == items)
  }
}

@Suite struct DraftCartTests {
  @Test func skipsSongsAlreadyInThePlaylistAndRepeats() {
    let a = UUID(), b = UUID(), c = UUID()
    #expect(PlaylistLogic.newSongs(adding: [a, b, a, c], to: [b]) == [a, c])
  }

  @Test func onlyDuplicatesLeavesNothing() {
    let a = UUID()
    #expect(PlaylistLogic.newSongs(adding: [a], to: [a]).isEmpty)
  }

  @Test func countLabelPluralises() {
    #expect(PlaylistLogic.countLabel(1, singular: "song", plural: "songs") == "1 song")
    #expect(PlaylistLogic.countLabel(0, singular: "song", plural: "songs") == "0 songs")
  }
}
