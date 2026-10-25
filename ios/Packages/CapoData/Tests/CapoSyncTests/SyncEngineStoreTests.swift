import CapoCore
import CapoStore
import Foundation
import Testing
import os

@testable import CapoSync

/// End-to-end: SyncEngine against the real GRDB-backed CapoStore (in-memory) and stub remote.
private struct Env {
  let db: CapoDatabase
  let repos: LocalRepositories
  let remote = StubRemote()
  let writer = StubWriter()
  let engine: SyncEngine

  init() throws {
    db = try CapoDatabase.inMemory(userID: me)
    repos = LocalRepositories(database: db, userID: me, teamsRemote: nil, onRemoteMutation: {})
    engine = SyncEngine(
      userID: me, store: repos.syncStore, remote: remote, writer: writer, realtime: nil,
      reachability: StubReachability())
  }

  func sync() async { await engine.syncNow(reason: .manual) }
}

@Suite struct SyncEngineStoreTests {
  @Test func firstPullPopulatesLocalDatabase() async throws {
    let env = try Env()
    let song = makeSong(title: "Remote")
    env.remote.mutate {
      $0.memberships = [makeMembership()]
      $0.teams = [makeTeam()]
      $0.songs = [song, makeSong(title: "Team", team: teamA)]
      $0.playlists = [makePlaylist()]
    }
    await env.sync()
    #expect(try await env.repos.songs.fetchSong(id: song.id)?.title == "Remote")
    let versions = try await env.repos.syncStore.localVersions(of: .songs)
    #expect(versions.count == 2)
    #expect(try await env.repos.syncStore.localVersions(of: .playlists).count == 1)
    let meta = try await env.repos.syncStore.syncMetadata()
    #expect(meta.lastPullAt != nil)
  }

  @Test func remoteDeleteAndTeamRemovalPropagate() async throws {
    let env = try Env()
    let mine = makeSong(), gone = makeSong(), team = makeSong(team: teamA)
    env.remote.mutate {
      $0.memberships = [makeMembership()]
      $0.teams = [makeTeam()]
      $0.songs = [mine, gone, team]
    }
    await env.sync()
    env.remote.mutate {
      $0.songs = [mine, team]
    }
    await env.sync()
    #expect(try await env.repos.songs.fetchSong(id: gone.id) == nil)
    env.remote.mutate { $0.memberships = []; $0.songs = [mine] }
    await env.sync()
    #expect(try await env.repos.songs.fetchSong(id: team.id) == nil)
    #expect(try await env.repos.songs.fetchSong(id: mine.id) != nil)
  }

  @Test func pendingLocalCreateSurvivesPullThenPushes() async throws {
    let env = try Env()
    env.writer.enqueue { _ in throw StubRemote.Offline() }
    let created = try await env.repos.songs.create(
      SongDraft(title: "Draft", lyrics: "x"), in: .personal(userID: me))
    await env.sync()  // push fails (transient), pull must not delete the local row
    #expect(try await env.repos.songs.fetchSong(id: created.id) != nil)
    #expect(try await env.repos.syncStore.statusCounts().pending == 1)

    // Later the push succeeds and the server row replaces the local one.
    var server = created
    server.updatedAt = ts(11)
    let applied = server
    env.writer.enqueue { _ in .applied(serverSong: applied) }
    env.remote.mutate { $0.songs = [applied] }
    // wait out the 1 s backoff
    try await Task.sleep(for: .milliseconds(1100))
    await env.sync()
    #expect(try await env.repos.syncStore.statusCounts().pending == 0)
    #expect(try await env.repos.songs.fetchSong(id: created.id)?.updatedAt == ts(11))
  }

  @Test func conflictThenKeepMineResendsWithServerBase() async throws {
    let env = try Env()
    let original = makeSong(title: "Orig")
    env.remote.mutate { $0.songs = [original] }
    await env.sync()

    try await env.repos.songs.update(id: original.id, SongPatch(title: "Mine"))
    var theirs = original
    theirs.title = "Theirs"
    theirs.updatedAt = ts(8)
    let server = theirs
    env.writer.enqueue { _ in .conflict(server: server) }
    env.remote.mutate { $0.songs = [server] }
    await env.sync()

    let counts = try await env.repos.syncStore.statusCounts()
    #expect(counts.conflicts == 1)
    var conflicts: [SongConflict] = []
    for await list in env.repos.conflicts.conflicts() { conflicts = list; break }
    #expect(conflicts.count == 1)

    try await env.repos.conflicts.resolve(conflicts[0].id, with: .keepMine)
    await env.sync()
    guard case .updateSong(let id, let patch, let base)? = env.writer.applied.last else {
      Issue.record("expected an updateSong to be re-sent, got \(env.writer.applied)")
      return
    }
    #expect(id == original.id)
    #expect(patch.title == "Mine")
    #expect(base == ts(8))
    #expect(try await env.repos.syncStore.statusCounts().conflicts == 0)
  }

  @Test func conflictThenKeepTheirsAdoptsServerRow() async throws {
    let env = try Env()
    let original = makeSong(title: "Orig")
    env.remote.mutate { $0.songs = [original] }
    await env.sync()
    try await env.repos.songs.update(id: original.id, SongPatch(title: "Mine"))
    var theirs = original
    theirs.title = "Theirs"
    theirs.updatedAt = ts(8)
    let server = theirs
    env.writer.enqueue { _ in .conflict(server: server) }
    env.remote.mutate { $0.songs = [server] }
    await env.sync()

    var conflicts: [SongConflict] = []
    for await list in env.repos.conflicts.conflicts() { conflicts = list; break }
    try await env.repos.conflicts.resolve(conflicts[0].id, with: .keepTheirs)
    let writes = env.writer.applied.count
    await env.sync()
    #expect(env.writer.applied.count == writes)
    #expect(try await env.repos.songs.fetchSong(id: original.id)?.title == "Theirs")
    #expect(try await env.repos.syncStore.statusCounts().pending == 0)
  }

  @Test func conflictThenKeepBothCreatesCopy() async throws {
    let env = try Env()
    let original = makeSong(title: "Orig")
    env.remote.mutate { $0.songs = [original] }
    await env.sync()
    try await env.repos.songs.update(id: original.id, SongPatch(title: "Mine"))
    var theirs = original
    theirs.title = "Theirs"
    theirs.updatedAt = ts(8)
    let server = theirs
    env.writer.enqueue { _ in .conflict(server: server) }
    env.remote.mutate { $0.songs = [server] }
    await env.sync()

    var conflicts: [SongConflict] = []
    for await list in env.repos.conflicts.conflicts() { conflicts = list; break }
    try await env.repos.conflicts.resolve(conflicts[0].id, with: .keepBothAsCopy)
    await env.sync()

    let creates = env.writer.applied.compactMap { op -> Song? in
      if case .createSong(let song) = op { return song }
      return nil
    }
    #expect(creates.count == 1)
    #expect(creates.first?.id != original.id)
    #expect(try await env.repos.songs.fetchSong(id: original.id)?.title == "Theirs")
  }

  @Test func rejectedOperationIsCountedAsFailed() async throws {
    let env = try Env()
    env.writer.enqueue { _ in .rejected(.permissionDenied) }
    _ = try await env.repos.songs.create(SongDraft(title: "Nope"), in: .personal(userID: me))
    await env.sync()
    let counts = try await env.repos.syncStore.statusCounts()
    #expect(counts.failed == 1)
    #expect(counts.pending == 0)
  }
}
