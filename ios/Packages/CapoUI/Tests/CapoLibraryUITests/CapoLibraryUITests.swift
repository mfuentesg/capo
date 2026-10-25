import CapoDesign
import Foundation
import Testing

@testable import CapoLibraryUI

private let ctx = AppContext.personal(userID: UUID())

@Suite struct LibraryFiltersTests {
  @Test func defaultsMapToPlainQuery() {
    let q = LibraryFilters().query(context: ctx)
    #expect(q.searchText == "")
    #expect(q.tagIDs.isEmpty)
    #expect(q.statuses == [.published, .draft])
    #expect(q.bpmRange == nil)
    #expect(q.sort == .recent)
  }

  @Test func searchSwitchesToRelevanceAndTrims() {
    var f = LibraryFilters()
    f.searchText = "  canci  "
    let q = f.query(context: ctx)
    #expect(q.searchText == "canci")
    #expect(q.sort == .relevance)
  }

  @Test func relevanceFallsBackWithoutSearch() {
    var f = LibraryFilters()
    f.sort = .relevance
    #expect(f.query(context: ctx).sort == .recent)
    f.sort = .title
    f.searchText = "x"
    #expect(f.query(context: ctx).sort == .title)
    #expect(f.availableSorts.first == .relevance)
  }

  @Test func bpmBuckets() {
    // Thresholds the web filter applies (song-list.tsx): <100, 100...140, >140.
    #expect(BPMBucket.slow.range.contains(99) && !BPMBucket.slow.range.contains(100))
    #expect(BPMBucket.medium.range == 100...140)
    #expect(BPMBucket.fast.range.contains(141) && !BPMBucket.fast.range.contains(140))
    var f = LibraryFilters()
    f.bpm = .medium
    #expect(f.query(context: ctx).bpmRange == 100...140)
  }

  @Test func tagsToggleAndStatusNeverEmpty() {
    var f = LibraryFilters()
    let tag = UUID()
    f.toggle(tag: tag)
    #expect(f.query(context: ctx).tagIDs == [tag])
    f.toggle(tag: tag)
    #expect(f.tagIDs.isEmpty)
    f.toggle(status: .draft)
    f.toggle(status: .published)
    #expect(f.statuses == [.published])
    f.toggle(status: .archived)
    #expect(f.statuses == [.published, .archived])
  }

  @Test func activeFilterCountAndReset() {
    var f = LibraryFilters()
    f.toggle(tag: UUID())
    f.bpm = .fast
    f.toggle(status: .archived)
    f.grouping = .key
    #expect(f.activeFilterCount == 4)
    f.resetFilters()
    #expect(f.activeFilterCount == 0 && !f.isNarrowed)
  }
}

@MainActor @Suite struct DebounceTests {
  @Test func commitsAfterDelay() async {
    let model = LibraryModel()
    model.searchInput = "abc"
    let ok = await model.commitSearchAfterDebounce(delay: .milliseconds(10))
    #expect(ok)
    #expect(model.filters.searchText == "abc")
  }

  @Test func cancellationSkipsCommit() async {
    let model = LibraryModel()
    model.searchInput = "abc"
    let task = Task { await model.commitSearchAfterDebounce(delay: .seconds(5)) }
    task.cancel()
    #expect(await task.value == false)
    #expect(model.filters.searchText == "")
  }

  @Test func restartedTaskOnlyCommitsLatest() async {
    let model = LibraryModel()
    model.searchInput = "a"
    let first = Task { await model.commitSearchAfterDebounce(delay: .seconds(5)) }
    first.cancel()
    model.searchInput = "ab"
    _ = await model.commitSearchAfterDebounce(delay: .milliseconds(10))
    #expect(await first.value == false)
    #expect(model.filters.searchText == "ab")
  }

  @Test func debounceIs150ms() {
    #expect(LibraryDebounce.search == .milliseconds(150))
  }
}

@Suite struct SongBadgeTests {
  @Test func bpmIconAndColourTiersMatchWeb() {
    #expect(SongBadgeLogic.iconTier(bpm: 89) == .turtle)
    #expect(SongBadgeLogic.iconTier(bpm: 90) == .rabbit)
    #expect(SongBadgeLogic.iconTier(bpm: 120) == .rabbit)
    #expect(SongBadgeLogic.iconTier(bpm: 121) == .zap)
    #expect(SongBadgeLogic.colorTier(bpm: 89) == .slow)
    #expect(SongBadgeLogic.colorTier(bpm: 130) == .steady)
    #expect(SongBadgeLogic.colorTier(bpm: 131) == .fast)
  }

  @Test func recentlyPlayedWindowIs14Days() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(SongBadgeLogic.isRecentlyPlayed(lastPlayed: now.addingTimeInterval(-14 * 86_400), now: now))
    #expect(!SongBadgeLogic.isRecentlyPlayed(lastPlayed: now.addingTimeInterval(-15 * 86_400), now: now))
    #expect(!SongBadgeLogic.isRecentlyPlayed(lastPlayed: now.addingTimeInterval(86_400), now: now))
    #expect(!SongBadgeLogic.isRecentlyPlayed(lastPlayed: nil, now: now))
  }

  @Test func compactRelativeTime() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(SongBadgeLogic.compactRelative(now.addingTimeInterval(-30), now: now) == "now")
    #expect(SongBadgeLogic.compactRelative(now.addingTimeInterval(-5 * 60), now: now) == "5m")
    #expect(SongBadgeLogic.compactRelative(now.addingTimeInterval(-3 * 3600), now: now) == "3h")
    #expect(SongBadgeLogic.compactRelative(now.addingTimeInterval(-2 * 86_400), now: now) == "2d")
    #expect(SongBadgeLogic.compactRelative(now.addingTimeInterval(-21 * 86_400), now: now) == "3w")
    #expect(SongBadgeLogic.compactRelative(now.addingTimeInterval(-120 * 86_400), now: now) == "4mo")
  }

  @Test func parsesPlainDatesAndTimestamps() {
    #expect(SongBadgeLogic.parseDate("2026-03-01") != nil)
    #expect(SongBadgeLogic.parseDate("2026-03-01T10:00:00+00:00") != nil)
    #expect(SongBadgeLogic.parseDate(nil) == nil)
  }

  @Test func bucketSlotsCycleThroughSevenColours() {
    let teams = (0..<9).map { _ in UUID() }
    #expect(SongBadgeLogic.bucketSlot(teamID: teams[0], teams: teams) == 0)
    #expect(SongBadgeLogic.bucketSlot(teamID: teams[7], teams: teams) == 0)
    #expect(SongBadgeLogic.bucketSlot(teamID: teams[8], teams: teams) == 1)
    #expect(SongBadgeLogic.bucketSlot(teamID: UUID(), teams: teams) == 0)
  }
}

@Suite struct GroupingTests {
  private func item(_ title: String, key: String?, artist: String?) -> SongListItem {
    SongListItem(
      id: UUID(), title: title, artist: artist, key: key, bpm: 100, status: .published, teamID: nil,
      hasLyrics: true, tags: [], hasPendingChanges: false, createdAt: ServerTimestamp("2026-01-01T00:00:00Z"))
  }

  @Test func noneKeepsOrderInOneUntitledGroup() {
    let items = [item("b", key: "G", artist: "x"), item("a", key: "C", artist: "y")]
    let groups = SongGrouping.groups(items, by: .none)
    #expect(groups.count == 1 && groups[0].title == nil && groups[0].items.map(\.title) == ["b", "a"])
  }

  @Test func keyGroupsSortAndPutMissingLast() {
    let items = [item("1", key: "G", artist: nil), item("2", key: nil, artist: nil), item("3", key: "C", artist: nil), item("4", key: "G", artist: nil)]
    let groups = SongGrouping.groups(items, by: .key)
    #expect(groups.map(\.title) == ["C", "G", "—"])
    #expect(groups[1].items.map(\.title) == ["1", "4"])
  }
}
