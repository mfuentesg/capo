import Foundation
import Testing

import CapoChordPro

/// One segment exactly as song-pipeline.ts emits it (JSON.stringify drops undefined fields).
struct GoldenSegment: Codable, Equatable, Sendable, CustomStringConvertible {
  var type: String
  var name: String?
  var sectionType: String?
  var html: String
  var count: Int?
  var flags: [String]?
  var inline: Bool?
  var found: Bool?
  var displayLabel: String?

  init(_ segment: LyricsSegment, commentLabel: String) {
    func html(_ body: SongBody) -> String {
      LegacyHTMLSerializer.html(body, commentLabel: commentLabel)
    }
    switch segment {
    case .normal(let body):
      type = "normal"
      self.html = html(body)
    case .section(let name, let sectionType, let body, let count, let flags, let inline):
      type = "section"
      self.name = name
      self.sectionType = sectionType
      self.html = html(body)
      self.count = count
      self.flags = flags.map(\.rawValue)
      self.inline = inline
    case .repeatRef(let name, let displayLabel, let count, let body, let found, let sectionType, let flags):
      type = "repeat"
      self.name = name
      self.displayLabel = displayLabel
      self.count = count
      self.html = html(body)
      self.found = found
      self.sectionType = sectionType
      self.flags = flags.map(\.rawValue)
    case .extend(let name, let displayLabel, let count, let body, let found, let sectionType, let flags):
      type = "extend"
      self.name = name
      self.displayLabel = displayLabel
      self.count = count
      self.html = html(body)
      self.found = found
      self.sectionType = sectionType
      self.flags = flags.map(\.rawValue)
    }
  }

  var description: String {
    let data = (try? JSONEncoder().encode(self)) ?? Data()
    return String(decoding: data, as: UTF8.self)
  }
}

struct GoldenFile: Decodable {
  struct Case: Decodable {
    let transpose: Int
    let capo: Int
    let segments: [GoldenSegment]
  }

  let source: String
  let sectionLabels: [String: String]
  let commentLabel: String
  let cases: [Case]
}

@Suite struct GoldenPipelineTests {
  @Test func corpusHasGoldens() {
    #expect(Fixtures.pipelineGoldens().count >= 8)
  }

  @Test(arguments: Fixtures.pipelineGoldens())
  func matchesGolden(_ file: String) throws {
    let golden = try Fixtures.decode(GoldenFile.self, file)
    let lyrics = try String(
      contentsOf: Fixtures.corpus.appendingPathComponent(golden.source), encoding: .utf8)
    for goldenCase in golden.cases {
      let options = ChordProRenderOptions(
        transpose: goldenCase.transpose, capo: goldenCase.capo,
        sectionLabels: golden.sectionLabels, commentLabel: golden.commentLabel)
      let actual = ChordProEngine.render(lyrics, options: options).segments.map {
        GoldenSegment($0, commentLabel: golden.commentLabel)
      }
      let label = "\(file) t=\(goldenCase.transpose) capo=\(goldenCase.capo)"
      #expect(actual.count == goldenCase.segments.count, "\(label): segment count")
      for (index, (got, expected)) in zip(actual, goldenCase.segments).enumerated() {
        #expect(got == expected, "\(label) segment \(index)\n got: \(got)\nwant: \(expected)")
      }
    }
  }
}
