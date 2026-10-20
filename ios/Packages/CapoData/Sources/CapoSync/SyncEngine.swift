import CapoCore
import CapoStore
import Foundation

/// Push-then-pull sync coordinator. `syncNow` is serialized: calls made while a run is in flight
/// coalesce into a single follow-up run and return once that follow-up has finished.
public actor SyncEngine: SyncService {
  static let chunkSize = 100
  static let pushBatchSize = 50
  static let maxBackoff: TimeInterval = 300

  private let userID: UserID
  private let store: any LocalSyncStore
  private let remote: any RemoteSyncSource
  private let writer: any RemoteWriter
  private let realtime: (any RealtimeNotifier)?
  private let reachability: any ReachabilityMonitor
  private let clock: @Sendable () -> Date
  private let realtimeDebounce: Duration
  private let outboxDebounce: Duration

  private let statusSubject = ValueSubject(SyncStatus())

  private var isOnline = true
  private var isSyncing = false
  private var rerunRequested = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var lastSuccessAt: Date?
  private var loadedMetadata = false

  private var scope: SyncScope
  private var lifecycleTasks: [Task<Void, Never>] = []
  private var realtimeTask: Task<Void, Never>?
  private var debounceTasks: [String: Task<Void, Never>] = [:]

  public init(
    userID: UserID, store: any LocalSyncStore, remote: any RemoteSyncSource,
    writer: any RemoteWriter, realtime: (any RealtimeNotifier)?,
    reachability: any ReachabilityMonitor, clock: @escaping @Sendable () -> Date = Date.init,
    realtimeDebounce: Duration = .seconds(1), outboxDebounce: Duration = .milliseconds(500)
  ) {
    self.userID = userID
    self.store = store
    self.remote = remote
    self.writer = writer
    self.realtime = realtime
    self.reachability = reachability
    self.clock = clock
    self.realtimeDebounce = realtimeDebounce
    self.outboxDebounce = outboxDebounce
    scope = SyncScope(userID: userID, teamIDs: [])
  }

  // MARK: SyncService

  public nonisolated func status() -> AsyncStream<SyncStatus> {
    statusSubject.stream()
  }

  public func start() async {
    guard lifecycleTasks.isEmpty else { return }
    let reachability = reachability
    let store = store
    lifecycleTasks.append(
      Task { [weak self] in
        for await online in reachability.isOnline() {
          guard !Task.isCancelled else { return }
          await self?.reachabilityChanged(online)
        }
      })
    lifecycleTasks.append(
      Task { [weak self] in
        var lastCount: Int?
        for await count in store.outboxChanges() {
          guard !Task.isCancelled else { return }
          // Only growth counts as an enqueue; draining or backoff updates must not retrigger.
          if let previous = lastCount, count > previous {
            await self?.scheduleDebounced(key: "outbox", reason: .outboxEnqueued)
          }
          lastCount = count
        }
      })
    subscribeRealtime()
  }

  public func stop() async {
    for task in lifecycleTasks { task.cancel() }
    lifecycleTasks.removeAll()
    realtimeTask?.cancel()
    realtimeTask = nil
    for task in debounceTasks.values { task.cancel() }
    debounceTasks.removeAll()
  }

  public func syncNow(reason: SyncReason) async {
    if isSyncing {
      rerunRequested = true
      await withCheckedContinuation { waiters.append($0) }
      return
    }
    isSyncing = true
    repeat {
      rerunRequested = false
      await runOnce()
    } while rerunRequested
    isSyncing = false
    let pending = waiters
    waiters.removeAll()
    for waiter in pending { waiter.resume() }
  }

  // MARK: Triggers

  private func reachabilityChanged(_ online: Bool) async {
    let wasOnline = isOnline
    isOnline = online
    if !online {
      await publish(.offline)
    } else if !wasOnline {
      await syncNow(reason: .reachability)
    }
  }

  private func scheduleDebounced(key: String, reason: SyncReason) {
    debounceTasks[key]?.cancel()
    let delay = key == "outbox" ? outboxDebounce : realtimeDebounce
    debounceTasks[key] = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else { return }
      await self?.syncNow(reason: reason)
    }
  }

  private func subscribeRealtime() {
    realtimeTask?.cancel()
    realtimeTask = nil
    guard let realtime, !lifecycleTasks.isEmpty else { return }
    let stream = realtime.changes(scope: scope)
    realtimeTask = Task { [weak self] in
      for await _ in stream {
        guard !Task.isCancelled else { return }
        await self?.scheduleDebounced(key: "realtime", reason: .realtime)
      }
    }
  }

  // MARK: Run

  private func runOnce() async {
    guard isOnline else {
      await publish(.offline)
      return
    }
    await loadMetadataIfNeeded()
    var firstError: String?

    await publish(.pushing)
    do {
      try await push()
    } catch {
      firstError = describe(error)
    }

    await publish(.pulling)
    do {
      try await pull()
    } catch {
      firstError = firstError ?? describe(error)
    }

    var metadata = (try? await store.syncMetadata()) ?? SyncMetadata()
    metadata.lastError = firstError
    if firstError == nil { lastSuccessAt = clock() }
    try? await store.saveSyncMetadata(metadata)

    if let firstError {
      await publish(.error(firstError))
    } else {
      await publish(.idle)
    }
  }

  private func loadMetadataIfNeeded() async {
    guard !loadedMetadata else { return }
    loadedMetadata = true
    if let metadata = try? await store.syncMetadata() {
      lastSuccessAt = [metadata.lastPullAt, metadata.lastPushAt].compactMap { $0 }.max()
    }
  }

  private func publish(_ phase: SyncPhase) async {
    let counts = (try? await store.statusCounts()) ?? (pending: 0, conflicts: 0, failed: 0)
    statusSubject.send(
      SyncStatus(
        phase: phase, lastSuccessAt: lastSuccessAt, pendingOperations: counts.pending,
        conflicts: counts.conflicts, failedOperations: counts.failed))
  }

  private func describe(_ error: Error) -> String {
    if let error = error as? CapoError { return String(describing: error) }
    return error.localizedDescription
  }

  // MARK: Push

  private func push() async throws {
    var seen = Set<Int64>()
    var blocked = Set<String>()
    while true {
      let batch = try await store.nextPendingOperations(
        limit: Self.pushBatchSize, now: clock())
      let fresh = batch.filter { !seen.contains($0.id) }
      if fresh.isEmpty { break }
      for record in fresh {
        seen.insert(record.id)
        let key = record.operation.entityKey
        // FIFO per entity: once an op fails transiently or conflicts, later ops wait.
        if blocked.contains(key) { continue }
        let outcome = await attempt(record)
        if case .retryLater = outcome { blocked.insert(key) }
        if case .conflict = outcome { blocked.insert(key) }
        try await store.complete(record.id, outcome: outcome)
      }
    }
    var metadata = try await store.syncMetadata()
    metadata.lastPushAt = clock()
    try await store.saveSyncMetadata(metadata)
  }

  private func attempt(_ record: OutboxRecord) async -> OutboxOutcome {
    do {
      try await store.markInflight(record.id)
      switch try await writer.apply(record.operation) {
      case .applied(let song): return .applied(serverSong: song)
      case .conflict(let server): return .conflict(server: server)
      case .rejected(let error): return .rejected(error)
      }
    } catch {
      return .retryLater(
        error: describe(error), nextAttemptAt: clock().addingTimeInterval(Self.backoff(record.attempts)))
    }
  }

  static func backoff(_ attempts: Int) -> TimeInterval {
    min(pow(2, Double(max(0, min(attempts, 20)))), maxBackoff)
  }

  // MARK: Pull

  private func pull() async throws {
    let memberships = try await remote.memberships(userID: userID)
    let teamIDs = Array(Set(memberships.map(\.teamID))).sorted { $0.uuidString < $1.uuidString }
    let newScope = SyncScope(userID: userID, teamIDs: teamIDs)
    let teams = teamIDs.isEmpty ? [] : try await remote.teams(ids: teamIDs)

    let remoteSongVersions = try await remote.songVersions(scope: newScope)
    let songDiff = diff(remote: remoteSongVersions, local: try await store.localVersions(of: .songs))
    var songs: [Song] = []
    for ids in songDiff.changed.chunked(Self.chunkSize) {
      songs += try await remote.songs(ids: ids)
    }

    let remotePlaylistVersions = try await remote.playlistVersions(scope: newScope)
    let playlistDiff = diff(
      remote: remotePlaylistVersions, local: try await store.localVersions(of: .playlists))
    var playlists: [Playlist] = []
    for ids in playlistDiff.changed.chunked(Self.chunkSize) {
      playlists += try await remote.playlists(ids: ids)
    }

    var entries: [PlaylistEntry] = []
    for ids in remotePlaylistVersions.map(\.id).chunked(Self.chunkSize) {
      entries += try await remote.playlistEntries(playlistIDs: ids)
    }
    let tags = try await remote.tags(scope: newScope)
    let assignments = try await remote.tagAssignments()
    let settings = try await remote.userSongSettings(userID: userID)
    let profile = try await remote.profile(userID: userID)

    let batch = PullBatch(
      teams: teams, memberships: memberships, upsertSongs: songs,
      deleteSongIDs: songDiff.deleted, upsertPlaylists: playlists,
      deletePlaylistIDs: playlistDiff.deleted, playlistEntries: entries, tags: tags,
      tagAssignments: assignments, userSongSettings: settings, profile: profile,
      skipEntityKeys: try await store.pendingEntityKeys())
    try await store.apply(batch)

    var metadata = try await store.syncMetadata()
    metadata.lastPullAt = clock()
    try await store.saveSyncMetadata(metadata)

    if newScope != scope {
      scope = newScope
      subscribeRealtime()
    }
  }

  private func diff(remote: [RowVersion], local: [UUID: ServerTimestamp]) -> (
    changed: [UUID], deleted: [UUID]
  ) {
    var remoteIDs = Set<UUID>()
    var changed: [UUID] = []
    for version in remote {
      remoteIDs.insert(version.id)
      if local[version.id]?.raw != version.updatedAt.raw { changed.append(version.id) }
    }
    let deleted = local.keys.filter { !remoteIDs.contains($0) }
    return (changed, Array(deleted))
  }
}

extension Array {
  fileprivate func chunked(_ size: Int) -> [[Element]] {
    stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
  }
}
