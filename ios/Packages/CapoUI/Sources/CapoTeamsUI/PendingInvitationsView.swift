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
            Text(item.teamName).font(CapoFont.style(.headline)).foregroundStyle(CapoTheme.text)
            if let inviter = item.inviterName {
              Text(L10n.Invitations.invitationFrom(name: inviter))
                .font(CapoFont.style(.subheadline)).foregroundStyle(CapoTheme.subtext)
            }
            RoleBadge(role: item.invitation.role).padding(.top, 4)
          }
          HStack {
            Button(L10n.Invitations.accept) {
              Task { await model.accept(services.teams, item) }
            }
            .buttonStyle(CapoPrimaryButtonStyle())
            Button(TeamsStrings.decline, role: .destructive) {
              Task { await model.decline(services.teams, item) }
            }
            .buttonStyle(CapoSecondaryButtonStyle())
            .foregroundStyle(CapoTheme.destructive)
          }
          .disabled(model.isBusy)
        }
        .padding(.vertical, 6)
        .capoRowBackground()
      }
    }
    .capoList()
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
