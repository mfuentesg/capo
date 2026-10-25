import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

/// Web `transfer-to-team-dialog.tsx`: moves a personal song into one of the user's teams. The change
/// goes through `SongRepository.update` (a `teamID` patch), so it is applied locally at once and
/// queued in the outbox while offline.
///
///     .sheet(isPresented: $showTransfer) {
///       TransferSongToTeamSheet(songID: song.id, title: song.title) { dismissDetail() }
///     }
public struct TransferSongToTeamSheet: View {
  let songID: SongID
  let title: String
  let onTransferred: () -> Void

  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var teams: [TeamWithRole] = []
  @State private var loaded = false
  @State private var selected: TeamID?
  @State private var isBusy = false
  @State private var message: String?

  public init(songID: SongID, title: String, onTransferred: @escaping () -> Void = {}) {
    self.songID = songID
    self.title = title
    self.onTransferred = onTransferred
  }

  public var body: some View {
    NavigationStack {
      Form {
        Section {
          Text(L10n.Songs.transferToTeamDescription(title: title)).capoText(.sm)
          if loaded && teams.isEmpty {
            Text(TeamsStrings.transferNoTeams).capoText(.sm).foregroundStyle(CapoTheme.subtext)
          } else {
            Picker(L10n.Songs.transferToTeamSelectPlaceholder, selection: $selected) {
              Text(L10n.Songs.transferToTeamSelectPlaceholder).tag(TeamID?.none)
              ForEach(teams) { item in
                Label {
                  Text(item.team.name)
                } icon: {
                  CapoIcon.named(item.team.icon, size: 16)
                }
                .tag(Optional(item.id))
              }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
          }
        } footer: {
          Text(L10n.Songs.transferToTeamWarning).capoText(.xs).foregroundStyle(CapoTheme.subtext)
        }
        .capoRowBackground()
      }
      .capoList()
      .navigationTitle(L10n.Songs.transferToTeamTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(TeamsStrings.cancel) { dismiss() }.disabled(isBusy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.Songs.transferToTeamConfirm) { Task { await transfer() } }
            .font(CapoFont.style(.body, weight: .bold))
            .disabled(selected == nil || isBusy)
        }
      }
      .capoToast($message)
      .task {
        for await all in services.teams.teams() {
          teams = Self.targets(all)
          loaded = true
        }
      }
    }
    .presentationDetents([.medium])
  }

  /// Viewers cannot add content to a team, so they are not offered as a destination.
  nonisolated static func targets(_ teams: [TeamWithRole]) -> [TeamWithRole] {
    teams.filter { $0.role.canEditContent }
  }

  private func transfer() async {
    guard let selected else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      try await services.songs.update(id: songID, SongPatch(teamID: selected))
      dismiss()
      onTransferred()
    } catch {
      message = L10n.Toasts.error
    }
  }
}
