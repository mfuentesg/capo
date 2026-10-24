import Foundation
import Testing

@testable import CapoEditorUI

/// `ios/Fixtures/converter/cifraclub.json`, generated from the web parser by
/// `npx tsx ios/scripts/gen-cifraclub-golden.ts`.
@MainActor @Suite struct CifraClubParserTests {
  struct Fixture: Decodable {
    struct Page: Decodable {
      struct Result: Decodable {
        struct Data: Decodable {
          let title: String
          let artist: String
          let key: String
          let lyrics: String
          let keyFound: Bool
        }
        let success: Bool
        let data: Data?
        let error: String?
      }
      let url: String
      let html: String
      let result: Result
    }
    struct URLCase: Decodable {
      let url: String
      let result: String
    }
    let pages: [Page]
    let urls: [URLCase]
  }

  static let fixture: Fixture? = {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
      .appendingPathComponent("Fixtures/converter/cifraclub.json")
    return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Fixture.self, from: $0) }
  }()

  @Test func parsesLikeTheWeb() throws {
    let fixture = try #require(Self.fixture)
    for page in fixture.pages {
      let url = try #require(URL(string: page.url))
      let actual = CifraClubParser.parse(html: page.html, url: url)
      switch (actual, page.result.success) {
      case (.success(let song), true):
        let expected = try #require(page.result.data)
        #expect(song.title == expected.title, "title \(page.url)")
        #expect(song.artist == expected.artist, "artist \(page.url)")
        #expect(song.key == expected.key, "key \(page.url)")
        #expect(song.keyFound == expected.keyFound, "keyFound \(page.url)")
        #expect(song.lyrics == expected.lyrics, "lyrics \(page.url)")
      case (.failure(let error), false):
        #expect(error.rawValue == page.result.error)
      default:
        Issue.record("success mismatch for \(page.url)")
      }
    }
  }

  @Test func validatesHosts() throws {
    let fixture = try #require(Self.fixture)
    for item in fixture.urls {
      let result = CifraClubParser.validate(item.url)
      switch result {
      case .success: #expect(item.result == "ok", "\(item.url)")
      case .failure(let error): #expect(error.rawValue == item.result, "\(item.url)")
      }
    }
  }
}
