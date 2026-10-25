import CapoCore
import CapoStore
import Foundation
import os

// Local test doubles for the sync engine. Kept independent of CapoFakes so tests can record calls
// and inject failures.

let me = UUID(uuidString: "00000000-0000-0000-0000-00000000000a")!
let teamA = UUID(uuidString: "00000000-0000-0000-0000-0000000000a1")!

func ts(_ n: Int) -> ServerTimestamp {
  ServerTimestamp(String(format: "2026-01-01T00:00:%02d.000000+00:00", n))
}

func makeSong(
  _ id: UUID = UUID(), title: String = "Song", team: TeamID? = nil, updated: Int = 1
) -> Song {
  Song(
    id: id, title: title, artist: nil, key: nil, bpm: nil, lyrics: "la", notes: nil, transpose: 0,
    capo: 0, status: .published, userID: team == nil ? me : nil, teamID: team, createdBy: me,
    createdAt: ts(0), updatedAt: ts(updated))
}

func makePlaylist(_ id: UUID = UUID(), updated: Int = 1) -> Playlist {
  Playlist(
    id: id, name: "Set", description: nil, date: nil, isPublic: false, allowGuestEditing: false,
    shareCode: nil, shareExpiresAt: nil, archivedAt: nil, userID: me, teamID: nil, createdBy: me,
    createdAt: ts(0), updatedAt: ts(updated))
}

func makeTeam(_ id: UUID = teamA) -> Team {
  Team(
    id: id, name: "Band", icon: nil, avatarURL: nil, isPublic: false, createdBy: me,
    createdAt: ts(0), updatedAt: ts(0))
}

func makeMembership(team: TeamID = teamA) -> TeamMembership {
  TeamMembership(id: UUID(), teamID: team, userID: me, role: .member, joinedAt: ts(0))
}

func makeProfile() -> Profile {
  Profile(
    id: me, email: "me@example.com", fullName: "Me", avatarURL: nil,
    preferences: .default, updatedAt: ts(0))
}

/// Mutable remote dataset with call recording.
final class StubRemote: RemoteSyncSource {
  struct State: Sendable {
    var memberships: [TeamMembership] = []
    var teams: [Team] = []
    var songs: [Song] = []
    var playlists: [Playlist] = []
    var entries: [PlaylistEntry] = []
    var tags: [SongTag] = []
    var assignments: [TagAssignment] = []
    var settings: [UserSongSettings] = []
    var profile = makeProfile()
    var fetchedSongIDs: [[SongID]] = []
    var fetchedPlaylistIDs: [[PlaylistID]] = []
    var callCount = 0
    var failing = false
    var failureError: (any Error & Sendable)?
  }

  struct Offline: Error {}

  let state = OSAllocatedUnfairLock(initialState: State())

  func mutate(_ body: @Sendable (inout State) -> Void) { state.withLock(body) }
  var snapshot: State { state.withLock { $0 } }

  private func read<T: Sendable>(_ body: @Sendable (inout State) -> T) throws -> T {
    try state.withLock { s in
      s.callCount += 1
      if s.failing { throw s.failureError ?? Offline() }
      return body(&s)
    }
  }

  /// When set, the next `memberships` call suspends until `release()`.
  private let gate = OSAllocatedUnfairLock<(armed: Bool, entered: Bool, cont: CheckedContinuation<Void, Never>?)>(
    initialState: (false, false, nil))
  func armGate() { gate.withLock { $0.armed = true } }
  var gateEntered: Bool { gate.withLock { $0.entered } }
  func release() {
    let cont = gate.withLock { g -> CheckedContinuation<Void, Never>? in
      g.armed = false
      defer { g.cont = nil }
      return g.cont
    }
    cont?.resume()
  }

  func memberships(userID: UserID) async throws -> [TeamMembership] {
    if gate.withLock({ $0.armed }) {
      await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        let resumeNow = gate.withLock { g -> Bool in
          if !g.armed { return true }
          g.entered = true
          g.cont = c
          return false
        }
        if resumeNow { c.resume() }
      }
    }
    return try read { $0.memberships }
  }
  func teams(ids: [TeamID]) async throws -> [Team] {
    try read { s in s.teams.filter { ids.contains($0.id) } }
  }
  func songVersions(scope: SyncScope) async throws -> [RowVersion] {
    try read { s in
      s.songs.filter { song in
        song.userID == scope.userID || song.teamID.map { scope.teamIDs.contains($0) } == true
      }.map { RowVersion(id: $0.id, updatedAt: $0.updatedAt) }
    }
  }
  func songs(ids: [SongID]) async throws -> [Song] {
    try read { s in
      s.fetchedSongIDs.append(ids)
      return s.songs.filter { ids.contains($0.id) }
    }
  }
  func playlistVersions(scope: SyncScope) async throws -> [RowVersion] {
    try read { s in s.playlists.map { RowVersion(id: $0.id, updatedAt: $0.updatedAt) } }
  }
  func playlists(ids: [PlaylistID]) async throws -> [Playlist] {
    try read { s in
      s.fetchedPlaylistIDs.append(ids)
      return s.playlists.filter { ids.contains($0.id) }
    }
  }
  func playlistEntries(playlistIDs: [PlaylistID]) async throws -> [PlaylistEntry] {
    try read { s in s.entries.filter { playlistIDs.contains($0.playlistID) } }
  }
  func tags(scope: SyncScope) async throws -> [SongTag] { try read { $0.tags } }
  func tagAssignments() async throws -> [TagAssignment] { try read { $0.assignments } }
  func userSongSettings(userID: UserID) async throws -> [UserSongSettings] {
    try read { $0.settings }
  }
  func profile(userID: UserID) async throws -> Profile { try read { $0.profile } }
}

/// Scripted writer: per-op closure decides the result; records every applied op.
final class StubWriter: RemoteWriter {
  struct State: Sendable {
    var applied: [OutboxOperation] = []
    var script: [@Sendable (OutboxOperation) throws -> RemoteApplyResult] = []
  }
  let state = OSAllocatedUnfairLock(initialState: State())

  var applied: [OutboxOperation] { state.withLock { $0.applied } }

  /// Results consumed in order; when exhausted, ops are `.applied(nil)`.
  func enqueue(_ handler: @escaping @Sendable (OutboxOperation) throws -> RemoteApplyResult) {
    state.withLock { $0.script.append(handler) }
  }

  func apply(_ op: OutboxOperation) async throws -> RemoteApplyResult {
    let handler: (@Sendable (OutboxOperation) throws -> RemoteApplyResult)? = state.withLock { s in
      s.applied.append(op)
      return s.script.isEmpty ? nil : s.script.removeFirst()
    }
    return try handler?(op) ?? .applied(serverSong: nil)
  }
}

final class StubReachability: ReachabilityMonitor {
  let subject: ValueSubject<Bool>
  init(online: Bool = true) { subject = ValueSubject(online) }
  func set(_ online: Bool) { subject.send(online) }
  func isOnline() -> AsyncStream<Bool> { subject.stream() }
}

final class StubRealtime: RealtimeNotifier {
  let continuations = OSAllocatedUnfairLock(
    initialState: [AsyncStream<RealtimeChange>.Continuation]())
  func changes(scope: SyncScope) -> AsyncStream<RealtimeChange> {
    let (stream, continuation) = AsyncStream<RealtimeChange>.makeStream()
    continuations.withLock { $0.append(continuation) }
    return stream
  }
  var subscriptions: Int { continuations.withLock { $0.count } }
  /// Ends every open stream, like a dropped channel.
  func drop() {
    let all = continuations.withLock { c -> [AsyncStream<RealtimeChange>.Continuation] in
      defer { c.removeAll() }
      return c
    }
    for c in all { c.finish() }
  }
  func emit(_ table: String = "songs") {
    for c in continuations.withLock({ $0 }) { c.yield(RealtimeChange(table: table)) }
  }
}

/// Polls until `condition` holds or the timeout elapses.
func eventually(timeout: Duration = .seconds(3), _ condition: @Sendable () async -> Bool) async
  -> Bool
{
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if await condition() { return true }
    try? await Task.sleep(for: .milliseconds(10))
  }
  return await condition()
}
