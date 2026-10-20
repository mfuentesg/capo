import CapoCore
import CapoDesign
import SwiftUI

/// Invitations addressed to the signed-in user's email; accept or decline.
public struct PendingInvitationsView: View {
  @Environment(\.userServices) private var services
  @State private var model = PendingInvitationsModel()

  public init() {}

  public var body: some View {
    List {
      if model.isOffline { OfflineBanner() }
      ForEach(model.items) { item in
        VStack(alignment: .leading, spacing: 10) {
          VStack(alignment: .leading, spacing: 2) {
            Text(item.teamName).font(.headline)
            if let inviter = item.inviterName {
              Text(L10n.Invitations.invitationFrom(name: inviter))
                .font(.subheadline).foregroundStyle(.secondary)
            }
            Text(TeamsStrings.roleName(item.invitation.role))
              .font(.caption).foregroundStyle(.secondary)
          }
          HStack {
            Button(L10n.Invitations.accept) {
              Task { await model.accept(services.teams, item) }
            }
            .buttonStyle(.borderedProminent)
            Button(TeamsStrings.decline, role: .destructive) {
              Task { await model.decline(services.teams, item) }
            }
            .buttonStyle(.bordered)
          }
          .disabled(model.isBusy)
        }
        .padding(.vertical, 4)
      }
    }
    .overlay {
      if model.loaded && model.items.isEmpty {
        EmptyStateView(
          title: L10n.Invitations.emptyTitle, message: L10n.Invitations.emptyDescription,
          systemImage: "envelope.open")
      }
    }
    .navigationTitle(L10n.Invitations.title)
    .capoToast($model.message)
    .refreshable { await model.load(services.teams) }
    .task { await model.load(services.teams) }
  }
}
