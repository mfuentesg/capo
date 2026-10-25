import Foundation
import Testing

/// Guards the string catalog: every `ios.*` key referenced from source exists with an English
/// and a Spanish translation. Reads the catalog and sources from the checkout (via `#filePath`).
@Suite struct LocalizationCatalogTests {
  private static let sources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("Sources")

  private static func catalog() throws -> [String: [String: Any]] {
    let url = sources.appendingPathComponent("CapoDesign/Resources/Localizable.xcstrings")
    let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    return try #require(root["strings"] as? [String: [String: Any]])
  }

  private static func value(_ entry: [String: Any], _ lang: String) -> String? {
    let locs = entry["localizations"] as? [String: Any]
    let unit = (locs?[lang] as? [String: Any])?["stringUnit"] as? [String: Any]
    return unit?["value"] as? String
  }

  @Test func everyCatalogKeyHasEnglishAndSpanish() throws {
    for (key, entry) in try Self.catalog() {
      #expect(Self.value(entry, "en")?.isEmpty == false, "missing en: \(key)")
      #expect(Self.value(entry, "es")?.isEmpty == false, "missing es: \(key)")
    }
  }

  @Test func iosKeysUsedInSourceExistInCatalog() throws {
    let catalog = try Self.catalog()
    let regex = try NSRegularExpression(pattern: #"localized:\s*"(ios\.[A-Za-z0-9_.]+)""#)
    let files = try #require(
      FileManager.default.enumerator(at: Self.sources, includingPropertiesForKeys: nil))
    var checked = 0
    for case let url as URL in files where url.pathExtension == "swift" {
      let text = try String(contentsOf: url, encoding: .utf8)
      let range = NSRange(text.startIndex..., in: text)
      for match in regex.matches(in: text, range: range) {
        let key = String(text[Range(match.range(at: 1), in: text)!])
        #expect(catalog[key] != nil, "\(url.lastPathComponent) uses unknown key \(key)")
        checked += 1
      }
    }
    #expect(checked > 100)
  }

  @Test func spanishDiffersFromEnglishForUserFacingStrings() throws {
    let entry = try #require(try Self.catalog()["ios.shell.retry"])
    #expect(Self.value(entry, "es") == "Reintentar")
    #expect(Self.value(entry, "en") == "Try again")
  }
}
