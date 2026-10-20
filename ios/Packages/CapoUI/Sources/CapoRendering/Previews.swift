#if DEBUG
import CapoDesign
import SwiftUI

private enum PreviewData {
  static let options = ChordProRenderOptions(
    transpose: 0, capo: 0,
    sectionLabels: ["verse": "Verse", "chorus": "Chorus", "bridge": "Bridge"],
    commentLabel: "Comment")

  static let pairs = [
    ChordLyricPair(chord: "C", lyrics: "Amazing "),
    ChordLyricPair(chord: "G/B", lyrics: "grace, how "),
    ChordLyricPair(chord: "Am7", lyrics: "sweet the "),
    ChordLyricPair(chord: "", lyrics: "sound")
  ]

  static let line = BodyLine.chordLyrics(pairs)

  static let handBuilt = RenderedSong(segments: [
    .normal(SongBody(lines: [.text(""), .comment("Capo 2, slowly"), line, .text("")])),
    .section(
      name: "Verse", sectionType: "verse", body: SongBody(lines: [line, line, .text("")]),
      count: 1, flags: [.attention, .forte], inline: false),
    .section(
      name: "Chorus", sectionType: "chorus",
      body: SongBody(lines: [
        line, .inline([.chord("C"), .text(" and "), .chord("G"), .text(" hold")]),
        .performanceNote("band in"),
        .volta(label: "1.", body: SongBody(lines: [line])),
        .box(label: "Tag", body: SongBody(lines: [line]))
      ]), count: 2, flags: [.vamp], inline: false),
    .repeatRef(
      name: "Verse", displayLabel: nil, count: 2, body: SongBody(lines: [line]), found: true,
      sectionType: "verse", flags: []),
    .repeatRef(
      name: "Missing", displayLabel: nil, count: 1, body: SongBody(lines: []), found: false,
      sectionType: "repeat", flags: [])
  ])

  static func corpus(_ name: String) -> RenderedSong {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Fixtures/corpus/\(name).cho")
    let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "{title: missing \(name)}"
    return ChordProEngine.render(text, options: options)
  }
}

#Preview("Hand-built, 2 columns") {
  var style = SongRenderStyle()
  style.columns = 2
  style.commentLabel = "Comment"
  return ScrollView { ChordProContentView(rendered: PreviewData.handBuilt, style: style).padding() }
}

#Preview("Dark, large font, chords only") {
  var style = SongRenderStyle()
  style.fontScale = 1.5
  style.showLyrics = false
  return ScrollView { ChordProContentView(rendered: PreviewData.handBuilt, style: style).padding() }
    .preferredColorScheme(.dark)
}

#Preview("Corpus: volta-box-comment") {
  var style = SongRenderStyle()
  style.commentLabel = "Comment"
  return ScrollView {
    ChordProContentView(rendered: PreviewData.corpus("volta-box-comment"), style: style).padding()
  }
}

#Preview("Corpus: repeat-and-extend, 2 col") {
  var style = SongRenderStyle()
  style.columns = 2
  return ScrollView {
    ChordProContentView(rendered: PreviewData.corpus("repeat-and-extend"), style: style).padding()
  }
}
#endif
