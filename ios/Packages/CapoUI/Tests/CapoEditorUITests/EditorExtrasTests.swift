import CapoDesign
import Foundation
import Testing

@testable import CapoEditorUI

@MainActor @Suite struct SectionWrapTests {
  private let verse = SectionType.all[0]
  private let chorus = SectionType.all[2]

  @Test func firstSectionUsesPlainLabel() {
    #expect(verse.wrap("[G]Amazing", in: "[G]Amazing") == "{sov: Verse}\n[G]Amazing\n{eov}")
  }

  @Test func countsExistingSectionsInBothSpellings() {
    let lyrics = "{sov: Verse}\na\n{eov}\n{start_of_verse: Verse 2}\nb\n{end_of_verse}\n{SOV}\nc"
    #expect(verse.sectionName(in: lyrics) == "Verse 4")
    #expect(chorus.sectionName(in: lyrics) == "Chorus")
  }

  @Test func pairsMatchTheWeb() {
    #expect(SectionType.all.map(\.start) == ["sov", "sopc", "soc", "sob", "soi", "soo"])
    #expect(SectionType.all.map(\.end) == ["eov", "eopc", "eoc", "eob", "eoi", "eoo"])
    #expect(SectionType.all[1].sectionName(in: "{start_of_prechorus: x}") == "Pre-Chorus 2")
  }
}

@MainActor @Suite struct EditorModelExtrasTests {
  @Test func parseChordsConvertsChordsOverWords() {
    let model = SongEditorModel()
    model.form.lyrics = "Em      C\nAmazing grace"
    #expect(model.parseChords() == .converted)
    #expect(model.form.lyrics == "[Em]Amazing [C]grace")
  }

  @Test func parseChordsLeavesChordProAlone() {
    let model = SongEditorModel()
    model.form.lyrics = "[G]Amazing [D]grace"
    #expect(model.parseChords() == .alreadyChordPro)
    #expect(model.form.lyrics == "[G]Amazing [D]grace")
  }

  @Test func importFillsDetailsOnlyForABlankNewSong() {
    let song = CifraClubSong(title: "Eres Fiel", artist: "Israel Houghton", key: "Em", lyrics: "[Em]x", keyFound: true)
    let fresh = SongEditorModel()
    fresh.apply(import: song)
    #expect(fresh.form.title == "Eres Fiel" && fresh.form.artist == "Israel Houghton" && fresh.form.key == "Em")
    #expect(fresh.form.lyrics == "[Em]x")

    let typed = SongEditorModel()
    typed.form.title = "Mine"
    typed.apply(import: song)
    #expect(typed.form.title == "Mine" && typed.form.lyrics == "[Em]x")
  }
}

@MainActor @Suite struct ReferenceTests {
  @Test func dataMatchesTheWebDocs() {
    #expect(ReferenceData.directives.count == 38)
    #expect(ReferenceData.flags.count == 9)
    #expect(ReferenceData.directives.first?.name == "title")
    #expect(ReferenceDirective.directives(in: .metadata).count == 14)
  }

  @Test func copyDropsAnnotations() {
    #expect(cleanReferenceExample("{c: A}    ← note\n[G]x  \n") == "{c: A}\n[G]x")
  }
}

private nonisolated func httpResponse(_ url: URL, _ status: Int, headers: [String: String] = [:]) -> HTTPURLResponse {
  HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
}

private let samplePage = """
  <html><body><div>Tom: G</div><pre>G   D
  Amazing grace
  Em  C
  How sweet</pre></body></html>
  """

@MainActor @Suite struct CifraClubImporterTests {

  @Test func importsAfterValidation() async {
    let importer = CifraClubImporter { url in (Data(samplePage.utf8), httpResponse(url, 200)) }
    let result = await importer.importSong(from: " https://www.cifraclub.com/john-newton/amazing-grace/ ")
    guard case .success(let song) = result else { Issue.record("expected success: \(result)"); return }
    #expect(song.title == "Amazing Grace" && song.artist == "John Newton" && song.key == "G")
  }

  @Test func rejectsBadInputBeforeFetching() async {
    let importer = CifraClubImporter { _ in Issue.record("must not fetch"); throw URLError(.cancelled) }
    #expect(await importer.importSong(from: "nope") == .failure(.invalidURL))
    #expect(await importer.importSong(from: "https://evil.example/a/b") == .failure(.wrongHost))
    #expect(await importer.importSong(from: "   ") == .failure(.invalidURL))
  }

  @Test func mapsTransportAndStatusErrors() async {
    let url = "https://www.cifraclub.com/a/b/"
    #expect(await CifraClubImporter { _ in throw URLError(.timedOut) }.importSong(from: url) == .failure(.network))
    let forbidden = CifraClubImporter { u in (Data(), httpResponse(u, 403)) }
    #expect(await forbidden.importSong(from: url) == .failure(.httpStatus))
    let huge = CifraClubImporter { u in (Data(count: 3_000_001), httpResponse(u, 200)) }
    #expect(await huge.importSong(from: url) == .failure(.httpStatus))
  }

  @Test func recheckRedirectTargets() async {
    let url = "https://www.cifraclub.com/a/b/"
    let off = CifraClubImporter { u in (Data(), httpResponse(u, 302, headers: ["Location": "https://evil.example/x"])) }
    #expect(await off.importSong(from: url) == .failure(.wrongHost))
    let loop = CifraClubImporter { u in (Data(), httpResponse(u, 301, headers: ["Location": "/a/b/"])) }
    #expect(await loop.importSong(from: url) == .failure(.httpStatus))
    let counter = Counter()
    let follows = CifraClubImporter { u in
      if await counter.next() == 0 { return (Data(), httpResponse(u, 301, headers: ["Location": "/c/d/"])) }
      return (Data(samplePage.utf8), httpResponse(u, 200))
    }
    guard case .success(let song) = await follows.importSong(from: url) else { Issue.record("redirect"); return }
    #expect(song.title == "B")
  }

  @Test func noChordBlock() async {
    let importer = CifraClubImporter { u in (Data("<html><body>x</body></html>".utf8), httpResponse(u, 200)) }
    #expect(await importer.importSong(from: "https://www.cifraclub.com/a/b/") == .failure(.noChordBlock))
  }
}

private actor Counter {
  private var value = 0
  func next() -> Int {
    defer { value += 1 }
    return value
  }
}

extension Result: @retroactive Equatable where Success == CifraClubSong, Failure == CifraClubError {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.success(let a), .success(let b)): a == b
    case (.failure(let a), .failure(let b)): a == b
    default: false
    }
  }
}
