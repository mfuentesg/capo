import CapoCore
import CapoStore
import Foundation
import os

/// Minimal in-memory `LocalSyncStore` used until (and alongside) the real CapoStore.
final class MemoryStore: LocalSyncStore {
  struct Op: Sendable {
    var record: OutboxRecord
    var state: State
    var nextAttemptAt: Date = .distantPast
  }
  enum State: Sendable { case pending, inflight, conflict, failed }

  struct Data: Sendable {
    var songs: [SongID: Song] = [:]
    var playlists: [PlaylistID: Playlist] = [:]
    var teams: [Team] = []
    var memberships: [TeamMembership] = []
    var tags: [SongTag] = []
    var profile: Profile?
    var ops: [Op] = []
    var nextID: Int64 = 1
    var meta = SyncMetadata()
    var applyCount = 0
    var lastBatch: PullBatch?
    var outcomes: [Int64: OutboxOutcome] = [:]
  }

  let data = OSAllocatedUnfairLock(initialState: Data())
  private let counts = ValueSubject(0)

  var snapshot: Data { data.withLock { $0 } }

  func seed(song: Song) { data.withLock { $0.songs[song.id] = song } }

  func enqueue(_ op: OutboxOperation, attempts: Int = 0) {
    let count = data.withLock { d -> Int in
      let id = d.nextID
      d.nextID += 1
      d.ops.append(
        Op(
          record: OutboxRecord(
            id: id, opID: UUID(), operation: op, attempts: attempts, createdAt: Date(),
            lastError: nil), state: .pending))
      return d.ops.filter { $0.state == .pending }.count
    }
    counts.send(count)
  }

  func localVersions(of table: SyncedTable) async throws -> [UUID: ServerTimestamp] {
    data.withLock { d in
      switch table {
      case .songs: return d.songs.mapValues(\.updatedAt)
      case .playlists: return d.playlists.mapValues(\.updatedAt)
      }
    }
  }
  func localPlaylistIDs() async throws -> [PlaylistID] { data.withLock { Array($0.playlists.keys) } }

  func apply(_ batch: PullBatch) async throws {
    data.withLock { d in
      d.applyCount += 1
      d.lastBatch = batch
      let skip = batch.skipEntityKeys
      for song in batch.upsertSongs where !skip.contains("song:\(song.id.uuidString.lowercased())") {
        d.songs[song.id] = song
      }
      for id in batch.deleteSongIDs where !skip.contains("song:\(id.uuidString.lowercased())") {
        d.songs[id] = nil
      }
      for p in batch.upsertPlaylists where !skip.contains("playlist:\(p.id.uuidString.lowercased())") {
        d.playlists[p.id] = p
      }
      for id in batch.deletePlaylistIDs
      where !skip.contains("playlist:\(id.uuidString.lowercased())") {
        d.playlists[id] = nil
      }
      if let teams = batch.teams { d.teams = teams }
      if let memberships = batch.memberships { d.memberships = memberships }
      if let tags = batch.tags { d.tags = tags }
      if let profile = batch.profile { d.profile = profile }
    }
  }

  func nextPendingOperations(limit: Int, now: Date) async throws -> [OutboxRecord] {
    data.withLock { d in
      var blocked = Set<String>()
      var result: [OutboxRecord] = []
      for op in d.ops {
        let key = op.record.operation.entityKey
        if blocked.contains(key) { continue }
        if op.state == .conflict || op.state == .inflight { blocked.insert(key); continue }
        guard op.state == .pending else { continue }
        if op.nextAttemptAt > now { blocked.insert(key); continue }
        result.append(op.record)
        if result.count == limit { break }
      }
      return result
    }
  }

  func markInflight(_ id: Int64) async throws {
    data.withLock { d in
      if let i = d.ops.firstIndex(where: { $0.record.id == id }) { d.ops[i].state = .inflight }
    }
  }

  func complete(_ id: Int64, outcome: OutboxOutcome) async throws {
    let pending = data.withLock { d -> Int in
      d.outcomes[id] = outcome
      guard let i = d.ops.firstIndex(where: { $0.record.id == id }) else { return 0 }
      switch outcome {
      case .applied(let server):
        if let server { d.songs[server.id] = server }
        d.ops.remove(at: i)
      case .retryLater(let error, let next):
        d.ops[i].state = .pending
        d.ops[i].record.attempts += 1
        d.ops[i].record.lastError = error
        d.ops[i].nextAttemptAt = next
      case .rejected(let error):
        d.ops[i].state = .failed
        d.ops[i].record.lastError = String(describing: error)
      case .conflict:
        d.ops[i].state = .conflict
      }
      return d.ops.filter { $0.state == .pending }.count
    }
    counts.send(pending)
  }

  func pendingEntityKeys() async throws -> Set<String> {
    data.withLock { d in
      Set(d.ops.filter { $0.state != .failed }.map { $0.record.operation.entityKey })
    }
  }

  func outboxChanges() -> AsyncStream<Int> { counts.stream() }
  func syncMetadata() async throws -> SyncMetadata { data.withLock { $0.meta } }
  func saveSyncMetadata(_ metadata: SyncMetadata) async throws { data.withLock { $0.meta = metadata } }

  func statusCounts() async throws -> (pending: Int, conflicts: Int, failed: Int) {
    data.withLock { d in
      (
        d.ops.filter { $0.state == .pending || $0.state == .inflight }.count,
        d.ops.filter { $0.state == .conflict }.count,
        d.ops.filter { $0.state == .failed }.count
      )
    }
  }
}
