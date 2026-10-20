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
    #expect(BPMBucket.slow.range.contains(89) && !BPMBucket.slow.range.contains(90))
    #expect(BPMBucket.medium.range == 90...120)
    #expect(BPMBucket.fast.range.contains(121) && !BPMBucket.fast.range.contains(120))
    var f = LibraryFilters()
    f.bpm = .medium
    #expect(f.query(context: ctx).bpmRange == 90...120)
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
    #expect(f.activeFilterCount == 3)
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
