import CapoCore
import Foundation

/// The single source of truth behind the local fakes. Every mutation re-emits all observers.
public actor InMemoryBackend {
  public let userID: UserID
  public private(set) var state: BackendState
  private nonisolated let revision = ValueSubject(0)

  public init(userID: UserID = FakeIDs.user, state: BackendState? = nil) {
    self.userID = userID
    self.state = state ?? FakeSeed.demo(userID: userID)
  }

  public func snapshot() -> BackendState { state }

  @discardableResult
  public func mutate<T: Sendable>(_ body: @Sendable (inout BackendState) throws -> T) rethrows -> T {
    let result = try body(&state)
    revision.update { $0 += 1 }
    return result
  }

  public func replace(with newState: BackendState) {
    state = newState
    revision.update { $0 += 1 }
  }

  /// Recomputes `compute` on every change; consecutive duplicates are dropped.
  public nonisolated func observe<T: Sendable & Equatable>(
    _ compute: @escaping @Sendable (BackendState) -> T
  ) -> AsyncStream<T> {
    let changes = revision.stream()
    return AsyncStream { continuation in
      let task = Task {
        var last: T?
        for await _ in changes {
          let value = compute(await self.snapshot())
          if value != last {
            last = value
            continuation.yield(value)
          }
        }
        continuation.finish()
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }
}

// MARK: - Shared queries

extension BackendState {
  public func matches(_ context: AppContext, userID: UserID?, teamID: TeamID?) -> Bool {
    switch context {
    case .all(let me): return (userID == me && teamID == nil) || teamID != nil
    case .personal(let me): return userID == me && teamID == nil
    case .team(let team): return teamID == team
    }
  }

  public func tags(forSong id: SongID) -> [SongTag] {
    let ids = Set(tagAssignments.filter { $0.songID == id }.map(\.tagID))
    return tags.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
  }

  public func listItem(_ song: Song) -> SongListItem {
    SongListItem(
      id: song.id, title: song.title, artist: song.artist, key: song.key, bpm: song.bpm,
      status: song.status, teamID: song.teamID, hasLyrics: !(song.lyrics ?? "").isEmpty,
      tags: tags(forSong: song.id), hasPendingChanges: pendingSongIDs.contains(song.id),
      createdAt: song.createdAt, playCount: playedEntries(of: song.id).count,
      lastPlayed: playedEntries(of: song.id).max())
  }

  /// Played dates of a song: each playlist's own date, else when the playlist was created.
  func playedEntries(of songID: SongID) -> [String] {
    let playlistIDs = Set(playlistEntries.filter { $0.songID == songID }.map(\.playlistID))
    return playlists.filter { playlistIDs.contains($0.id) }.map { $0.date ?? $0.createdAt.raw }
  }

  public func songs(matching query: SongQuery) -> [SongListItem] {
    let terms = Self.fold(query.searchText).split(whereSeparator: \.isWhitespace).map(String.init)
    let filtered = songs.filter { song in
      guard matches(query.context, userID: song.userID, teamID: song.teamID),
        query.statuses.contains(song.status)
      else { return false }
      if let range = query.bpmRange {
        guard let bpm = song.bpm, range.contains(bpm) else { return false }
      }
      if !query.tagIDs.isEmpty {
        let assigned = tagAssignments.filter { $0.songID == song.id }.map(\.tagID)
        guard assigned.contains(where: query.tagIDs.contains) else { return false }
      }
      if !terms.isEmpty {
        let haystack = Self.fold(
          [song.title, song.artist ?? "", song.notes ?? "", song.lyrics ?? ""].joined(separator: " "))
        guard terms.allSatisfy(haystack.contains) else { return false }
      }
      return true
    }
    let sorted: [Song]
    switch query.sort {
    case .recent: sorted = filtered.sorted { $0.createdAt > $1.createdAt }
    case .title, .relevance:
      sorted = filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    case .artist:
      sorted = filtered.sorted {
        ($0.artist ?? "").localizedStandardCompare($1.artist ?? "") == .orderedAscending
      }
    }
    return sorted.map(listItem)
  }

  public func orderedSongIDs(inPlaylist id: PlaylistID) -> [SongID] {
    playlistEntries.filter { $0.playlistID == id }.sorted { $0.position < $1.position }.map(\.songID)
  }

  public func summary(_ playlist: Playlist) -> PlaylistSummary {
    let ids = orderedSongIDs(inPlaylist: playlist.id)
    let offline = ids.allSatisfy { id in songs.first { $0.id == id }?.lyrics != nil }
    return PlaylistSummary(
      playlist: playlist, songCount: ids.count, isPinned: pinnedPlaylistIDs.contains(playlist.id),
      isFullyAvailableOffline: offline)
  }

  public func detail(_ id: PlaylistID) -> PlaylistDetail? {
    guard let playlist = playlists.first(where: { $0.id == id }) else { return nil }
    let items = orderedSongIDs(inPlaylist: id).compactMap { songID in
      songs.first { $0.id == songID }.map(listItem)
    }
    return PlaylistDetail(playlist: playlist, songs: items, isPinned: pinnedPlaylistIDs.contains(id))
  }

  static func fold(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }
}
