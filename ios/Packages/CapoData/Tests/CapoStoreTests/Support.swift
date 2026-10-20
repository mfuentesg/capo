import CapoCore
import Foundation
@testable import CapoStore

let me = UUID(uuidString: "00000000-0000-4000-8000-0000000000A1")!
let otherUser = UUID(uuidString: "00000000-0000-4000-8000-0000000000A2")!
let teamA = UUID(uuidString: "00000000-0000-4000-8000-0000000000B1")!

struct Env {
  let db: CapoDatabase
  let repos: LocalRepositories

  init(teamsRemote: (any TeamsRemote)? = nil, onRemote: @escaping @Sendable () async -> Void = {}) throws {
    db = try CapoDatabase.inMemory(userID: me)
    repos = LocalRepositories(
      database: db, userID: me, teamsRemote: teamsRemote, onRemoteMutation: onRemote)
  }
}

func makeSong(
  _ title: String, id: UUID = UUID(), user: UUID? = me, team: UUID? = nil, lyrics: String? = "la",
  artist: String? = nil, bpm: Int? = nil, updatedAt: String = "2026-01-01T00:00:00.000001+00:00"
) -> Song {
  Song(
    id: id, title: title, artist: artist, key: nil, bpm: bpm, lyrics: lyrics, notes: nil,
    transpose: 0, capo: 0, status: .published, userID: user, teamID: team, createdBy: me,
    createdAt: ServerTimestamp("2026-01-01T00:00:00.000001+00:00"),
    updatedAt: ServerTimestamp(updatedAt))
}

func first<T: Sendable>(_ stream: AsyncStream<T>) async -> T? {
  for await value in stream { return value }
  return nil
}

/// Waits (up to ~3s) for a stream value satisfying the predicate.
func next<T: Sendable>(_ stream: AsyncStream<T>, where predicate: @escaping @Sendable (T) -> Bool) async -> T? {
  await withTaskGroup(of: T?.self) { group in
    group.addTask {
      for await value in stream where predicate(value) { return value }
      return nil
    }
    group.addTask {
      try? await Task.sleep(for: .seconds(3))
      return nil
    }
    let result = await group.next() ?? nil
    group.cancelAll()
    return result
  }
}

func query(_ context: AppContext, _ text: String = "") -> SongQuery {
  SongQuery(context: context, searchText: text)
}

func titles(_ store: Env, _ q: SongQuery) async -> [String] {
  (await first(store.repos.songs.songs(q)) ?? []).map(\.title)
}

final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var n = 0
  func bump() { lock.lock(); n += 1; lock.unlock() }
  var value: Int { lock.lock(); defer { lock.unlock() }; return n }
}
