import Foundation
import Testing

@testable import CapoDesign

@MainActor
@Suite struct PlaylistDraftStoreTests {
  @Test func toggleKeepsTapOrderAndRemoves() {
    let a = UUID(), b = UUID(), c = UUID()
    let draft = PlaylistDraftStore()
    draft.toggle(a); draft.toggle(b); draft.toggle(c)
    draft.toggle(b)
    #expect(draft.ids == [a, c])
    #expect(draft.contains(a) && !draft.contains(b))
  }

  @Test func addSkipsDuplicatesAndKeepsExistingOrder() {
    let a = UUID(), b = UUID()
    let draft = PlaylistDraftStore(ids: [a])
    draft.add([b, a])
    #expect(draft.ids == [a, b])
  }

  @Test func moveReordersAndClearEmpties() {
    let a = UUID(), b = UUID(), c = UUID()
    let draft = PlaylistDraftStore(ids: [a, b, c])
    draft.move(from: IndexSet(integer: 2), to: 0)
    #expect(draft.ids == [c, a, b])
    draft.remove(a)
    #expect(draft.ids == [c, b])
    draft.clear()
    #expect(draft.ids.isEmpty)
  }
}
