import CapoDesign
import SwiftUI

/// Target chooser for `capoActions.addSongsToPlaylist`: the shell presents this in a sheet with
/// the song ids it received. Lists active setlists in the current context and can create one.
public struct AddToPlaylistView: View {
  let songIDs: [SongID]
  let onFinish: () -> Void

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @State private var playlists: [PlaylistSummary] = []
  @State private var loaded = false
  @State private var showCreate = false
  @State private var errorText: String?

  public init(songIDs: [SongID], onFinish: @escaping () -> Void) {
    self.songIDs = songIDs
    self.onFinish = onFinish
  }

  public var body: some View {
    NavigationStack {
      List {
        Button { showCreate = true } label: {
          Label(PlaylistStrings.newSetlist, systemImage: "plus.circle.fill").frame(minHeight: 44)
        }
        ForEach(playlists) { summary in
          Button { add(to: summary.id) } label: {
            PlaylistRow(summary: summary)
          }
          .buttonStyle(.plain)
        }
        if let errorText { Text(errorText).foregroundStyle(.red).font(.footnote) }
      }
      .navigationTitle(PlaylistStrings.chooseSetlist)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(PlaylistStrings.cancel, action: onFinish)
        }
      }
      .sheet(isPresented: $showCreate) {
        PlaylistFormView(mode: .create) { if let p = $0 { add(to: p.id) } }
      }
      .task(id: context) {
        for await items in services.playlists.playlists(in: context, includeArchived: false) {
          playlists = items
          loaded = true
        }
      }
    }
  }

  private func add(to playlistID: PlaylistID) {
    Task {
      do {
        try await services.playlists.addSongs(songIDs, to: playlistID)
        onFinish()
      } catch { errorText = String(describing: error) }
    }
  }
}
