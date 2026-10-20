import CapoCore
import Foundation
import os

public struct FakeError: Error, Hashable, Sendable {
  public var message: String
  public init(_ message: String = "fake transient failure") { self.message = message }
}

/// Scriptable remote for CapoSync tests. Serves `state`, records every call, and throws queued errors.
public actor FakeRemoteSyncSource: RemoteSyncSource {
  public var state: BackendState
  public private(set) var calls: [String] = []
  /// Ids requested through `songs(ids:)` / `playlists(ids:)`, in call order.
  public private(set) var requestedSongIDs: [[SongID]] = []
  public private(set) var requestedPlaylistIDs: [[PlaylistID]] = []
  private var queuedErrors: [String: [any Error]] = [:]

  public init(state: BackendState = BackendState()) {
    self.state = state
  }

  public func setState(_ state: BackendState) { self.state = state }
  public func update(_ body: @Sendable (inout BackendState) -> Void) { body(&state) }

  /// The next call to `method` (e.g. "songVersions") throws `error`. Queue several to fail repeatedly.
  public func failNext(_ method: String, with error: any Error = FakeError()) {
    queuedErrors[method, default: []].append(error)
  }

  public func resetCalls() {
    calls = []
    requestedSongIDs = []
    requestedPlaylistIDs = []
  }

  private func record(_ method: String) throws {
    calls.append(method)
    if var errors = queuedErrors[method], !errors.isEmpty {
      let error = errors.removeFirst()
      queuedErrors[method] = errors
      throw error
    }
  }

  private func inScope(_ scope: SyncScope, userID: UserID?, teamID: TeamID?) -> Bool {
    userID == scope.userID || teamID.map(scope.teamIDs.contains) == true
  }

  public func memberships(userID: UserID) async throws -> [TeamMembership] {
    try record("memberships")
    return state.memberships.filter { $0.userID == userID }
  }

  public func teams(ids: [TeamID]) async throws -> [Team] {
    try record("teams")
    return state.teams.filter { ids.contains($0.id) }
  }

  public func songVersions(scope: SyncScope) async throws -> [RowVersion] {
    try record("songVersions")
    return state.songs.filter { inScope(scope, userID: $0.userID, teamID: $0.teamID) }
      .map { RowVersion(id: $0.id, updatedAt: $0.updatedAt) }
  }

  public func songs(ids: [SongID]) async throws -> [Song] {
    try record("songs")
    requestedSongIDs.append(ids)
    return state.songs.filter { ids.contains($0.id) }
  }

  public func playlistVersions(scope: SyncScope) async throws -> [RowVersion] {
    try record("playlistVersions")
    return state.playlists.filter { inScope(scope, userID: $0.userID, teamID: $0.teamID) }
      .map { RowVersion(id: $0.id, updatedAt: $0.updatedAt) }
  }

  public func playlists(ids: [PlaylistID]) async throws -> [Playlist] {
    try record("playlists")
    requestedPlaylistIDs.append(ids)
    return state.playlists.filter { ids.contains($0.id) }
  }

  public func playlistEntries(playlistIDs: [PlaylistID]) async throws -> [PlaylistEntry] {
    try record("playlistEntries")
    return state.playlistEntries.filter { playlistIDs.contains($0.playlistID) }
  }

  public func tags(scope: SyncScope) async throws -> [SongTag] {
    try record("tags")
    return state.tags.filter { inScope(scope, userID: $0.userID, teamID: $0.teamID) }
  }

  public func tagAssignments() async throws -> [TagAssignment] {
    try record("tagAssignments")
    return state.tagAssignments
  }

  public func userSongSettings(userID: UserID) async throws -> [UserSongSettings] {
    try record("userSongSettings")
    return state.userSongSettings
  }

  public func profile(userID: UserID) async throws -> Profile {
    try record("profile")
    guard let profile = state.profile else { throw CapoError.notFound }
    return profile
  }
}

/// Scriptable writer: queued results are consumed FIFO; when empty, `defaultResult` answers.
public actor FakeRemoteWriter: RemoteWriter {
  public enum Scripted: Sendable {
    case result(RemoteApplyResult)
    case failure(any Error)
  }

  public private(set) var applied: [OutboxOperation] = []
  private var queue: [Scripted] = []
  private let defaultResult: @Sendable (OutboxOperation) -> RemoteApplyResult

  public init(
    defaultResult: @escaping @Sendable (OutboxOperation) -> RemoteApplyResult = FakeRemoteWriter.echo
  ) {
    self.defaultResult = defaultResult
  }

  /// createSong echoes the song back; everything else is `.applied(serverSong: nil)`.
  public static let echo: @Sendable (OutboxOperation) -> RemoteApplyResult = { op in
    if case .createSong(let song) = op { return .applied(serverSong: song) }
    return .applied(serverSong: nil)
  }

  public func enqueue(_ result: RemoteApplyResult) { queue.append(.result(result)) }
  public func enqueueFailure(_ error: any Error = FakeError()) { queue.append(.failure(error)) }

  public func apply(_ op: OutboxOperation) async throws -> RemoteApplyResult {
    applied.append(op)
    guard !queue.isEmpty else { return defaultResult(op) }
    switch queue.removeFirst() {
    case .result(let result): return result
    case .failure(let error): throw error
    }
  }
}

/// Online/offline switch; `isOnline()` replays the current value.
public final class FakeReachability: ReachabilityMonitor {
  private let subject: ValueSubject<Bool>
  public init(online: Bool = true) { subject = ValueSubject(online) }
  public var online: Bool { subject.value }
  public func set(online: Bool) { subject.send(online) }
  public func isOnline() -> AsyncStream<Bool> { subject.stream() }
}

/// Emits realtime changes on demand (no replay).
public final class FakeRealtimeNotifier: RealtimeNotifier {
  private let continuations = OSAllocatedUnfairLock<[UUID: AsyncStream<RealtimeChange>.Continuation]>(
    initialState: [:])

  public init() {}

  public func emit(_ change: RealtimeChange = RealtimeChange(table: "songs")) {
    for continuation in continuations.withLock({ Array($0.values) }) {
      continuation.yield(change)
    }
  }

  public func changes(scope: SyncScope) -> AsyncStream<RealtimeChange> {
    let id = UUID()
    let (stream, continuation) = AsyncStream<RealtimeChange>.makeStream()
    continuations.withLock { $0[id] = continuation }
    continuation.onTermination = { [weak self] _ in
      _ = self?.continuations.withLock { $0.removeValue(forKey: id) }
    }
    return stream
  }
}

/// Online team operations applied directly to an InMemoryBackend.
public struct FakeTeamsRemote: TeamsRemote {
  public let backend: InMemoryBackend
  public init(backend: InMemoryBackend) { self.backend = backend }

  public func members(teamID: TeamID) async throws -> [TeamMember] {
    let state = await backend.snapshot()
    return state.memberships.filter { $0.teamID == teamID }.map { membership in
      TeamMember(membership: membership, profile: state.profiles.first { $0.id == membership.userID })
    }
  }

  public func invitations(teamID: TeamID) async throws -> [TeamInvitation] {
    await backend.snapshot().invitations.filter { $0.teamID == teamID && $0.acceptedAt == nil }
  }

  public func pendingInvitations(email: String) async throws -> [PendingInvitation] {
    let state = await backend.snapshot()
    return state.invitations.filter { $0.email == email && $0.acceptedAt == nil }.map { invitation in
      PendingInvitation(
        invitation: invitation,
        teamName: state.teams.first { $0.id == invitation.teamID }?.name ?? "",
        inviterName: state.profiles.first { $0.id == invitation.invitedBy }?.fullName)
    }
  }

  public func createTeam(name: String, icon: String?, isPublic: Bool) async throws -> Team {
    let me = backend.userID
    return await backend.mutate { state in
      let now = ServerTimestamp.now()
      let team = Team(
        id: UUID(), name: name, icon: icon, avatarURL: nil, isPublic: isPublic, createdBy: me,
        createdAt: now, updatedAt: now)
      state.teams.append(team)
      state.memberships.append(
        TeamMembership(id: UUID(), teamID: team.id, userID: me, role: .owner, joinedAt: now))
      return team
    }
  }

  public func updateTeam(id: TeamID, name: String, icon: String?) async throws {
    await backend.mutate { state in
      guard let i = state.teams.firstIndex(where: { $0.id == id }) else { return }
      state.teams[i].name = name
      state.teams[i].icon = icon
      state.teams[i].updatedAt = .now()
    }
  }

  public func deleteTeam(id: TeamID) async throws {
    await backend.mutate { state in
      state.teams.removeAll { $0.id == id }
      state.memberships.removeAll { $0.teamID == id }
    }
  }

  public func leaveTeam(id: TeamID) async throws {
    let me = backend.userID
    await backend.mutate { state in state.memberships.removeAll { $0.teamID == id && $0.userID == me } }
  }

  public func invite(email: String, role: TeamRole, teamID: TeamID) async throws -> TeamInvitation {
    let me = backend.userID
    return await backend.mutate { state in
      let invitation = TeamInvitation(
        id: UUID(), teamID: teamID, email: email, role: role, invitedBy: me,
        token: UUID().uuidString, expiresAt: FakeSeed.timestamp(minutesAgo: -7 * 24 * 60),
        acceptedAt: nil, createdAt: .now())
      state.invitations.append(invitation)
      return invitation
    }
  }

  public func revokeInvitation(id: UUID) async throws {
    await backend.mutate { state in state.invitations.removeAll { $0.id == id } }
  }

  public func acceptInvitation(token: String) async throws -> TeamID {
    let me = backend.userID
    return try await backend.mutate { state in
      guard let i = state.invitations.firstIndex(where: { $0.token == token }) else {
        throw CapoError.notFound
      }
      state.invitations[i].acceptedAt = .now()
      let invitation = state.invitations[i]
      state.memberships.append(
        TeamMembership(
          id: UUID(), teamID: invitation.teamID, userID: me, role: invitation.role, joinedAt: .now()))
      return invitation.teamID
    }
  }

  public func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws {
    await backend.mutate { state in
      guard let i = state.memberships.firstIndex(where: { $0.teamID == teamID && $0.userID == userID })
      else { return }
      state.memberships[i].role = role
    }
  }

  public func removeMember(userID: UserID, teamID: TeamID) async throws {
    await backend.mutate { state in
      state.memberships.removeAll { $0.teamID == teamID && $0.userID == userID }
    }
  }

  public func transferOwnership(teamID: TeamID, to userID: UserID) async throws {
    let me = backend.userID
    await backend.mutate { state in
      for i in state.memberships.indices where state.memberships[i].teamID == teamID {
        if state.memberships[i].userID == userID { state.memberships[i].role = .owner }
        else if state.memberships[i].userID == me { state.memberships[i].role = .admin }
      }
    }
  }

  public func ensureShareCode(playlistID: PlaylistID) async throws -> String {
    try await backend.mutate { state in
      guard let i = state.playlists.firstIndex(where: { $0.id == playlistID }) else {
        throw CapoError.notFound
      }
      if let code = state.playlists[i].shareCode { return code }
      let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
      let code = String((0..<12).map { _ in alphabet.randomElement()! })
      state.playlists[i].shareCode = code
      return code
    }
  }
}
