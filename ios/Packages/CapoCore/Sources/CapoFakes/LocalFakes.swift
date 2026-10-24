import CapoCore
import Foundation

// In-memory implementations of every local contract, all backed by one InMemoryBackend.

public struct FakeSongRepository: SongRepository {
  public let backend: InMemoryBackend
  public init(backend: InMemoryBackend) { self.backend = backend }

  public func songs(_ query: SongQuery) -> AsyncStream<[SongListItem]> {
    backend.observe { $0.songs(matching: query) }
  }

  public func song(id: SongID) -> AsyncStream<Song?> {
    backend.observe { state in state.songs.first { $0.id == id } }
  }

  public func fetchSong(id: SongID) async throws -> Song? {
    await backend.snapshot().songs.first { $0.id == id }
  }

  public func create(_ draft: SongDraft, in context: AppContext) async throws -> Song {
    let me = backend.userID
    return await backend.mutate { state in
      let now = ServerTimestamp.now()
      let song = Song(
        id: UUID(), title: draft.title, artist: draft.artist, key: draft.key, bpm: draft.bpm,
        lyrics: draft.lyrics, notes: draft.notes, transpose: draft.transpose, capo: draft.capo,
        status: draft.status, userID: context.teamID == nil ? me : nil, teamID: context.teamID,
        createdBy: me, createdAt: now, updatedAt: now)
      state.songs.append(song)
      return song
    }
  }

  public func update(id: SongID, _ patch: SongPatch) async throws {
    try await backend.mutate { state in
      guard let index = state.songs.firstIndex(where: { $0.id == id }) else {
        throw CapoError.notFound
      }
      var song = state.songs[index]
      if let v = patch.title { song.title = v }
      if let v = patch.artist { song.artist = v.isEmpty ? nil : v }
      if let v = patch.key { song.key = v.isEmpty ? nil : v }
      if let v = patch.bpm { song.bpm = v == 0 ? nil : v }
      if let v = patch.lyrics { song.lyrics = v.isEmpty ? nil : v }
      if let v = patch.notes { song.notes = v.isEmpty ? nil : v }
      if let v = patch.transpose { song.transpose = v }
      if let v = patch.capo { song.capo = v }
      if let v = patch.status { song.status = v }
      if let v = patch.teamID {
        song.teamID = v
        song.userID = nil
      }
      song.updatedAt = .now()
      state.songs[index] = song
    }
  }

  public func delete(id: SongID) async throws {
    await backend.mutate { state in
      state.songs.removeAll { $0.id == id }
      state.tagAssignments.removeAll { $0.songID == id }
      state.playlistEntries.removeAll { $0.songID == id }
    }
  }

  public func setTags(songID: SongID, tagIDs: [TagID]) async throws {
    await backend.mutate { state in
      state.tagAssignments.removeAll { $0.songID == songID }
      state.tagAssignments += tagIDs.map { TagAssignment(songID: songID, tagID: $0) }
    }
  }

  public func tags(forSong id: SongID) -> AsyncStream<[SongTag]> {
    backend.observe { $0.tags(forSong: id) }
  }
}

public struct FakeTagRepository: TagRepository {
  public let backend: InMemoryBackend
  public init(backend: InMemoryBackend) { self.backend = backend }

  public func tags(in context: AppContext) -> AsyncStream<[SongTag]> {
    backend.observe { state in
      state.tags.filter { state.matches(context, userID: $0.userID, teamID: $0.teamID) }
        .sorted { $0.name < $1.name }
    }
  }

  public func create(name: String, color: String?, in context: AppContext) async throws -> SongTag {
    let me = backend.userID
    return await backend.mutate { state in
      let tag = SongTag(
        id: UUID(), name: name, color: color, userID: context.teamID == nil ? me : nil,
        teamID: context.teamID, createdAt: .now())
      state.tags.append(tag)
      return tag
    }
  }

  public func delete(id: TagID) async throws {
    await backend.mutate { state in
      state.tags.removeAll { $0.id == id }
      state.tagAssignments.removeAll { $0.tagID == id }
    }
  }
}

public struct FakePlaylistRepository: PlaylistRepository {
  public let backend: InMemoryBackend
  public init(backend: InMemoryBackend) { self.backend = backend }

  public func playlists(in context: AppContext, includeArchived: Bool) -> AsyncStream<[PlaylistSummary]> {
    backend.observe { state in
      state.playlists
        .filter { state.matches(context, userID: $0.userID, teamID: $0.teamID) }
        .filter { includeArchived || $0.archivedAt == nil }
        .sorted { ($0.date ?? "") > ($1.date ?? "") }
        .map(state.summary)
    }
  }

  public func playlist(id: PlaylistID) -> AsyncStream<PlaylistDetail?> {
    backend.observe { $0.detail(id) }
  }

  public func create(_ draft: PlaylistDraft, in context: AppContext) async throws -> Playlist {
    let me = backend.userID
    return await backend.mutate { state in
      let now = ServerTimestamp.now()
      let playlist = Playlist(
        id: UUID(), name: draft.name, description: draft.description, date: draft.date,
        isPublic: false, allowGuestEditing: false, shareCode: nil, shareExpiresAt: nil,
        archivedAt: nil, userID: context.teamID == nil ? me : nil, teamID: context.teamID,
        createdBy: me, createdAt: now, updatedAt: now)
      state.playlists.append(playlist)
      state.playlistEntries += draft.songIDs.enumerated().map {
        PlaylistEntry(id: UUID(), playlistID: playlist.id, songID: $0.element, position: $0.offset)
      }
      return playlist
    }
  }

  public func update(id: PlaylistID, _ patch: PlaylistPatch) async throws {
    try await backend.mutate { state in
      guard let i = state.playlists.firstIndex(where: { $0.id == id }) else { throw CapoError.notFound }
      if let v = patch.name { state.playlists[i].name = v }
      if let v = patch.description { state.playlists[i].description = v.isEmpty ? nil : v }
      if let v = patch.date { state.playlists[i].date = v.isEmpty ? nil : v }
      if let v = patch.isPublic { state.playlists[i].isPublic = v }
      if let v = patch.allowGuestEditing { state.playlists[i].allowGuestEditing = v }
      state.playlists[i].updatedAt = .now()
    }
  }

  public func delete(id: PlaylistID) async throws {
    await backend.mutate { state in
      state.playlists.removeAll { $0.id == id }
      state.playlistEntries.removeAll { $0.playlistID == id }
      state.pinnedPlaylistIDs.remove(id)
    }
  }

  public func setArchived(id: PlaylistID, _ archived: Bool) async throws {
    await backend.mutate { state in
      guard let i = state.playlists.firstIndex(where: { $0.id == id }) else { return }
      state.playlists[i].archivedAt = archived ? .now() : nil
    }
  }

  public func addSongs(_ songIDs: [SongID], to playlistID: PlaylistID) async throws {
    await backend.mutate { state in
      var ids = state.orderedSongIDs(inPlaylist: playlistID)
      for id in songIDs where !ids.contains(id) { ids.append(id) }
      Self.write(ids, to: playlistID, in: &state)
    }
  }

  public func removeSong(_ songID: SongID, from playlistID: PlaylistID) async throws {
    await backend.mutate { state in
      Self.write(state.orderedSongIDs(inPlaylist: playlistID).filter { $0 != songID }, to: playlistID, in: &state)
    }
  }

  public func reorder(playlistID: PlaylistID, songIDs: [SongID]) async throws {
    await backend.mutate { state in Self.write(songIDs, to: playlistID, in: &state) }
  }

  public func setPinned(_ pinned: Bool, playlistID: PlaylistID) async throws {
    await backend.mutate { state in
      if pinned { state.pinnedPlaylistIDs.insert(playlistID) } else { state.pinnedPlaylistIDs.remove(playlistID) }
    }
  }

  private static func write(_ ids: [SongID], to playlistID: PlaylistID, in state: inout BackendState) {
    state.playlistEntries.removeAll { $0.playlistID == playlistID }
    state.playlistEntries += ids.enumerated().map {
      PlaylistEntry(id: UUID(), playlistID: playlistID, songID: $0.element, position: $0.offset)
    }
  }
}

public struct FakeSettingsRepository: SettingsRepository {
  public let backend: InMemoryBackend
  public init(backend: InMemoryBackend) { self.backend = backend }

  public func songSettings(songID: SongID) -> AsyncStream<UserSongSettings?> {
    backend.observe { state in state.userSongSettings.first { $0.songID == songID } }
  }

  public func saveSongSettings(_ settings: UserSongSettings) async throws {
    await backend.mutate { state in
      var settings = settings
      settings.updatedAt = .now()
      state.userSongSettings.removeAll { $0.songID == settings.songID }
      state.userSongSettings.append(settings)
    }
  }

  public func preferences() -> AsyncStream<UserPreferences> {
    backend.observe { $0.profile?.preferences ?? .default }
  }

  public func updatePreferences(_ patch: PreferencesPatch) async throws {
    await backend.mutate { state in
      guard let current = state.profile else { return }
      state.profile?.preferences = UserPreferences(json: current.preferences.json(applying: patch))
      state.profile?.updatedAt = .now()
    }
  }
}

public struct FakeTeamRepository: TeamRepository {
  public let backend: InMemoryBackend
  public let remote: FakeTeamsRemote
  public init(backend: InMemoryBackend) {
    self.backend = backend
    remote = FakeTeamsRemote(backend: backend)
  }

  public func teams() -> AsyncStream<[TeamWithRole]> {
    let me = backend.userID
    return backend.observe { state in
      state.memberships.filter { $0.userID == me }.compactMap { membership in
        state.teams.first { $0.id == membership.teamID }.map { TeamWithRole(team: $0, role: membership.role) }
      }.sorted { $0.team.name < $1.team.name }
    }
  }

  public func members(teamID: TeamID) async throws -> [TeamMember] { try await remote.members(teamID: teamID) }
  public func invitations(teamID: TeamID) async throws -> [TeamInvitation] {
    try await remote.invitations(teamID: teamID)
  }
  public func pendingInvitationsForMe() async throws -> [PendingInvitation] {
    let email = await backend.snapshot().profile?.email ?? ""
    return try await remote.pendingInvitations(email: email)
  }
  public func createTeam(name: String, icon: String?, isPublic: Bool) async throws -> Team {
    try await remote.createTeam(name: name, icon: icon, isPublic: isPublic)
  }
  public func updateTeam(id: TeamID, name: String, icon: String?) async throws {
    try await remote.updateTeam(id: id, name: name, icon: icon)
  }
  public func deleteTeam(id: TeamID) async throws { try await remote.deleteTeam(id: id) }
  public func leaveTeam(id: TeamID) async throws { try await remote.leaveTeam(id: id) }
  public func invite(email: String, role: TeamRole, teamID: TeamID) async throws -> TeamInvitation {
    try await remote.invite(email: email, role: role, teamID: teamID)
  }
  public func revokeInvitation(id: UUID) async throws { try await remote.revokeInvitation(id: id) }
  public func acceptInvitation(token: String) async throws -> TeamID {
    try await remote.acceptInvitation(token: token)
  }
  public func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws {
    try await remote.changeRole(userID: userID, teamID: teamID, role: role)
  }
  public func removeMember(userID: UserID, teamID: TeamID) async throws {
    try await remote.removeMember(userID: userID, teamID: teamID)
  }
  public func transferOwnership(teamID: TeamID, to userID: UserID) async throws {
    try await remote.transferOwnership(teamID: teamID, to: userID)
  }
}

public struct FakeSharingService: SharingService {
  public let backend: InMemoryBackend
  public let webBaseURL: URL
  public init(backend: InMemoryBackend, webBaseURL: URL = URL(string: "https://capo.example")!) {
    self.backend = backend
    self.webBaseURL = webBaseURL
  }

  public func ensureShareCode(playlistID: PlaylistID) async throws -> String {
    try await FakeTeamsRemote(backend: backend).ensureShareCode(playlistID: playlistID)
  }

  public func shareURL(forCode code: String) -> URL {
    webBaseURL.appendingPathComponent("playlists").appendingPathComponent(code)
  }
}

public struct FakeConflictRepository: ConflictRepository {
  public let backend: InMemoryBackend
  public init(backend: InMemoryBackend) { self.backend = backend }

  public func conflicts() -> AsyncStream<[SongConflict]> {
    backend.observe { $0.conflicts }
  }

  public func resolve(_ conflictID: UUID, with resolution: ConflictResolution) async throws {
    try await backend.mutate { state in
      guard let conflict = state.conflicts.first(where: { $0.id == conflictID }) else {
        throw CapoError.notFound
      }
      state.conflicts.removeAll { $0.id == conflictID }
      switch resolution {
      case .keepMine:
        state.songs.removeAll { $0.id == conflict.local.id }
        state.songs.append(conflict.local)
      case .keepTheirs:
        state.songs.removeAll { $0.id == conflict.local.id }
        if let server = conflict.server { state.songs.append(server) }
      case .keepBothAsCopy:
        var copy = conflict.local
        copy.id = UUID()
        copy.title += " (copy)"
        state.songs.removeAll { $0.id == conflict.local.id }
        if let server = conflict.server { state.songs.append(server) }
        state.songs.append(copy)
      }
    }
  }
}

public final class FakeSyncService: SyncService {
  private let subject: ValueSubject<SyncStatus>
  private let reasons = ValueSubject<[SyncReason]>([])

  public init(status: SyncStatus = SyncStatus(phase: .idle, lastSuccessAt: Date())) {
    subject = ValueSubject(status)
  }

  /// Every `syncNow` reason so far, oldest first.
  public var recordedReasons: [SyncReason] { reasons.value }

  public func setStatus(_ status: SyncStatus) { subject.send(status) }
  public func status() -> AsyncStream<SyncStatus> { subject.stream() }

  public func syncNow(reason: SyncReason) async {
    reasons.update { $0.append(reason) }
    subject.update {
      $0.phase = .idle
      $0.lastSuccessAt = Date()
    }
  }

  public func start() async {}
  public func stop() async {}
}

public final class FakeAuthService: AuthService {
  private let subject: ValueSubject<AuthSession?>

  public static let demoSession = AuthSession(
    userID: FakeIDs.user, email: "demo@capo.app", fullName: "Demo User", avatarURL: nil,
    provider: "demo")

  public init(session: AuthSession? = FakeAuthService.demoSession) {
    subject = ValueSubject(session)
  }

  public func sessionStream() -> AsyncStream<AuthSession?> { subject.stream() }
  public func currentSession() async -> AuthSession? { subject.value }
  public func signInWithGoogle() async throws { subject.send(Self.demoSession) }

  public func signIn(email: String, password: String) async throws {
    guard !email.isEmpty, !password.isEmpty else { throw CapoError.invalidInput("credentials") }
    subject.send(
      AuthSession(userID: FakeIDs.user, email: email, fullName: nil, avatarURL: nil, provider: "email"))
  }

  public func signUp(email: String, password: String) async throws {
    try await signIn(email: email, password: password)
  }

  public func signOut() async throws { subject.send(nil) }
  public func handleOpenURL(_ url: URL) async -> Bool { url.scheme == "capo" }
}
