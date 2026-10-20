import CapoDesign
import SwiftUI

/// Chooses a setlist for `capoActions.addSongsToPlaylist`.
struct AddToSetlistSheet: View {
  let songIDs: [SongID]
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var playlists: [PlaylistSummary] = []
  @State private var loaded = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      Group {
        if loaded && playlists.isEmpty {
          EmptyStateView(
            title: String(localized: "ios.shell.addToSetlist.empty", defaultValue: "No setlists yet", bundle: .capoDesign),  // TODO(i18n)
            message: String(localized: "ios.shell.addToSetlist.emptyHint", defaultValue: "Create a setlist first, then add songs to it.", bundle: .capoDesign),  // TODO(i18n)
            systemImage: "music.note.list")
        } else {
          List(playlists) { summary in
            Button {
              add(to: summary.playlist.id)
            } label: {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(summary.playlist.name).font(.body.weight(.medium))
                  Text("\(summary.songCount)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(.tint)
              }
              .frame(minHeight: CapoMetrics.minTouchTarget)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
        }
      }
      .navigationTitle(String(localized: "ios.shell.addToSetlist.title", defaultValue: "Add to setlist", bundle: .capoDesign))  // TODO(i18n)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "ios.shell.cancel", defaultValue: "Cancel", bundle: .capoDesign)) { dismiss() }  // TODO(i18n)
        }
      }
      .capoToast($errorMessage)
    }
    .presentationDetents([.medium, .large])
    .task(id: context) {
      for await list in services.playlists.playlists(in: context, includeArchived: false) {
        playlists = list
        loaded = true
      }
    }
  }

  private func add(to playlistID: PlaylistID) {
    Task {
      do {
        try await services.playlists.addSongs(songIDs, to: playlistID)
        dismiss()
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
}
