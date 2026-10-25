import Foundation
import SwiftUI
import Testing
import UIKit

@testable import CapoRendering

@Suite struct RenderUnitTests {
  @Test func blankChordColumnsStayWithTheFollowingWord() {
    let pairs = [
      ChordLyricPair(chord: "G", lyrics: "Amazing "),
      ChordLyricPair(chord: "Dm7", lyrics: " "),
      ChordLyricPair(chord: "", lyrics: "está"),
      ChordLyricPair(chord: "C", lyrics: "end")
    ]
    let units = ChordLyricsLineView.units(pairs)
    #expect(units.map { $0.count } == [1, 2, 1])
    #expect(units[1].map(\.lyrics) == [" ", "está"])
  }

  @Test func normalSegmentSplitsAfterBlankLines() {
    let song = RenderedSong(segments: [
      .normal(SongBody(lines: [.text("a"), .text(""), .text("b"), .text("c"), .text(""), .text("d")]))
    ])
    let units = RenderUnit.units(for: song)
    #expect(units.count == 3)
    #expect(units.map(\.id) == [0, 1, 2])
  }

  @Test func sectionsStayAtomic() {
    let body = SongBody(lines: [.text("x"), .text(""), .text("y")])
    let song = RenderedSong(segments: [
      .section(name: "Verse", sectionType: "verse", body: body, count: 1, flags: [], inline: false),
      .repeatRef(
        name: "Verse", displayLabel: nil, count: 2, body: body, found: true, sectionType: "verse",
        flags: [])
    ])
    #expect(RenderUnit.units(for: song).count == 2)
  }

  @Test func headerTitleShowsCount() {
    #expect(SegmentView.title("Chorus", 1) == "Chorus")
    #expect(SegmentView.title("Chorus", 3) == "Chorus × 3")
  }
}

@Suite(.serialized) @MainActor struct RenderingIntegrationTests {
  static let corpus: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Fixtures/corpus")

  static let options = ChordProRenderOptions(
    transpose: 0, capo: 0,
    sectionLabels: ["verse": "Verse", "chorus": "Chorus"], commentLabel: "Comment")

  func height(of song: RenderedSong, width: CGFloat, columns: Int = 1) -> CGFloat {
    var style = SongRenderStyle()
    style.columns = columns
    let host = UIHostingController(rootView: ChordProContentView(rendered: song, style: style))
    return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
  }

  @Test func corpusFilesLayOutWithPositiveHeight() throws {
    let files = try FileManager.default.contentsOfDirectory(
      at: Self.corpus, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "cho" }
    #expect(!files.isEmpty)
    for file in files {
      let text = try String(contentsOf: file, encoding: .utf8)
      let song = ChordProEngine.render(text, options: Self.options)
      #expect(height(of: song, width: 800) > 0, "\(file.lastPathComponent)")
    }
  }

  @Test func twoColumnsAreShorterThanOne() {
    let lines = (0..<60).map { i -> BodyLine in
      i % 6 == 5 ? .text("") : .chordLyrics([ChordLyricPair(chord: "Am", lyrics: "line \(i) ")])
    }
    let song = RenderedSong(segments: [.normal(SongBody(lines: lines))])
    let one = height(of: song, width: 1000, columns: 1)
    let two = height(of: song, width: 1000, columns: 2)
    #expect(two < one * 0.65)
  }

  @Test func layoutOf300LineSongIsFast() {
    let pairs = (0..<6).map { ChordLyricPair(chord: ["C", "G", "Am", "F"][$0 % 4], lyrics: "word\($0) ") }
    let lines = (0..<300).map { i -> BodyLine in
      i % 5 == 4 ? .text("") : .chordLyrics(pairs)
    }
    let song = RenderedSong(segments: [.normal(SongBody(lines: lines))])
    _ = height(of: song, width: 1000, columns: 2)  // warm up
    let clock = ContinuousClock()
    // Best of three: other suites run in parallel on the same runner, so a single sample can be
    // inflated by scheduling noise unrelated to layout cost.
    let elapsed = (0..<3).map { _ in
      clock.measure { _ = height(of: song, width: 1000, columns: 2) }
    }.min()!
    print("WP7a perf: 300-line hosted layout = \(elapsed)")
    // Coarse guard only: debug build on a simulator, hosted layout. The real 16 ms/frame budget
    // must be measured with a Release build on a device (see ios/docs/wp-notes/WP7a.md).
    // Shared CI runners measured 1.3 s for this debug build, so the guard only catches a
    // regression of an order of magnitude.
    #expect(elapsed < .seconds(3))
  }

  @Test func pureMathIsUnderOneFrame() {
    let sizes = (0..<8).map { _ in CGSize(width: 70, height: 40) }
    let clock = ContinuousClock()
    let elapsed = clock.measure {
      for _ in 0..<300 { _ = ChordLyricsArrangeMath.arrange(sizes: sizes, maxWidth: 400, rowSpacing: 2) }
    }
    #expect(elapsed < .milliseconds(16))
  }
}
