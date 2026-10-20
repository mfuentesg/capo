import CapoDesign
import SwiftUI

/// Active / archived setlists with pin and offline-ready badges.
public struct PlaylistsView: View {
  @Binding var selection: PlaylistID?
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.currentTeamRole) private var role
  @State private var all: [PlaylistSummary] = []
  @State private var loaded = false
  @State private var showArchived = false
  @State private var showCreate = false
  @State private var pendingDelete: PlaylistSummary?

  public init(selection: Binding<PlaylistID?>) { _selection = selection }

  private var canEdit: Bool { role?.canEditContent ?? true }
  private var visible: [PlaylistSummary] {
    all.filter { ($0.playlist.archivedAt != nil) == showArchived }
  }

  public var body: some View {
    List(selection: $selection) {
      Section {
        Picker("", selection: $showArchived) {
          Text(PlaylistStrings.active).tag(false)
          Text(PlaylistStrings.archived).tag(true)
        }
        .pickerStyle(.segmented)
        .listRowBackground(Color.clear)
      }
      ForEach(visible) { summary in
        PlaylistRow(summary: summary)
          .tag(summary.id)
          .swipeActions(edge: .trailing) {
            if canEdit {
              Button(PlaylistStrings.delete, role: .destructive) { pendingDelete = summary }
              Button {
                Task { try? await services.playlists.setArchived(id: summary.id, !showArchived) }
              } label: {
                Text(showArchived ? PlaylistStrings.unarchive : PlaylistStrings.archive)
              }
              .tint(.orange)
            }
          }
      }
    }
    .overlay {
      if loaded && visible.isEmpty {
        EmptyStateView(
          title: showArchived ? PlaylistStrings.emptyArchived : PlaylistStrings.emptyTitle,
          message: showArchived ? nil : PlaylistStrings.emptyMessage,
          systemImage: "music.note.list")
      }
    }
    .navigationTitle(PlaylistStrings.title)
    .toolbar {
      if canEdit {
        ToolbarItem(placement: .topBarTrailing) {
          Button { showCreate = true } label: {
            Label(PlaylistStrings.newSetlist, systemImage: "plus")
          }
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
}

struct PlaylistRow: View {
  let summary: PlaylistSummary

  var body: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 4) {
        Text(summary.playlist.name).font(.headline).lineLimit(1)
        HStack(spacing: 6) {
          if let date = PlaylistDate.display(summary.playlist.date) { Text(date) }
          Text(PlaylistStrings.songCount(summary.songCount))
        }
        .font(.subheadline).foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      if summary.isPinned {
        Image(systemName: summary.isFullyAvailableOffline ? "checkmark.circle.fill" : "pin.fill")
          .foregroundStyle(summary.isFullyAvailableOffline ? Color.green : Color.secondary)
          .accessibilityLabel(
            summary.isFullyAvailableOffline ? PlaylistStrings.offlineReady : PlaylistStrings.pinned)
      }
    }
    .frame(minHeight: 56)
    .contentShape(Rectangle())
  }
}
