import GRDB
import Testing

// Throwaway WP0 smoke test proving GRDB ships with FTS5 enabled. Owned by WP3a afterwards.
@Test func fts5IsAvailableWithDiacriticFolding() throws {
  let db = try DatabaseQueue()
  try db.write { db in
    try db.create(virtualTable: "docs", using: FTS5()) { t in
      t.tokenizer = .unicode61(diacritics: .remove)
      t.column("body")
    }
    try db.execute(sql: "INSERT INTO docs(body) VALUES (?)", arguments: ["Canción de prueba"])
  }
  let count = try db.read { db in
    let pattern = FTS5Pattern(matchingAllPrefixesIn: "cancion")
    return try Int.fetchOne(
      db, sql: "SELECT COUNT(*) FROM docs WHERE docs MATCH ?", arguments: [pattern]
    ) ?? 0
  }
  #expect(count == 1)
}
