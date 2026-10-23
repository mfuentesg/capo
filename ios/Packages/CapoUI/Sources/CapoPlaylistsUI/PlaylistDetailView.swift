import CapoDesign
import CapoLibraryUI
import SwiftUI

/// One setlist: ordered songs with drag reorder, add/remove, details, archive, delete, pin, share.
public struct PlaylistDetailView: View {
  let playlistID: PlaylistID
  @Environment(\.userServices) private var services
  @Environment(\.currentTeamRole) private var role
  @Environment(\.capoActions) private var actions
  @State private var detail: PlaylistDetail?
  @State private var songs: [SongListItem] = []
  @State private var loaded = false
  @State private var isOffline = false
  @State private var editMode: EditMode = .inactive
  @State private var showPicker = false
  @State private var showForm = false
  @State private var showShare = false
  @State private var confirmDelete = false

  public init(playlistID: PlaylistID) { self.playlistID = playlistID }

  private var canEdit: Bool { role?.canEditContent ?? true }

  public var body: some View {
    Group {
      if let detail {
        List {
          Section {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
              Button { actions.performSetlist(playlistID, index) } label: {
                SetlistSongRow(index: index, song: song)
              }
              .buttonStyle(.plain)
              .capoCardRow()
            }
            .onMove { move(from: $0, to: $1) }
            .onDelete { delete(at: $0) }
            .moveDisabled(!canEdit)
            .deleteDisabled(!canEdit)
          } header: {
            header(detail.playlist)
          }
        }
        .capoList()
        .overlay {
          if songs.isEmpty {
            EmptyStateView(
              title: PlaylistStrings.emptySongsTitle, message: PlaylistStrings.emptySongsMessage,
              systemImage: "music.note.list")
          }
        }
        .navigationTitle(detail.playlist.name)
        .toolbar { toolbar(detail) }
        .environment(\.editMode, $editMode)
      } else if loaded {
        EmptyStateView(title: PlaylistStrings.notFound, message: nil, systemImage: "questionmark.folder")
      } else {
        ProgressView()
      }
    }
    .sheet(isPresented: $showPicker) {
      SongPickerView(excluding: Set(songs.map(\.id))) { ids in
        Task { try? await services.playlists.addSongs(ids, to: playlistID) }
      }
    }
    .sheet(isPresented: $showForm) {
      if let playlist = detail?.playlist { PlaylistFormView(mode: .edit(playlist)) }
    }
    .sheet(isPresented: $showShare) { ShareSheetView(playlistID: playlistID) }
    .confirmationDialog(
      detail.map { PlaylistStrings.deleteConfirm($0.playlist.name) } ?? "",
      isPresented: $confirmDelete, titleVisibility: .visible
    ) {
      Button(PlaylistStrings.delete, role: .destructive) {
        Task { try? await services.playlists.delete(id: playlistID) }
      }
    }
    .task(id: playlistID) {
      for await value in services.playlists.playlist(id: playlistID) {
        detail = value
        songs = value?.songs ?? []
        loaded = true
      }
    }
    .task {
      for await status in services.sync.status() { isOffline = status.phase == .offline }
    }
  }

  @ViewBuilder private func header(_ playlist: Playlist) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      if let date = PlaylistDate.display(playlist.date) { Text(date) }
      if let text = playlist.description, !text.isEmpty { Text(text) }
    }
    .font(CapoFont.style(.subheadline)).foregroundStyle(CapoTheme.subtext).textCase(nil)
  }

  @ToolbarContentBuilder private func toolbar(_ detail: PlaylistDetail) -> some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
      Button { actions.performSetlist(playlistID, 0) } label: {
        Label(PlaylistStrings.perform, systemImage: "play.fill")
      }
      .disabled(songs.isEmpty)
    }
    if canEdit {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showPicker = true } label: {
          Label(PlaylistStrings.addSongs, systemImage: "plus")
        }
      }
    }
    ToolbarItem(placement: .topBarTrailing) {
      Menu {
        if canEdit {
          Button(editMode.isEditing ? PlaylistStrings.done : PlaylistStrings.reorder,
            systemImage: "arrow.up.arrow.down") {
            withAnimation { editMode = editMode.isEditing ? .inactive : .active }
          }
          .disabled(songs.count < 2)
          Button(PlaylistStrings.editDetails, systemImage: "pencil") { showForm = true }
        }
        Button(
          detail.isPinned ? PlaylistStrings.unpin : PlaylistStrings.pin,
          systemImage: detail.isPinned ? "pin.slash" : "pin"
        ) {
          Task { try? await services.playlists.setPinned(!detail.isPinned, playlistID: playlistID) }
        }
        Button(PlaylistStrings.share, systemImage: "square.and.arrow.up") {
          if let share = actions.sharePlaylist { share(playlistID) } else { showShare = true }
        }
          .disabled(isOffline)
        if canEdit {
          Button(
            detail.playlist.archivedAt == nil ? PlaylistStrings.archive : PlaylistStrings.unarchive,
            systemImage: "archivebox"
          ) {
            Task {
              try? await services.playlists.setArchived(
                id: playlistID, detail.playlist.archivedAt == nil)
            }
          }
          Button(PlaylistStrings.delete, systemImage: "trash", role: .destructive) {
            confirmDelete = true
          }
        }
      } label: {
        Label(PlaylistStrings.title, systemImage: "ellipsis.circle")
      }
    }
  }

  private func move(from source: IndexSet, to destination: Int) {
    songs = SetlistMath.move(songs, from: source, to: destination)
    let ids = songs.map(\.id)
    Task { try? await services.playlists.reorder(playlistID: playlistID, songIDs: ids) }
  }

  private func delete(at offsets: IndexSet) {
    let removed = offsets.map { songs[$0].id }
    songs.remove(atOffsets: offsets)
    Task {
      for id in removed { try? await services.playlists.removeSong(id, from: playlistID) }
    }
  }
}

struct SetlistSongRow: View {
  let index: Int
  let song: SongListItem

  var body: some View {
    HStack(spacing: 12) {
      Text("\(index + 1)").font(CapoFont.style(.subheadline, weight: .semibold).monospacedDigit())
        .foregroundStyle(CapoTheme.subtext)
        .frame(minWidth: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(song.title).font(CapoFont.style(.headline)).foregroundStyle(CapoTheme.text).lineLimit(1)
        if let artist = song.artist, !artist.isEmpty {
          Text(artist).font(CapoFont.style(.subheadline)).foregroundStyle(CapoTheme.subtext).lineLimit(1)
        }
      }
      Spacer(minLength: 8)
      if let key = song.key, !key.isEmpty {
        KeyBadge(key)
      }
    }
    .frame(minHeight: 56)
    .contentShape(Rectangle())
  }
}

/// Online only: ensures a share code, then offers the public link.
struct ShareSheetView: View {
  let playlistID: PlaylistID
  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var url: URL?
  @State private var errorText: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        if let url {
          Text(url.absoluteString).font(CapoFont.style(.callout)).textSelection(.enabled).multilineTextAlignment(.center)
          ShareLink(item: url) { Label(PlaylistStrings.share, systemImage: "square.and.arrow.up") }
            .buttonStyle(CapoPrimaryButtonStyle())
          Button(PlaylistStrings.copyLink, systemImage: "doc.on.doc") {
            UIPasteboard.general.url = url
          }
        } else if let errorText {
          Text(errorText).foregroundStyle(CapoTheme.destructive)
        } else {
          ProgressView()
        }
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(CapoTheme.background)
      .tint(CapoTheme.primary)
      .navigationTitle(PlaylistStrings.share)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button(PlaylistStrings.done) { dismiss() } }
      }
      .task {
        do {
          let code = try await services.sharing.ensureShareCode(playlistID: playlistID)
          url = services.sharing.shareURL(forCode: code)
        } catch CapoError.offlineUnavailable {
          errorText = PlaylistStrings.shareOffline
        } catch { errorText = String(describing: error) }
      }
    }
  }
}
