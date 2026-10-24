import CapoDesign
import CapoIcons
import SwiftUI

/// Web playlists list: "Playlists · N" with a Create pill, client-side search, a visibility filter,
/// card rows (archived ones dimmed) and swipe to delete.
public struct PlaylistsView: View {
  @Binding var selection: PlaylistID?
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.currentTeamRole) private var role
  @State private var all: [PlaylistSummary] = []
  @State private var loaded = false
  @State private var query = ""
  @State private var visibility = PlaylistLogic.Visibility.all
  @State private var showCreate = false
  @State private var pendingDelete: PlaylistSummary?

  public init(selection: Binding<PlaylistID?>) { _selection = selection }

  private var canEdit: Bool { role?.canEditContent ?? true }
  private var visible: [PlaylistSummary] {
    PlaylistLogic.visible(all, query: query, visibility: visibility)
  }

  public var body: some View {
    List(selection: $selection) {
      ForEach(visible) { summary in
        PlaylistRow(
          summary: summary, isSelected: selection == summary.id,
          onToggleArchive: canEdit ? { toggleArchive(summary) } : nil
        )
        .tag(summary.id)
        .capoCardRow()
        .swipeActions(edge: .trailing) {
          if canEdit {
            Button(PlaylistStrings.delete, role: .destructive) { pendingDelete = summary }
          }
        }
      }
    }
    .capoList()
    .overlay {
      if loaded && visible.isEmpty {
        EmptyStateView(
          title: all.isEmpty ? PlaylistStrings.emptyTitle : L10n.Playlists.noPlaylists,
          message: all.isEmpty ? PlaylistStrings.emptyMessage : nil,
          systemImage: "music.note.list")
      }
    }
    .searchable(text: $query, prompt: L10n.Playlists.searchPlaceholder)
    .navigationTitle(loaded ? "\(PlaylistStrings.title) · \(visible.count)" : PlaylistStrings.title)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) { filterMenu }
      if canEdit {
        ToolbarItem(placement: .topBarTrailing) {
          Button { showCreate = true } label: {
            HStack(spacing: 6) {
              CapoIcon(.plus, size: 16)
              Text(L10n.Playlists.createPlaylist).lineLimit(1)
            }
          }
          .buttonStyle(CapoPrimaryButtonStyle(size: .small))
        }
      }
    }
    .refreshable { await services.sync.syncNow(reason: .manual) }
    .sheet(isPresented: $showCreate) {
      PlaylistFormView(mode: .create) { if let p = $0 { selection = p.id } }
    }
    .confirmationDialog(
      pendingDelete.map { PlaylistStrings.deleteConfirm($0.playlist.name) } ?? "",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible
    ) {
      Button(PlaylistStrings.delete, role: .destructive) {
        if let target = pendingDelete {
          if selection == target.id { selection = nil }
          Task { try? await services.playlists.delete(id: target.id) }
        }
        pendingDelete = nil
      }
    }
    .task(id: context) {
      for await items in services.playlists.playlists(in: context, includeArchived: true) {
        all = items
        loaded = true
      }
    }
  }

  private var filterMenu: some View {
    Menu {
      Picker(L10n.Filters.visibility, selection: $visibility) {
        Text(L10n.Songs.all).tag(PlaylistLogic.Visibility.all)
        Text(L10n.Filters.public).tag(PlaylistLogic.Visibility.public)
        Text(L10n.Filters.private).tag(PlaylistLogic.Visibility.private)
      }
    } label: {
      CapoIcon(.settings2, size: 16)
        .foregroundStyle(CapoTheme.foreground)
        .frame(width: 36, height: 36)
        .overlay(alignment: .topTrailing) {
          if visibility != .all { PingDotMarker() }
        }
    }
    .accessibilityLabel(L10n.Songs.filters)
  }

  private func toggleArchive(_ summary: PlaylistSummary) {
    let archive = summary.playlist.archivedAt == nil
    Task { try? await services.playlists.setArchived(id: summary.id, archive) }
  }
}

/// Filled 8 px dot that marks an active filter.
private struct PingDotMarker: View {
  var body: some View {
    Circle().fill(CapoTheme.primary).frame(width: 8, height: 8)
      .offset(x: -2, y: 4).accessibilityHidden(true)
  }
}
