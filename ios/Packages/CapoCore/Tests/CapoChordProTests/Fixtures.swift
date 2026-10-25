import Foundation

/// Locates ios/Fixtures relative to this file, so both `swift test` and simulator runs find it.
enum Fixtures {
  static let root: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // CapoChordProTests
    .deletingLastPathComponent()  // Tests
    .deletingLastPathComponent()  // CapoCore
    .deletingLastPathComponent()  // Packages
    .deletingLastPathComponent()  // ios
    .appendingPathComponent("Fixtures")

  static let golden = root.appendingPathComponent("golden")
  static let corpus = root.appendingPathComponent("corpus")

  static func goldenURL(_ name: String) -> URL { golden.appendingPathComponent(name) }

  static func exists(_ name: String) -> Bool {
    FileManager.default.fileExists(atPath: goldenURL(name).path)
  }

  static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(contentsOf: goldenURL(name)))
  }

  /// Golden pipeline files: every *.json except the chord and music-theory tables.
  static func pipelineGoldens() -> [String] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: golden.path)) ?? []
    return names.filter { $0.hasSuffix(".json") && $0 != "chords.json" && $0 != "music-theory.json" }
      .sorted()
  }
}

/// Collects mismatches so one failing test reports how many differ plus the first few.
struct Mismatches {
  private(set) var count = 0
  private(set) var samples: [String] = []

  mutating func check(_ actual: String, _ expected: String, _ label: @autoclosure () -> String) {
    guard actual != expected else { return }
    count += 1
    if samples.count < 10 { samples.append("\(label()): got \(actual) expected \(expected)") }
  }

  var summary: String { "\(count) mismatches\n" + samples.joined(separator: "\n") }
}
