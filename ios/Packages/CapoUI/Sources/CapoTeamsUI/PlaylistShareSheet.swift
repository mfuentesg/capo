import CapoCore
import CapoDesign
import SwiftUI

/// Resolves a playlist's share code (online) and offers the `/playlists/<code>` link.
public struct PlaylistShareSheet: View {
  let playlistID: PlaylistID

  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var model = ShareModel()

  public init(playlistID: PlaylistID) { self.playlistID = playlistID }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        if let url = model.url {
          Text(url.absoluteString).font(.callout.monospaced()).textSelection(.enabled)
            .multilineTextAlignment(.center)
          Text(TeamsStrings.shareHint).font(.footnote).foregroundStyle(.secondary)
          ShareLink(item: url) { Label(TeamsStrings.shareLink, systemImage: "square.and.arrow.up") }
            .buttonStyle(.borderedProminent)
        } else if model.isOffline {
          Label(TeamsStrings.offline, systemImage: "wifi.slash").foregroundStyle(.secondary)
          Button(TeamsStrings.retry) { Task { await load() } }
        } else if model.message != nil {
          Button(TeamsStrings.retry) { Task { await load() } }
        } else {
          ProgressView()
        }
      }
      .padding()
      .navigationTitle(TeamsStrings.shareTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button(L10n.Common.done) { dismiss() } }
      }
      .capoToast($model.message)
    }
    .presentationDetents([.medium])
    .task { await load() }
  }

  private func load() async {
    await model.load(services.sharing, playlistID: playlistID)
  }
}

@MainActor @Observable
final class ShareModel: OnlineActionModel {
  var url: URL?

  func load(_ sharing: any SharingService, playlistID: PlaylistID) async {
    message = nil
    await perform(failure: L10n.Toasts.error) {
      let code = try await sharing.ensureShareCode(playlistID: playlistID)
      url = sharing.shareURL(forCode: code)
    }
  }
}
