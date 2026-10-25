import Foundation
import Testing

import CapoChordPro

/// One case per directive or parser behaviour. Expected values were produced by running
/// features/lyrics-editor/utils/song-pipeline.ts on the same input; "THROW" means the web
/// pipeline throws and rendered-song.tsx shows the raw lyrics.
struct DirectiveCase: Decodable, CustomTestStringConvertible, Sendable {
  enum Expected: Decodable, Sendable {
    case segments([GoldenSegment])
    case throwsToRawLyrics

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let marker = try? container.decode(String.self), marker == "THROW" {
        self = .throwsToRawLyrics
      } else {
        self = .segments(try container.decode([GoldenSegment].self))
      }
    }
  }

  let name: String
  let lyrics: String
  let t: Int
  let c: Int
  let segs: Expected

  var testDescription: String { name }

  static let all: [DirectiveCase] = json.map {
    try! JSONDecoder().decode(DirectiveCase.self, from: Data($0.utf8))
  }

  private static let json: [String] = [
    ##"{"name":"comment","lyrics":"{c: Intro}\n[G]x\n{comment_box: Boxed}","t":0,"c":0,"segs":[{"type":"section","name":"Intro","sectionType":"comment","html":"","count":1,"flags":[],"inline":false},{"type":"normal","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">x</span></span>"},{"type":"section","name":"Boxed","sectionType":"comment","html":"","count":1,"flags":[],"inline":false}]}"##,
    ##"{"name":"commentLabelFlag","lyrics":"{c: Coda, label}","t":0,"c":0,"segs":[{"type":"section","name":"Coda","sectionType":"comment-label","html":"","count":1,"flags":[],"inline":false}]}"##,
    ##"{"name":"inlineCommentInContent","lyrics":"{sov: V}\n{c: Softly}\n[G]x\n{eov}","t":0,"c":0,"segs":[{"type":"section","name":"V","sectionType":"verse","html":"<div class=\"lyrics-comment\"><div class=\"lyrics-comment-label\">Note</div><div class=\"lyrics-comment-body\">Softly</div></div>\n<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">x</span></span>","count":1,"flags":[],"inline":false}]}"##,
    ##"{"name":"note","lyrics":"{note: Play <soft>}\n[G]x","t":0,"c":0,"segs":[{"type":"normal","html":"<span class=\"performance-note\">Play &lt;soft&gt;</span>\n<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">x</span></span>"}]}"##,
    ##"{"name":"sectionDefaults","lyrics":"{soc}\n[C]x\n{eoc}\n{soi}\n[D]y\n{eoi}","t":0,"c":0,"segs":[{"type":"section","name":"Chorus","sectionType":"chorus","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">C</span></span></span><span class=\"clp-lyric-text\">x</span></span>","count":1,"flags":[],"inline":false},{"type":"section","name":"intro","sectionType":"intro","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">D</span></span></span><span class=\"clp-lyric-text\">y</span></span>","count":1,"flags":[],"inline":false}]}"##,
    ##"{"name":"sectionValue","lyrics":"{sov: \"Verse 2\", 3, forte, vamp, label: Custom}\n[G]x\n{eov}","t":0,"c":0,"segs":[{"type":"section","name":"Verse 2","sectionType":"verse","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">x</span></span>","count":3,"flags":["forte","vamp"],"inline":false}]}"##,
    ##"{"name":"inlineSection","lyrics":"{sob: B, inline}\n  [G]  a   [C]   b  \n{eob}","t":0,"c":0,"segs":[{"type":"section","name":"B","sectionType":"bridge","html":"<span class=\"chord\">G</span> a <span class=\"chord\">C</span> b","count":1,"flags":["inline"],"inline":true}]}"##,
    ##"{"name":"volta","lyrics":"[G]a\n{sovt: 1.}\n[C]b\n{eovt}\n\n[D]c","t":0,"c":0,"segs":[{"type":"normal","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">a</span></span>\n<div class=\"volta-block\"><div class=\"volta-label\">1.</div><div class=\"volta-content\"><span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">C</span></span></span><span class=\"clp-lyric-text\">b</span></span></div></div>\n<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">D</span></span></span><span class=\"clp-lyric-text\">c</span></span>"}]}"##,
    ##"{"name":"box","lyrics":"{sbox: Bridge}\n[G]a\n{ebox}\n{sbox: Hidden, label}\n[C]b\n{ebox}","t":0,"c":0,"segs":[{"type":"normal","html":"<div class=\"lyrics-box\"><div class=\"lyrics-box-label\">Bridge</div><div class=\"lyrics-box-content\"><span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">a</span></span></div></div>\n\n<div class=\"lyrics-label\">Hidden</div>"}]}"##,
    ##"{"name":"repeat","lyrics":"{soc: Chorus}\n[G]la\n{eoc}\n{repeat: chorus, 2, inline}\n{repeat: Missing}","t":0,"c":0,"segs":[{"type":"section","name":"Chorus","sectionType":"chorus","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:2ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">la</span></span>","count":1,"flags":[],"inline":false},{"type":"repeat","name":"chorus","count":2,"html":"la<span class=\"chord\">G</span>","found":true,"sectionType":"chorus","flags":["inline"]},{"type":"repeat","name":"Missing","count":1,"html":"","found":false,"sectionType":"repeat","flags":[]}]}"##,
    ##"{"name":"extend","lyrics":"{soc: Chorus}\n[G]la\n{eoc}\n{start_of_extend: Chorus, label: \"More\"}\n[D]tag\n{end_of_extend}","t":0,"c":0,"segs":[{"type":"section","name":"Chorus","sectionType":"chorus","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:2ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">la</span></span>","count":1,"flags":[],"inline":false},{"type":"extend","name":"Chorus","displayLabel":"More","count":1,"html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:2ch\"><span class=\"chord\">G</span></span></span><span class=\"clp-lyric-text\">la</span></span>\n<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:3ch\"><span class=\"chord\">D</span></span></span><span class=\"clp-lyric-text\">tag</span></span>","found":true,"sectionType":"chorus","flags":[]}]}"##,
    ##"{"name":"keyDirective","lyrics":"[A#]before\n{key: Em}\n[A#]x [Gb]y [D/F#]z","t":1,"c":0,"segs":[{"type":"normal","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:6ch\"><span class=\"chord\">B</span></span></span><span class=\"clp-lyric-text\">before</span></span>\n\n<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:2ch\"><span class=\"chord\">B</span></span><span class=\"clp-col\" style=\"min-width:2ch\"><span class=\"chord\">G</span></span><span class=\"clp-col\" style=\"min-width:4ch\"><span class=\"chord\">Eb/G</span></span></span><span class=\"clp-lyric-text\">x y z</span></span>"}]}"##,
    ##"{"name":"capoTwoPass","lyrics":"[Am]x [F#m]y","t":1,"c":5,"segs":[{"type":"normal","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:3ch\"><span class=\"chord\">E#m</span></span><span class=\"clp-col\" style=\"min-width:2ch\"><span class=\"chord\">Dm</span></span></span><span class=\"clp-lyric-text\">x y</span></span>"}]}"##,
    ##"{"name":"escapesAndAnnotation","lyrics":"[G]x\\ y \\[z [*Coda]coda","t":0,"c":0,"segs":[{"type":"normal","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:4ch\"><span class=\"chord\">G</span></span><span class=\"clp-col\" style=\"min-width:3ch\"></span><span class=\"clp-col\" style=\"min-width:4ch\"></span></span><span class=\"clp-lyric-text\">x y [z coda</span></span>"}]}"##,
    ##"{"name":"softLineBreak","lyrics":"[G]a b c","t":0,"c":0,"segs":[{"type":"normal","html":"<span class=\"clp-pair\"><span class=\"clp-chords\"><span class=\"clp-col\" style=\"min-width:1ch\"><span class=\"chord\">G</span></span><span class=\"clp-col\" style=\"min-width:2ch\"></span><span class=\"clp-col\" style=\"min-width:1ch\"></span></span><span class=\"clp-lyric-text\">ab c</span></span>"}]}"##,
    ##"{"name":"hashCommentAutoInline","lyrics":"[G]a # note here","t":0,"c":0,"segs":[{"type":"normal","html":"a <span class=\"chord\">G</span> note here"}]}"##,
    ##"{"name":"unparseableFallsBack","lyrics":"[G\nok","t":0,"c":0,"segs":"THROW"}"##
  ]
}

@Suite struct DirectiveTests {
  @Test(arguments: DirectiveCase.all)
  func directive(_ testCase: DirectiveCase) {
    let options = ChordProRenderOptions(
      transpose: testCase.t, capo: testCase.c,
      sectionLabels: ["chorus": "Chorus", "verse": "Verse", "bridge": "Bridge"], commentLabel: "Note")
    let rendered = ChordProEngine.render(testCase.lyrics, options: options)
    switch testCase.segs {
    case .segments(let expected):
      #expect(rendered.segments.map { GoldenSegment($0, commentLabel: "Note") } == expected)
    case .throwsToRawLyrics:
      let raw = testCase.lyrics.split(separator: "\n", omittingEmptySubsequences: false)
        .map { BodyLine.text(String($0)) }
      #expect(rendered.segments == [.normal(SongBody(lines: raw))])
    }
  }

  @Test func complexSegmentsFlag() {
    let options = ChordProRenderOptions(transpose: 0, capo: 0, sectionLabels: [:], commentLabel: "")
    #expect(!ChordProEngine.render("[G]plain", options: options).hasComplexSegments)
    #expect(ChordProEngine.render("{soc}\n[G]x\n{eoc}", options: options).hasComplexSegments)
  }

  @Test func emptyLyricsRenderNothing() {
    let options = ChordProRenderOptions(transpose: 2, capo: 1, sectionLabels: [:], commentLabel: "")
    #expect(ChordProEngine.render("", options: options).segments.isEmpty)
  }
}
