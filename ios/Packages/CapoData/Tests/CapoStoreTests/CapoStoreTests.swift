import CapoCore
import CapoFakes
import Foundation
import Testing
@testable import CapoStore

@Suite struct StoreTests {
  // MARK: Context & search

  @Test func contextIsolation() async throws {
    let env = try Env()
    let a = makeSong("Mine"), b = makeSong("Team", user: nil, team: teamA)
    let c = makeSong("Other", user: otherUser), d = makeSong("Both", user: me, team: teamA)
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [a, b, c, d]))
    #expect(await titles(env, query(.personal(userID: me))) == ["Mine"].sorted())
    #expect(await titles(env, query(.team(teamID: teamA))) == ["Team"])
  }

  @Test func ftsPrefixDiacriticsAndChordStripping() async throws {
    let env = try Env()
    let s = makeSong("Canción de cuna", lyrics: "[Am]Duerme {c: x} mi niño [G]hermoso")
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [s, makeSong("Other")]))
    let ctx = AppContext.personal(userID: me)
    #expect(await titles(env, query(ctx, "cancion")) == ["Canción de cuna"])
    #expect(await titles(env, query(ctx, "canc")) == ["Canción de cuna"])
    #expect(await titles(env, query(ctx, "Canción")) == ["Canción de cuna"])
    #expect(await titles(env, query(ctx, "hermoso")) == ["Canción de cuna"])
    #expect(await titles(env, query(ctx, "Am")).isEmpty)
    #expect(makeSearchLyrics("[Am]a{t: z}b") == "a b")
  }

  @Test func tagFilterIsAnyOf() async throws {
    let env = try Env()
    let ctx = AppContext.personal(userID: me)
    let s1 = makeSong("One"), s2 = makeSong("Two"), s3 = makeSong("Three")
    let t1 = try await env.repos.tags.create(name: "x", color: nil, in: ctx)
    let t2 = try await env.repos.tags.create(name: "y", color: nil, in: ctx)
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [s1, s2, s3], skipEntityKeys: []))
    try await env.repos.songs.setTags(songID: s1.id, tagIDs: [t1.id])
    try await env.repos.songs.setTags(songID: s2.id, tagIDs: [t2.id])
    var q = query(ctx)
    q.tagIDs = [t1.id, t2.id]
    q.sort = .title
    #expect(await titles(env, q) == ["One", "Two"])
    q.tagIDs = [t2.id]
    let items = await first(env.repos.songs.songs(q)) ?? []
    #expect(items.map(\.title) == ["Two"])
    #expect(items.first?.tags.map(\.id) == [t2.id])
  }

  // MARK: Outbox

  @Test func updatesCoalesceAndKeepBase() async throws {
    let env = try Env()
    let s = makeSong("A")
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [s]))
    try await env.repos.songs.update(id: s.id, SongPatch(title: "B"))
    try await env.repos.songs.update(id: s.id, SongPatch(artist: "Z"))
    let ops = try await env.repos.syncStore.nextPendingOperations(limit: 10, now: .now)
    #expect(ops.count == 1)
    guard case .updateSong(_, let patch, let base) = ops[0].operation else {
      Issue.record("expected updateSong"); return
    }
    #expect(patch.title == "B" && patch.artist == "Z")
    #expect(base == s.updatedAt)
    #expect(try await env.repos.songs.fetchSong(id: s.id)?.title == "B")
  }

  @Test func inflightUpdateIsNotCoalesced() async throws {
    let env = try Env()
    let s = makeSong("A")
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [s]))
    try await env.repos.songs.update(id: s.id, SongPatch(title: "B"))
    let first = try await env.repos.syncStore.nextPendingOperations(limit: 10, now: .now)[0]
    try await env.repos.syncStore.markInflight(first.id)
    try await env.repos.songs.update(id: s.id, SongPatch(title: "C"))
    // Head is inflight, so nothing for this entity is eligible yet.
    #expect(try await env.repos.syncStore.nextPendingOperations(limit: 10, now: .now).isEmpty)
    #expect(try await env.repos.syncStore.statusCounts().pending == 2)
  }

  @Test func settingsAndPreferencesKeepLatest() async throws {
    let env = try Env()
    let id = UUID()
    for transpose in [1, 2, 3] {
      try await env.repos.settings.saveSongSettings(
        UserSongSettings(songID: id, transpose: transpose, capo: 0, fontSize: 1, updatedAt: nil))
    }
    try await env.repos.settings.updatePreferences(PreferencesPatch(lyricsColumns: 1))
    try await env.repos.settings.updatePreferences(PreferencesPatch(theme: .dark))
    let ops = try await env.repos.syncStore.nextPendingOperations(limit: 10, now: .now)
    #expect(ops.count == 2)
    for op in ops.map(\.operation) {
      switch op {
      case .upsertSongSettings(let s, _): #expect(s.transpose == 3 && s.updatedAt != nil)
      case .updatePreferences(let p, _): #expect(p.lyricsColumns == 1 && p.theme == .dark)
      default: Issue.record("unexpected \(op)")
      }
    }
    let prefs = await first(env.repos.settings.preferences())
    #expect(prefs?.lyricsColumns == 1 && prefs?.theme == .dark)
    await #expect(throws: CapoError.self) {
      try await env.repos.settings.saveSongSettings(
        UserSongSettings(songID: id, transpose: 9, capo: 0, fontSize: nil, updatedAt: nil))
    }
  }

  @Test func deleteAfterCreateDropsBoth() async throws {
    let env = try Env()
    let song = try await env.repos.songs.create(SongDraft(title: "New"), in: .personal(userID: me))
    try await env.repos.songs.update(id: song.id, SongPatch(title: "New2"))
    #expect(try await env.repos.syncStore.pendingEntityKeys() == [OutboxOperation.key("song", song.id)])
    try await env.repos.songs.delete(id: song.id)
    #expect(try await env.repos.syncStore.pendingEntityKeys().isEmpty)
    #expect(try await env.repos.songs.fetchSong(id: song.id) == nil)
  }

  @Test func deleteOfSyncedSongEnqueuesDelete() async throws {
    let env = try Env()
    let s = makeSong("A")
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [s]))
    try await env.repos.songs.update(id: s.id, SongPatch(title: "B"))
    try await env.repos.songs.delete(id: s.id)
    let ops = try await env.repos.syncStore.nextPendingOperations(limit: 10, now: .now)
    #expect(ops.map(\.operation) == [.deleteSong(id: s.id)])
  }

  @Test func retryBackoffAndRejection() async throws {
    let env = try Env()
    let song = try await env.repos.songs.create(SongDraft(title: "N"), in: .personal(userID: me))
    let store = env.repos.syncStore
    let op = try await store.nextPendingOperations(limit: 5, now: .now)[0]
    let later = Date().addingTimeInterval(60)
    try await store.complete(op.id, outcome: .retryLater(error: "x", nextAttemptAt: later))
    #expect(try await store.nextPendingOperations(limit: 5, now: .now).isEmpty)
    let again = try await store.nextPendingOperations(limit: 5, now: later.addingTimeInterval(1))
    #expect(again.count == 1 && again[0].attempts == 1 && again[0].lastError == "x")
    try await store.complete(op.id, outcome: .rejected(.permissionDenied))
    #expect(try await store.statusCounts() == (pending: 0, conflicts: 0, failed: 1))
    #expect(try await store.pendingEntityKeys().isEmpty)
    _ = song
  }

  // MARK: Apply

  @Test func applySkipsPendingEntitiesAndReplacesFullSets() async throws {
    let env = try Env()
    let store = env.repos.syncStore
    let s1 = makeSong("S1"), s2 = makeSong("S2")
    let tag = SongTag(id: UUID(), name: "t", color: nil, userID: me, teamID: nil, createdAt: .now())
    try await store.apply(
      PullBatch(
        upsertSongs: [s1, s2], tags: [tag],
        tagAssignments: [TagAssignment(songID: s1.id, tagID: tag.id), TagAssignment(songID: s2.id, tagID: tag.id)]))
    try await env.repos.songs.update(id: s1.id, SongPatch(title: "Local"))
    let skip = try await store.pendingEntityKeys()
    var server = s1
    server.title = "Server"
    server.updatedAt = ServerTimestamp("2026-02-01T00:00:00.000001+00:00")
    try await store.apply(
      PullBatch(
        upsertSongs: [server], deleteSongIDs: [s2.id], tags: [tag], tagAssignments: [],
        skipEntityKeys: skip))
    #expect(try await env.repos.songs.fetchSong(id: s1.id)?.title == "Local")
    #expect(try await env.repos.songs.fetchSong(id: s2.id) == nil)
    // s1's assignments are skipped (pending song entity) so it keeps its tag.
    let versions = try await store.localVersions(of: .songs)
    #expect(versions.keys.contains(s1.id) && !versions.keys.contains(s2.id))
    // Idempotent re-apply without skips takes the server row.
    try await store.apply(PullBatch(upsertSongs: [server]))
    try await store.apply(PullBatch(upsertSongs: [server]))
    #expect(try await env.repos.songs.fetchSong(id: s1.id)?.title == "Server")
  }

  @Test func appliedCreateRebasesLaterUpdates() async throws {
    let env = try Env()
    let store = env.repos.syncStore
    let song = try await env.repos.songs.create(SongDraft(title: "N"), in: .personal(userID: me))
    let create = try await store.nextPendingOperations(limit: 5, now: .now)[0]
    try await store.markInflight(create.id)
    try await env.repos.songs.update(id: song.id, SongPatch(title: "N2"))
    var server = song
    server.updatedAt = ServerTimestamp("2026-05-05T05:05:05.123456+00:00")
    try await store.complete(create.id, outcome: .applied(serverSong: server))
    let ops = try await store.nextPendingOperations(limit: 5, now: .now)
    guard case .updateSong(_, _, let base) = ops.first?.operation else {
      Issue.record("expected updateSong"); return
    }
    #expect(base == server.updatedAt)
    #expect(try await env.repos.songs.fetchSong(id: song.id)?.updatedAt == server.updatedAt)
  }

  @Test func streamEmitsOnChange() async throws {
    let env = try Env()
    let stream = env.repos.songs.songs(query(.personal(userID: me)))
    _ = try await env.repos.songs.create(SongDraft(title: "Fresh"), in: .personal(userID: me))
    let items = await next(stream) { $0.map(\.title) == ["Fresh"] }
    #expect(items?.first?.hasPendingChanges == true)
  }

  // MARK: Conflicts

  private func makeConflict(_ env: Env) async throws -> (Song, Song, UUID) {
    let s = makeSong("Base")
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [s]))
    try await env.repos.songs.update(id: s.id, SongPatch(title: "Mine"))
    let op = try await env.repos.syncStore.nextPendingOperations(limit: 5, now: .now)[0]
    var server = s
    server.title = "Theirs"
    server.updatedAt = ServerTimestamp("2026-03-03T00:00:00.000001+00:00")
    try await env.repos.syncStore.complete(op.id, outcome: .conflict(server: server))
    let conflict = await first(env.repos.conflicts.conflicts())?.first
    #expect(conflict?.local.title == "Mine" && conflict?.server?.title == "Theirs")
    return (s, server, conflict?.id ?? .zero)
  }

  @Test func conflictKeepMine() async throws {
    let env = try Env()
    let (s, server, id) = try await makeConflict(env)
    #expect(try await env.repos.syncStore.statusCounts().conflicts == 1)
    try await env.repos.conflicts.resolve(id, with: .keepMine)
    let ops = try await env.repos.syncStore.nextPendingOperations(limit: 5, now: .now)
    guard case .updateSong(let sid, let patch, let base) = ops.first?.operation else {
      Issue.record("expected updateSong"); return
    }
    #expect(sid == s.id && base == server.updatedAt && patch.title == "Mine")
    #expect(await first(env.repos.conflicts.conflicts())?.isEmpty == true)
  }

  @Test func conflictKeepTheirs() async throws {
    let env = try Env()
    let (s, _, id) = try await makeConflict(env)
    try await env.repos.conflicts.resolve(id, with: .keepTheirs)
    #expect(try await env.repos.songs.fetchSong(id: s.id)?.title == "Theirs")
    #expect(try await env.repos.syncStore.pendingEntityKeys().isEmpty)
  }

  @Test func conflictKeepBothAsCopy() async throws {
    let env = try Env()
    let (s, _, id) = try await makeConflict(env)
    try await env.repos.conflicts.resolve(id, with: .keepBothAsCopy)
    #expect(try await env.repos.songs.fetchSong(id: s.id)?.title == "Theirs")
    let all = await titles(env, query(.personal(userID: me)))
    #expect(all.sorted() == ["Mine (copy)", "Theirs"])
    let ops = try await env.repos.syncStore.nextPendingOperations(limit: 5, now: .now)
    #expect(ops.count == 1)
    if case .createSong(let copy) = ops.first?.operation { #expect(copy.id != s.id) } else {
      Issue.record("expected createSong")
    }
  }

  @Test func conflictBlocksEntityQueue() async throws {
    let env = try Env()
    _ = try await makeConflict(env)
    let s = try #require(await first(env.repos.songs.songs(query(.personal(userID: me))))?.first)
    try await env.repos.songs.update(id: s.id, SongPatch(artist: "later"))
    #expect(try await env.repos.syncStore.nextPendingOperations(limit: 5, now: .now).isEmpty)
  }

  // MARK: Playlists

  @Test func playlistLifecycle() async throws {
    let env = try Env()
    let ctx = AppContext.personal(userID: me)
    let a = makeSong("A"), b = makeSong("B"), c = makeSong("C", lyrics: nil)
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [a, b, c]))
    let pl = try await env.repos.playlists.create(PlaylistDraft(name: "Set", songIDs: [a.id]), in: ctx)
    try await env.repos.playlists.addSongs([b.id, a.id, c.id], to: pl.id)
    var detail = await first(env.repos.playlists.playlist(id: pl.id))
    #expect(detail??.songs.map(\.title) == ["A", "B", "C"])
    try await env.repos.playlists.reorder(playlistID: pl.id, songIDs: [c.id, b.id, a.id])
    detail = await first(env.repos.playlists.playlist(id: pl.id))
    #expect(detail??.songs.map(\.title) == ["C", "B", "A"])

    var summary = await first(env.repos.playlists.playlists(in: ctx, includeArchived: false))?.first
    #expect(summary?.songCount == 3 && summary?.isFullyAvailableOffline == false)
    try await env.repos.playlists.removeSong(c.id, from: pl.id)
    try await env.repos.playlists.setPinned(true, playlistID: pl.id)
    summary = await first(env.repos.playlists.playlists(in: ctx, includeArchived: false))?.first
    #expect(summary?.songCount == 2 && summary?.isFullyAvailableOffline == true && summary?.isPinned == true)

    // add+remove before push cancel out: no removeSong op was queued.
    let ops = try await env.repos.syncStore.nextPendingOperations(limit: 20, now: .now).map(\.operation)
    #expect(ops.count == 1)  // createPlaylist is the head; the rest wait behind it
    try await env.repos.playlists.setArchived(id: pl.id, true)
    #expect(await first(env.repos.playlists.playlists(in: ctx, includeArchived: false))?.isEmpty == true)
    #expect(await first(env.repos.playlists.playlists(in: ctx, includeArchived: true))?.count == 1)
    try await env.repos.playlists.delete(id: pl.id)
    #expect(try await env.repos.syncStore.pendingEntityKeys().isEmpty)
  }

  // MARK: Teams

  @Test func teamOpsRequireRemoteAndNotifyAfterMutation() async throws {
    let offline = try Env()
    await #expect(throws: CapoError.offlineUnavailable) {
      _ = try await offline.repos.teams.createTeam(name: "T", icon: nil, isPublic: false)
    }
    let counter = Counter()
    let backend = InMemoryBackend()
    let env = try Env(teamsRemote: FakeTeamsRemote(backend: backend)) { counter.bump() }
    _ = try await env.repos.teams.createTeam(name: "T", icon: nil, isPublic: false)
    #expect(counter.value == 1)
  }

  @Test func teamsStreamJoinsRole() async throws {
    let env = try Env()
    let team = Team(
      id: teamA, name: "Band", icon: nil, avatarURL: nil, isPublic: false, createdBy: me,
      createdAt: .now(), updatedAt: .now())
    let membership = TeamMembership(id: UUID(), teamID: teamA, userID: me, role: .admin, joinedAt: .now())
    try await env.repos.syncStore.apply(PullBatch(teams: [team], memberships: [membership]))
    let teams = await first(env.repos.teams.teams())
    #expect(teams?.map(\.role) == [.admin])
  }

  // MARK: Erase & metadata

  @Test func eraseAndMetadata() async throws {
    let env = try Env()
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: [makeSong("A")]))
    try await env.repos.syncStore.saveSyncMetadata(SyncMetadata(lastPullAt: Date(timeIntervalSince1970: 5), lastPushAt: nil, lastError: "e"))
    #expect(try await env.repos.syncStore.syncMetadata().lastError == "e")
    try env.db.erase()
    #expect(try await env.repos.syncStore.localVersions(of: .songs).isEmpty)
    #expect(try await env.repos.syncStore.syncMetadata().lastError == nil)
  }

  // MARK: Performance

  @Test func searchOver2000SongsIsFast() async throws {
    let env = try Env()
    let words = ["amor", "fuego", "cielo", "canción", "gracia", "santo", "río", "luz"]
    let songs = (0..<2000).map { i in
      makeSong(
        "\(words[i % 8]) \(words[(i / 8) % 8]) \(i)", lyrics: "[C]\(words[i % 7]) [G]\(words[i % 5]) " + String(repeating: "la ", count: 200))
    }
    try await env.repos.syncStore.apply(PullBatch(upsertSongs: songs))
    let q = SongQuery(context: .personal(userID: me), searchText: "cancion gra", sort: .relevance)
    _ = try await env.db.writer.read { db in try GRDBSongRepository.fetchList(db, q) }  // warm
    let clock = ContinuousClock()
    var result: [SongListItem] = []
    let elapsed = try await clock.measure {
      result = try await env.db.writer.read { db in try GRDBSongRepository.fetchList(db, q) }
    }
    #expect(!result.isEmpty)
    #expect(elapsed < .milliseconds(50), "search took \(elapsed)")
  }
}
