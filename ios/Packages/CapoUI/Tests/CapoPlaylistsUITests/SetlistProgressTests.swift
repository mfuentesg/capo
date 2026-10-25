import Testing

@testable import CapoPlaylistsUI

@Suite struct SetlistProgressTests {
  @Test func marksDoneCurrentAndUpcoming() {
    #expect(
      SetlistProgress.segments(index: 2, count: 5) == [.done, .done, .current, .upcoming, .upcoming])
    #expect(SetlistProgress.segments(index: 0, count: 1) == [.current])
  }

  @Test func clampsAndHandlesEmpty() {
    #expect(SetlistProgress.segments(index: 9, count: 3) == [.done, .done, .current])
    #expect(SetlistProgress.segments(index: 0, count: 0).isEmpty)
  }

  @Test func peekDetail() {
    #expect(SetlistProgress.peekDetail(key: "D", bpm: 100, bpmLabel: "BPM") == "D · 100 BPM")
    #expect(SetlistProgress.peekDetail(key: nil, bpm: 100, bpmLabel: "BPM") == "100 BPM")
    #expect(SetlistProgress.peekDetail(key: "", bpm: 0, bpmLabel: "BPM") == nil)
  }
}
