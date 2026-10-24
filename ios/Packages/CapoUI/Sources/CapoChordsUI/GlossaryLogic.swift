import CapoRendering
import Foundation

/// One glossary card: a database key and suffix with the positions the web would show.
nonisolated struct ChordEntry: Identifiable, Hashable {
  var key: String
  var suffix: String
  var id: String { "\(key)-\(suffix)" }

  /// Web `keyLabel`: "Csharp" to "C#".
  static func keyLabel(_ key: String) -> String { key.replacingOccurrences(of: "sharp", with: "#") }

  /// Web `name`: "Aminor" for the minor chord.
  var webName: String { suffix == "major" ? Self.keyLabel(key) : Self.keyLabel(key) + suffix }

  /// Name as the design shows it and as chord symbols are written: "Am", "A7", "Amaj7", "A/E".
  var displayName: String {
    let root = Self.keyLabel(key)
    switch suffix {
    case "major": return root
    case "minor": return root + "m"
    default: return root + suffix
    }
  }
}

enum ChordGlossary {
  static let keys: [String] = GlossaryOrder.entries.map(\.key)

  static let all: [ChordEntry] = GlossaryOrder.entries.flatMap { entry in
    entry.suffixes.map { ChordEntry(key: entry.key, suffix: $0) }
  }

  static func entries(forKey key: String) -> [ChordEntry] { all.filter { $0.key == key } }

  /// Web `useChordSearch`: key chip narrows first, then the text filter.
  static func filter(query: String, key: String?) -> [ChordEntry] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let pool = key.map(entries(forKey:)) ?? all
    guard !q.isEmpty else { return pool }
    let normalized = q.replacingOccurrences(of: "#", with: "sharp")
    return pool.filter { entry in
      let names = [entry.webName.lowercased(), entry.displayName.lowercased()]
      if names.contains(where: { $0.contains(q) }) || entry.suffix.lowercased().contains(q) { return true }
      return key == nil && entry.key.lowercased() == normalized
    }
  }

  static func firstPosition(_ entry: ChordEntry, database: ChordDatabase = .shared) -> ChordPosition? {
    database.positions(key: entry.key, suffix: entry.suffix).first
  }
}
