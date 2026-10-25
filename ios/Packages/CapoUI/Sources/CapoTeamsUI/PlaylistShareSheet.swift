import CapoCore
import CapoDesign
import SwiftUI

/// Resolves a playlist's share code (online) and offers the `/shared/<code>` link. A link only
/// resolves while the playlist is public, so a private playlist is offered a switch instead.
public struct PlaylistShareSheet: View {
  let playlistID: PlaylistID

  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var model = ShareModel()

  public init(playlistID: PlaylistID) { self.playlistID = playlistID }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        if model.needsPublic {
          Toggle(isOn: Binding(get: { false }, set: { if $0 { Task { await makePublic() } } })) {
            VStack(alignment: .leading, spacing: 2) {
              Text(L10n.PlaylistDetail.publicVisibility).font(CapoFont.style(.headline))
              Text(L10n.PlaylistDetail.anyoneWithLink).font(CapoFont.style(.footnote))
                .foregroundStyle(CapoTheme.subtext)
            }
          }
          .tint(CapoTheme.primary)
        } else if let url = model.url {
          Text(url.absoluteString).font(CapoFont.mono(16)).textSelection(.enabled)
            .multilineTextAlignment(.center)
          Text(TeamsStrings.shareHint).font(CapoFont.style(.footnote)).foregroundStyle(CapoTheme.subtext)
          ShareLink(item: url) { Label(TeamsStrings.shareLink, systemImage: "square.and.arrow.up") }
            .buttonStyle(CapoPrimaryButtonStyle())
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
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(CapoTheme.background)
      .tint(CapoTheme.primary)
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
    await model.load(services.sharing, playlists: services.playlists, playlistID: playlistID)
  }

  private func makePublic() async {
    try? await services.playlists.update(id: playlistID, PlaylistPatch(isPublic: true))
    await load()
  }
}

@MainActor @Observable
final class ShareModel: OnlineActionModel {
  var url: URL?
  /// The playlist is private, so a share link would 404 (the web page only serves public playlists).
  var needsPublic = false

  func load(
    _ sharing: any SharingService, playlists: any PlaylistRepository, playlistID: PlaylistID
  ) async {
    message = nil
    for await detail in playlists.playlist(id: playlistID) {
      needsPublic = !(detail?.playlist.isPublic ?? false)
      break
    }
    guard !needsPublic else { return }
    await perform(failure: L10n.Toasts.error) {
      let code = try await sharing.ensureShareCode(playlistID: playlistID)
      url = sharing.shareURL(forCode: code)
    }
  }
}
