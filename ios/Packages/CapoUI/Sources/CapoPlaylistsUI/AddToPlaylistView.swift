import CapoDesign
import CapoIcons
import SwiftUI

/// The web's draft-cart dialog (`playlist-draft.tsx`), presented by the shell for
/// `capoActions.addSongsToPlaylist`: the selected songs (removable), a "new playlist" or existing
/// playlist target, a name for new ones, Clear and "Add N songs". It edits the shared
/// `PlaylistDraftStore`, so closing it keeps the selection; the songs can be dragged into order.
public struct AddToPlaylistView: View {
  let onFinish: () -> Void

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.creationContext) private var creationContext
  @Environment(\.playlistDraft) private var draft
  @State private var titles: [SongID: (title: String, artist: String?)] = [:]
  @State private var songTeams: [SongID: TeamID?] = [:]
  @State private var newBucket: AppContext?
  @State private var playlists: [PlaylistSummary] = []
  @State private var target: Target?
  @State private var newName = ""
  @State private var isWorking = false
  @State private var toast: String?
  @FocusState private var nameFocused: Bool

  enum Target: Hashable { case new, existing(PlaylistID) }

  public init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

  private var ids: [SongID] { draft.ids }

  /// Team of the playlist the songs would land in (nil = personal); unknown until a target is picked.
  private var targetTeam: TeamID?? {
    switch target {
    case nil:
      return nil
    case .new:
      return .some((newBucket ?? creationContext).teamID)
    case .existing(let id):
      guard let summary = playlists.first(where: { $0.id == id }) else { return nil }
      return .some(summary.playlist.teamID)
    }
  }

  /// Songs from another bucket than the target playlist (teammates could not read them).
  private var mismatched: Set<SongID> {
    guard let team = targetTeam else { return [] }
    return Set(PlaylistLogic.crossBucket(ids, teamOf: songTeams, target: team))
  }

  private var canAdd: Bool {
    guard !ids.isEmpty, !isWorking, mismatched.isEmpty, let target else { return false }
    if target == .new { return !newName.trimmingCharacters(in: .whitespaces).isEmpty }
    return true
  }

  public var body: some View {
    NavigationStack {
      List {
        header.listRow()
        songList
        targetPicker.listRow()
        if target == .new {
          nameField.listRow()
          BucketPicker(
            selection: Binding(get: { newBucket ?? creationContext }, set: { newBucket = $0 }),
            label: L10n.Playlists.bucket
          ).listRow()
        }
        if !mismatched.isEmpty {
          Text(L10n.Ios.Playlists.crossBucket).capoText(.xs)
            .foregroundStyle(CapoTheme.destructive).listRow()
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .environment(\.editMode, .constant(.active))  // drag handles to sort the songs
      .background(CapoTheme.background)
      .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(PlaylistStrings.cancel, action: onFinish)
        }
      }
      .capoToast($toast)
      .tint(CapoTheme.primary)
      .task(id: context) {
        for await items in services.playlists.playlists(in: context, includeArchived: false) {
          playlists = items
        }
      }
      .task(id: draft.ids) { await loadTitles() }
    }
  }

  // MARK: Pieces

  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        CapoIcon(.listMusic, size: 20).foregroundStyle(CapoTheme.accentPlaylists)
        Text(L10n.PlaylistDraft.addToPlaylist)
          .capoText(.lg, weight: .semibold).accessibilityAddTraits(.isHeader)
      }
      Text("\(ids.count) \(L10n.PlaylistDraft.songsSelected)")
        .capoText(.sm).foregroundStyle(CapoTheme.mutedForeground).monospacedDigit()
    }
  }

  private var songList: some View {
    ForEach(ids, id: \.self) { id in
      HStack(spacing: 8) {
        CapoIcon(.music2, size: 12).foregroundStyle(CapoTheme.mutedForeground)
        VStack(alignment: .leading, spacing: 0) {
          Text(titles[id]?.title ?? "…").capoText(.sm, weight: .medium).lineLimit(1)
          if mismatched.contains(id) {
            Text(L10n.Ios.Playlists.otherBucket).capoText(.xs)
              .foregroundStyle(CapoTheme.destructive).lineLimit(1)
          } else if let artist = titles[id]?.artist, !artist.isEmpty {
            Text(artist).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(1)
          }
        }
        Spacer(minLength: 8)
        Button { withAnimation(.snappy(duration: 0.2)) { draft.remove(id) } } label: {
          CapoIcon(.x, size: 16).foregroundStyle(CapoTheme.mutedForeground)
            .frame(width: 36, height: 36).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PlaylistStrings.remove)
      }
      .padding(.leading, 12)
      .padding(.trailing, 4)
      .frame(minHeight: 44)
      .playlistCard()
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.xl, style: .continuous)
          .strokeBorder(CapoTheme.destructive, lineWidth: mismatched.contains(id) ? 1 : 0))
      .deleteDisabled(true)
      .listRow()
    }
    .onMove { draft.move(from: $0, to: $1) }
  }

  private var targetPicker: some View {
    Menu {
      Button(L10n.PlaylistDraft.selectNewPlaylist) {
        target = .new
        nameFocused = true
      }
      if !playlists.isEmpty { Divider() }
      ForEach(playlists) { summary in
        Button(summary.playlist.name) { target = .existing(summary.id) }
      }
    } label: {
      HStack(spacing: 8) {
        Text(targetLabel)
          .capoText(.sm)
          .foregroundStyle(target == nil ? CapoTheme.mutedForeground : CapoTheme.foreground)
          .lineLimit(1)
        Spacer(minLength: 8)
        CapoIcon(.chevronDown, size: 16).foregroundStyle(CapoTheme.mutedForeground)
      }
      .padding(.horizontal, 12)
      .frame(minHeight: 44)
      .background(
        CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
          .strokeBorder(CapoTheme.input, lineWidth: 1))
    }
    .accessibilityLabel(L10n.Playlists.selectPlaylist)
  }

  private var targetLabel: String {
    switch target {
    case nil: L10n.PlaylistDraft.selectPlaylist
    case .new: L10n.PlaylistDraft.selectNewPlaylist
    case .existing(let id): playlists.first { $0.id == id }?.playlist.name ?? L10n.PlaylistDraft.selectPlaylist
    }
  }

  private var nameField: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(L10n.Playlists.playlistName).capoText(.sm, weight: .medium)
      TextField(L10n.Playlists.playlistNamePlaceholder, text: $newName)
        .focused($nameFocused)
        .capoText(.sm)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(
          CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
            .strokeBorder(CapoTheme.input, lineWidth: 1))
        .submitLabel(.done)
    }
  }

  private var actionBar: some View {
    HStack(spacing: 12) {
      Button(L10n.PlaylistDraft.clearButton) {
        draft.clear()
        onFinish()
      }
      .buttonStyle(CapoSecondaryButtonStyle())
      Button(action: add) {
        Text(L10n.PlaylistDraft.addButton(count: String(ids.count))).frame(maxWidth: .infinity)
      }
      .buttonStyle(CapoPrimaryButtonStyle())
      .disabled(!canAdd)
    }
    .padding(16)
    .background(CapoTheme.background)
    .overlay(alignment: .top) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
  }

  // MARK: Actions

  private func loadTitles() async {
    for id in draft.ids where titles[id] == nil {
      if let song = try? await services.songs.fetchSong(id: id) {
        titles[id] = (song.title, song.artist)
        songTeams[id] = .some(song.teamID)
      }
    }
  }

  private func add() {
    guard let target else { return }
    isWorking = true
    Task {
      defer { isWorking = false }
      do {
        switch target {
        case .new:
          _ = try await services.playlists.create(
            PlaylistDraft(name: newName.trimmingCharacters(in: .whitespaces), songIDs: ids),
            in: newBucket ?? creationContext)
          await finish(L10n.Toasts.playlistCreated)
        case .existing(let playlistID):
          var existing: [SongID] = []
          for await detail in services.playlists.playlist(id: playlistID) {
            existing = detail?.songs.map(\.id) ?? []
            break
          }
          let fresh = PlaylistLogic.newSongs(adding: ids, to: existing)
          guard !fresh.isEmpty else { return await finish(L10n.Toasts.songsAlreadyInPlaylist) }
          try await services.playlists.addSongs(fresh, to: playlistID)
          await finish(L10n.Toasts.songsAdded)
        }
      } catch { toast = String(describing: error) }
    }
  }

  private func finish(_ message: String) async {
    draft.clear()
    toast = message
    try? await Task.sleep(for: .milliseconds(900))
    onFinish()
  }
}

private extension View {
  /// Plain, separator-free list row so the cards keep their own chrome.
  func listRow() -> some View {
    listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
  }
}
