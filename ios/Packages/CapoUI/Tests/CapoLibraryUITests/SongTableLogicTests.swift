import CapoDesign
import Foundation
import Testing

@testable import CapoLibraryUI

private func song(
  _ title: String, artist: String? = nil, key: String? = nil, bpm: Int? = nil, plays: Int = 0,
  lastPlayed: String? = nil, created: String = "2026-01-01T00:00:00Z"
) -> SongListItem {
  SongListItem(
    id: UUID(), title: title, artist: artist, key: key, bpm: bpm, status: .published, teamID: nil,
    hasLyrics: true, tags: [], hasPendingChanges: false, createdAt: ServerTimestamp(created),
    playCount: plays, lastPlayed: lastPlayed)
}

@Suite struct SongTableSortTests {
  @Test func headerTapTogglesDirectionAndSwitchingStartsNaturally() {
    var sort = SongTableSort.default
    #expect(sort.column == .title && sort.ascending)
    sort = sort.tapped(.title)
    #expect(!sort.ascending)
    sort = sort.tapped(.bpm)
    #expect(sort.column == .bpm && sort.ascending)
    sort = sort.tapped(.played)
    #expect(sort.column == .played && !sort.ascending)
  }

  @Test func titleSortIsNaturalAndDirectional() {
    let items = [song("Song 10"), song("song 2"), song("Alabaré")]
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.title)).map(\.title) == ["Alabaré", "song 2", "Song 10"])
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.title, ascending: false)).map(\.title) == ["Song 10", "song 2", "Alabaré"])
  }

  @Test func emptyValuesGoLastInBothDirections() {
    let items = [song("A", bpm: nil), song("B", bpm: 120), song("C", bpm: 80), song("D", bpm: 0)]
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.bpm)).map(\.title) == ["C", "B", "A", "D"])
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.bpm, ascending: false)).map(\.title) == ["B", "C", "A", "D"])
  }

  @Test func keyAndArtistSortFallBackToTitleOnTies() {
    let items = [song("Z", artist: "Marea", key: "G"), song("B", artist: "Marea", key: "G"), song("M", key: nil)]
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.key)).map(\.title) == ["B", "Z", "M"])
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.artist)).map(\.title) == ["B", "Z", "M"])
  }

  @Test func playedSortsByLastPlayedAndNeverPlayedLast() {
    let items = [
      song("old", plays: 1, lastPlayed: "2026-01-01"), song("never"),
      song("new", plays: 3, lastPlayed: "2026-05-01")
    ]
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.played)).map(\.title) == ["new", "old", "never"])
    #expect(SongTableLogic.sorted(items, by: SongTableSort(.played, ascending: true)).map(\.title) == ["old", "new", "never"])
  }

  @Test func ownerSortUsesTheProvidedLabels() {
    let a = song("a"), b = song("b"), c = song("c")
    let labels = [a.id: "Me", b.id: "Banda", c.id: ""]
    let sorted = SongTableLogic.sorted([a, b, c], by: SongTableSort(.owner)) { labels[$0.id] ?? "" }
    #expect(sorted.map(\.title) == ["b", "a", "c"])
  }
}

@Suite struct SongTableSectionTests {
  @Test func lettersFoldDiacriticsAndCase() {
    #expect(SongTableLogic.letter(of: "Alabaré") == "A")
    #expect(SongTableLogic.letter(of: "ábaco") == "A")
    #expect(SongTableLogic.letter(of: "  zeta") == "Z")
    #expect(SongTableLogic.letter(of: "99 Luftballons") == "#")
    #expect(SongTableLogic.letter(of: "¡Aleluya!") == "#")
    #expect(SongTableLogic.letter(of: nil) == "#")
  }

  @Test func titleSortGroupsConsecutiveLetters() {
    let items = [song("Alabaré"), song("Amazing"), song("Be"), song("Cuán")]
    let sections = SongTableLogic.sections(items, sort: SongTableSort(.title), grouping: .none)
    #expect(sections.map(\.title) == ["A", "B", "C"])
    #expect(sections[0].items.count == 2)
  }

  @Test func otherSortsAndGroupingChangeTheSections() {
    let items = [song("a", artist: "X", key: "G"), song("b", artist: "Y", key: "C")]
    #expect(SongTableLogic.sections(items, sort: SongTableSort(.bpm), grouping: .none).map(\.title) == [nil])
    #expect(SongTableLogic.sections(items, sort: nil, grouping: .none).count == 1)
    #expect(SongTableLogic.sections(items, sort: SongTableSort(.title), grouping: .key).map(\.title) == ["C", "G"])
    #expect(SongTableLogic.sections(items, sort: SongTableSort(.artist), grouping: .none).map(\.title) == ["X", "Y"])
  }
}

@Suite struct IndexScrubberTests {
  @Test func indexIsAToZThenHash() {
    #expect(SongTableLogic.indexLetters.count == 27)
    #expect(SongTableLogic.indexLetters.first == "A" && SongTableLogic.indexLetters[25] == "Z")
    #expect(SongTableLogic.indexLetters.last == "#")
  }

  @Test func fractionMapsToLettersAndClamps() {
    #expect(SongTableLogic.scrubLetter(fraction: 0) == "A")
    #expect(SongTableLogic.scrubLetter(fraction: -3) == "A")
    #expect(SongTableLogic.scrubLetter(fraction: 0.5) == "N")
    #expect(SongTableLogic.scrubLetter(fraction: 1) == "#")
    #expect(SongTableLogic.scrubLetter(fraction: 9) == "#")
  }

  @Test func scrubbingToAMissingLetterJumpsToTheNextPresentOne() {
    let available = ["A", "C", "M"]
    #expect(SongTableLogic.target(for: "C", available: available) == "C")
    #expect(SongTableLogic.target(for: "D", available: available) == "M")
    #expect(SongTableLogic.target(for: "Z", available: available) == "M")
    #expect(SongTableLogic.target(for: "B", available: []) == nil)
  }
}

@Suite struct SongTableLayoutTests {
  @Test func phoneAndNarrowWindowsStayCompact() {
    let phone = SongTableLogic.Layout(width: 390, isRegularSizeClass: false, showsOwnership: true)
    #expect(phone.mode == .compact && !phone.showsOwnerColumn && !phone.showsOwnerDot)
    let slideOver = SongTableLogic.Layout(width: 420, isRegularSizeClass: true, showsOwnership: true)
    #expect(slideOver.mode == .compact)
  }

  @Test func landscapeShowsOwnerColumnPortraitShowsDot() {
    let landscape = SongTableLogic.Layout(width: 1180, isRegularSizeClass: true, showsOwnership: true)
    #expect(landscape.mode == .regular && landscape.showsOwnerColumn && !landscape.showsOwnerDot)
    let portrait = SongTableLogic.Layout(width: 820, isRegularSizeClass: true, showsOwnership: true)
    #expect(portrait.mode == .regular && !portrait.showsOwnerColumn && portrait.showsOwnerDot)
    let single = SongTableLogic.Layout(width: 1180, isRegularSizeClass: true, showsOwnership: false)
    #expect(!single.showsOwnerColumn && !single.showsOwnerDot)
  }
}
