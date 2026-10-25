import CapoCore
import CapoStore
import Foundation
import Testing
import os

@testable import CapoSync

private final class Clock: Sendable {
  let now = OSAllocatedUnfairLock(initialState: Date(timeIntervalSince1970: 1_000_000))
  func advance(_ seconds: TimeInterval) { now.withLock { $0.addTimeInterval(seconds) } }
  var fn: @Sendable () -> Date { { [self] in now.withLock { $0 } } }
}

private struct Harness {
  let store = MemoryStore()
  let remote = StubRemote()
  let writer = StubWriter()
  let reachability: StubReachability
  let realtime = StubRealtime()
  let clock = Clock()
  let engine: SyncEngine

  init(online: Bool = true) {
    reachability = StubReachability(online: online)
    engine = SyncEngine(
      userID: me, store: store, remote: remote, writer: writer, realtime: realtime,
      reachability: reachability, clock: clock.fn, realtimeDebounce: .milliseconds(50),
      outboxDebounce: .milliseconds(50))
  }
}

@Suite struct SyncEngineTests {
  @Test func firstFullPull() async throws {
    let h = Harness()
    let song = makeSong(title: "A")
    let teamSong = makeSong(title: "T", team: teamA)
    let playlist = makePlaylist()
    h.remote.mutate {
      $0.memberships = [makeMembership()]
      $0.teams = [makeTeam()]
      $0.songs = [song, teamSong]
      $0.playlists = [playlist]
    }
    await h.engine.syncNow(reason: .appLaunch)

    let snap = h.store.snapshot
    #expect(Set(snap.songs.keys) == [song.id, teamSong.id])
    #expect(snap.playlists.keys.contains(playlist.id))
    #expect(snap.teams.map(\.id) == [teamA])
    #expect(snap.profile?.id == me)
    #expect(snap.applyCount == 1)
    #expect(snap.meta.lastPullAt != nil)
    #expect(snap.meta.lastError == nil)
  }

  @Test func incrementalPullFetchesOnlyChangedIDs() async throws {
    let h = Harness()
    let a = makeSong(title: "A"), b = makeSong(title: "B")
    h.remote.mutate { $0.songs = [a, b] }
    await h.engine.syncNow(reason: .manual)
    h.remote.mutate { $0.fetchedSongIDs = [] }

    var edited = b
    edited.title = "B2"
    edited.updatedAt = ts(5)
    let changed = edited
    h.remote.mutate { $0.songs = [a, changed] }
    await h.engine.syncNow(reason: .manual)

    #expect(h.remote.snapshot.fetchedSongIDs == [[b.id]])
    #expect(h.store.snapshot.songs[b.id]?.title == "B2")
    #expect(h.store.snapshot.songs[a.id]?.title == "A")

    h.remote.mutate { $0.fetchedSongIDs = [] }
    await h.engine.syncNow(reason: .manual)
    #expect(h.remote.snapshot.fetchedSongIDs.isEmpty)
  }

  @Test func changedIDsAreFetchedInChunksOf100() async throws {
    let h = Harness()
    let songs = (0..<250).map { _ in makeSong() }
    h.remote.mutate { $0.songs = songs }
    await h.engine.syncNow(reason: .manual)
    #expect(h.remote.snapshot.fetchedSongIDs.map(\.count) == [100, 100, 50])
    #expect(h.store.snapshot.songs.count == 250)
  }

  @Test func remoteDeleteRemovesLocalRow() async throws {
    let h = Harness()
    let a = makeSong(), b = makeSong()
    h.remote.mutate { $0.songs = [a, b] }
    await h.engine.syncNow(reason: .manual)
    h.remote.mutate { $0.songs = [a] }
    await h.engine.syncNow(reason: .manual)
    #expect(Set(h.store.snapshot.songs.keys) == [a.id])
    #expect(h.store.snapshot.lastBatch?.deleteSongIDs == [b.id])
  }

  @Test func pendingLocalCreateSurvivesPull() async throws {
    let h = Harness()
    let local = makeSong(title: "Local only")
    h.store.seed(song: local)
    h.store.enqueue(.createSong(local))
    // Writer is down so the create stays pending through this sync.
    h.writer.enqueue { _ in throw StubRemote.Offline() }
    await h.engine.syncNow(reason: .manual)

    #expect(h.store.snapshot.songs[local.id] != nil)
    #expect(h.store.snapshot.lastBatch?.skipEntityKeys == [OutboxOperation.createSong(local).entityKey])
  }

  @Test func pushRunsBeforePullAndAppliedServerRowIsStored() async throws {
    let h = Harness()
    let song = makeSong(title: "New")
    var updated = song
    updated.updatedAt = ts(9)
    let server = updated
    h.store.seed(song: song)
    h.store.enqueue(.createSong(song))
    h.writer.enqueue { _ in .applied(serverSong: server) }
    h.remote.mutate { $0.songs = [server] }
    await h.engine.syncNow(reason: .outboxEnqueued)

    #expect(h.writer.applied == [.createSong(song)])
    #expect(h.store.snapshot.ops.isEmpty)
    #expect(h.store.snapshot.songs[song.id]?.updatedAt == ts(9))
    #expect(h.store.snapshot.meta.lastPushAt != nil)
  }

  @Test func conflictBlocksEntityAndSurfacesInStatus() async throws {
    let h = Harness()
    let song = makeSong()
    h.store.seed(song: song)
    h.store.enqueue(.updateSong(id: song.id, patch: SongPatch(title: "Mine"), base: song.updatedAt))
    h.store.enqueue(.updateSong(id: song.id, patch: SongPatch(artist: "Me"), base: song.updatedAt))
    var theirs = song
    theirs.title = "Theirs"
    theirs.updatedAt = ts(7)
    let server = theirs
    h.writer.enqueue { _ in .conflict(server: server) }
    await h.engine.syncNow(reason: .manual)

    // Second op of the same entity must not be sent.
    #expect(h.writer.applied.count == 1)
    let ops = h.store.snapshot.ops
    #expect(ops.count == 2)
    #expect(ops[0].state == .conflict)
    let counts = try await h.store.statusCounts()
    #expect(counts.conflicts == 1)

    // And it stays blocked on the next run.
    await h.engine.syncNow(reason: .manual)
    #expect(h.writer.applied.count == 1)
  }

  @Test func conflictDoesNotBlockOtherEntities() async throws {
    let h = Harness()
    let a = makeSong(), b = makeSong()
    h.store.enqueue(.updateSong(id: a.id, patch: SongPatch(title: "x"), base: a.updatedAt))
    h.store.enqueue(.updateSong(id: b.id, patch: SongPatch(title: "y"), base: b.updatedAt))
    h.writer.enqueue { _ in .conflict(server: nil) }
    await h.engine.syncNow(reason: .manual)
    #expect(h.writer.applied.count == 2)
    #expect(h.store.snapshot.ops.count == 1)
  }

  @Test func transientFailureRetriesWithExponentialBackoff() async throws {
    let h = Harness()
    let id = UUID()
    h.store.enqueue(.deleteSong(id: id))
    h.writer.enqueue { _ in throw StubRemote.Offline() }
    await h.engine.syncNow(reason: .manual)

    var op = h.store.snapshot.ops[0]
    #expect(op.record.attempts == 1)
    #expect(op.state == .pending)
    #expect(op.nextAttemptAt == h.clock.now.withLock { $0 }.addingTimeInterval(1))

    // Not due yet: no second attempt.
    await h.engine.syncNow(reason: .manual)
    #expect(h.writer.applied.count == 1)

    h.clock.advance(2)
    h.writer.enqueue { _ in throw StubRemote.Offline() }
    await h.engine.syncNow(reason: .manual)
    #expect(h.writer.applied.count == 2)
    op = h.store.snapshot.ops[0]
    #expect(op.record.attempts == 2)
    #expect(op.nextAttemptAt == h.clock.now.withLock { $0 }.addingTimeInterval(2))

    h.clock.advance(10)
    await h.engine.syncNow(reason: .manual)
    #expect(h.store.snapshot.ops.isEmpty)
  }

  @Test func errorsThatKeepFailingAreSurfacedInsteadOfRetriedForever() async throws {
    let h = Harness()
    h.store.enqueue(.deleteSong(id: UUID()), attempts: SyncEngine.maxAttempts - 1)
    h.writer.enqueue { _ in throw StubRemote.Offline() }
    await h.engine.syncNow(reason: .manual)
    #expect(h.store.snapshot.ops[0].state == .failed)
  }

  @Test func backoffIsCappedAtFiveMinutes() {
    #expect(SyncEngine.backoff(0) == 1)
    #expect(SyncEngine.backoff(3) == 8)
    #expect(SyncEngine.backoff(8) == 256)
    #expect(SyncEngine.backoff(9) == 300)
    #expect(SyncEngine.backoff(500) == 300)
  }

  @Test func transientFailureKeepsFIFOForSameEntity() async throws {
    let h = Harness()
    let id = UUID()
    h.store.enqueue(.updateSong(id: id, patch: SongPatch(title: "1"), base: ts(1)))
    h.store.enqueue(.updateSong(id: id, patch: SongPatch(title: "2"), base: ts(1)))
    h.writer.enqueue { _ in throw StubRemote.Offline() }
    await h.engine.syncNow(reason: .manual)
    #expect(h.writer.applied.count == 1)
  }

  @Test func rejectedOpIsMarkedFailedAndSurfaced() async throws {
    let h = Harness()
    h.store.enqueue(.deleteSong(id: UUID()))
    h.writer.enqueue { _ in .rejected(.permissionDenied) }
    var statuses: [SyncStatus] = []
    let stream = h.engine.status()
    let collector = Task { for await s in stream { statuses.append(s) } }
    await h.engine.syncNow(reason: .manual)
    collector.cancel()

    #expect(h.store.snapshot.ops[0].state == .failed)
    let counts = try await h.store.statusCounts()
    #expect(counts.failed == 1)
    #expect(counts.pending == 0)
    await h.engine.syncNow(reason: .manual)
    #expect(h.writer.applied.count == 1)  // never retried
  }

  @Test func scopeChangeOnTeamRemovalDropsTeamData() async throws {
    let h = Harness()
    let mine = makeSong(title: "mine")
    let teamSong = makeSong(title: "team", team: teamA)
    h.remote.mutate {
      $0.memberships = [makeMembership()]
      $0.teams = [makeTeam()]
      $0.songs = [mine, teamSong]
    }
    await h.engine.syncNow(reason: .manual)
    #expect(h.store.snapshot.songs.count == 2)

    h.remote.mutate { $0.memberships = [] }
    await h.engine.syncNow(reason: .manual)

    let snap = h.store.snapshot
    #expect(Set(snap.songs.keys) == [mine.id])
    #expect(snap.teams.isEmpty)
    #expect(snap.memberships.isEmpty)
  }

  @Test func offlineSyncIsANoOp() async throws {
    let h = Harness(online: false)
    h.store.enqueue(.deleteSong(id: UUID()))
    await h.engine.start()
    #expect(await eventually { await h.engine.currentStatus().phase == .offline })
    let before = h.remote.snapshot.callCount
    await h.engine.syncNow(reason: .manual)

    #expect(h.remote.snapshot.callCount == before)
    #expect(h.writer.applied.isEmpty)
    #expect(h.store.snapshot.applyCount == 0)
    let status = await h.engine.currentStatus()
    #expect(status.phase == .offline)
    #expect(status.pendingOperations == 1)
    await h.engine.stop()
  }

  @Test func regainingReachabilityTriggersSync() async throws {
    let h = Harness(online: false)
    h.remote.mutate { $0.songs = [makeSong()] }
    await h.engine.start()
    #expect(await eventually { await h.engine.currentStatus().phase == .offline })
    h.reachability.set(true)
    #expect(await eventually { h.store.snapshot.songs.count == 1 })
    await h.engine.stop()
  }

  @Test func realtimeEventsAreDebouncedIntoOneSync() async throws {
    let h = Harness()
    await h.engine.start()
    #expect(await eventually { h.realtime.subscriptions == 1 })
    for _ in 0..<5 { h.realtime.emit() }
    #expect(await eventually { h.store.snapshot.applyCount >= 1 })
    try await Task.sleep(for: .milliseconds(200))
    #expect(h.store.snapshot.applyCount == 1)
    await h.engine.stop()
  }

  @Test func secondaryTablesAreRefetchedOnlyWhenNeeded() async throws {
    let h = Harness()
    await h.engine.syncNow(reason: .appLaunch)
    var batch = try #require(h.store.snapshot.lastBatch)
    #expect(batch.tags != nil && batch.tagAssignments != nil && batch.userSongSettings != nil)
    #expect(batch.profile != nil && batch.playlistEntries != nil)

    await h.engine.syncNow(reason: .realtime)
    batch = try #require(h.store.snapshot.lastBatch)
    #expect(batch.tags == nil && batch.tagAssignments == nil && batch.userSongSettings == nil)
    #expect(batch.profile == nil && batch.playlistEntries == nil)

    await h.engine.start()
    #expect(await eventually { h.realtime.subscriptions == 1 })
    h.realtime.emit("song_tag_assignments")
    #expect(await eventually { h.store.snapshot.lastBatch?.tagAssignments != nil })
    batch = try #require(h.store.snapshot.lastBatch)
    #expect(batch.tags == nil && batch.userSongSettings == nil)

    await h.engine.syncNow(reason: .manual)
    #expect(h.store.snapshot.lastBatch?.tags != nil)
    await h.engine.stop()
  }

  @Test func droppedRealtimeChannelResubscribesAndRunsAFullSync() async throws {
    let h = Harness()
    await h.engine.start()
    #expect(await eventually { h.realtime.subscriptions == 1 })
    h.realtime.drop()
    #expect(await eventually(timeout: .seconds(5)) { h.realtime.subscriptions == 1 })
    #expect(await eventually(timeout: .seconds(5)) { h.store.snapshot.applyCount >= 1 })
    #expect(h.store.snapshot.lastBatch?.tags != nil)
    await h.engine.stop()
  }

  @Test func outboxEnqueueTriggersPush() async throws {
    let h = Harness()
    await h.engine.start()
    try await Task.sleep(for: .milliseconds(50))
    h.store.enqueue(.deleteSong(id: UUID()))
    #expect(await eventually { h.writer.applied.count == 1 })
    await h.engine.stop()
  }

  @Test func callsDuringARunCoalesceIntoOneFollowUp() async throws {
    let h = Harness()
    h.remote.mutate { $0.songs = [makeSong()] }
    h.remote.armGate()
    let first = Task { await h.engine.syncNow(reason: .manual) }
    #expect(await eventually { h.remote.gateEntered })
    let extra = (0..<5).map { _ in Task { await h.engine.syncNow(reason: .manual) } }
    try await Task.sleep(for: .milliseconds(50))
    h.remote.release()
    await first.value
    for task in extra { await task.value }
    // One in-flight run plus exactly one follow-up.
    #expect(h.store.snapshot.applyCount == 2)
  }

  @Test func pullFailureSurfacesErrorStatusAndMetadata() async throws {
    let h = Harness()
    h.remote.mutate { $0.failing = true }
    await h.engine.syncNow(reason: .manual)
    let status = await h.engine.currentStatus()
    guard case .error = status.phase else {
      Issue.record("expected error phase, got \(status.phase)")
      return
    }
    #expect(h.store.snapshot.meta.lastError != nil)
    #expect(h.store.snapshot.applyCount == 0)
  }
}

extension SyncEngineTests {
  /// Cold start offline: `syncNow` can run before the first reachability event, so the engine still
  /// believes it is online and the transport error must be reported as offline, not as a failure.
  @Test func transportFailureBeforeFirstReachabilityEventIsOffline() async throws {
    let h = Harness()
    h.remote.mutate {
      $0.failing = true
      $0.failureError = URLError(.notConnectedToInternet)
    }
    await h.engine.syncNow(reason: .appLaunch)
    let status = await h.engine.currentStatus()
    #expect(status.phase == .offline)
    #expect(h.store.snapshot.meta.lastError == nil)
  }

  @Test func nonTransportFailureStillReportsError() async throws {
    let h = Harness()
    h.remote.mutate {
      $0.failing = true
      $0.failureError = URLError(.badServerResponse)
    }
    await h.engine.syncNow(reason: .manual)
    guard case .error = await h.engine.currentStatus().phase else {
      Issue.record("expected error phase")
      return
    }
  }
}

extension SyncEngine {
  func currentStatus() async -> SyncStatus {
    for await s in status() { return s }
    return SyncStatus()
  }
}
