import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

/// Invitations addressed to the signed-in user's email; accept or decline.
public struct PendingInvitationsView: View {
  @Environment(\.userServices) private var services
  @State private var model = PendingInvitationsModel()

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if model.isOffline { OfflineBanner() }
        Text(L10n.Invitations.pendingDescription).capoText(.sm).foregroundStyle(CapoTheme.subtext)
        ForEach(model.items) { item in
          VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
              CapoIcon(.mail, size: 20)
                .foregroundStyle(CapoTheme.text)
                .frame(width: 40, height: 40)
                .background(CapoTheme.primary.opacity(0.1), in: Circle())
              VStack(alignment: .leading, spacing: 2) {
                Text(item.teamName).capoText(.lg, weight: .semibold, tracking: -0.025)
                if let inviter = item.inviterName {
                  Text(L10n.Invitations.invitationFrom(name: inviter))
                    .capoText(.sm).foregroundStyle(CapoTheme.subtext)
                }
              }
              Spacer(minLength: 8)
              RoleBadge(role: item.invitation.role)
            }
            HStack(spacing: 4) {
              CapoIcon(.clock, size: 12)
              Text(L10n.Invitations.expires(date: TeamDetailView.dateText(item.invitation.expiresAt)))
            }
            .capoText(.xs)
            .foregroundStyle(
              TeamDetailModel.isExpired(item.invitation) ? CapoTheme.destructive : CapoTheme.subtext)
            HStack(spacing: 8) {
              Button(L10n.Invitations.accept) {
                Task { await model.accept(services.teams, item) }
              }
              .buttonStyle(CapoPrimaryButtonStyle())
              Button(TeamsStrings.decline) {
                Task { await model.decline(services.teams, item) }
              }
              .buttonStyle(CapoSecondaryButtonStyle())
            }
            .disabled(model.isBusy)
          }
          .teamSurface()
          .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        }
      }
      .padding(24)
    }
    .background(CapoTheme.background)
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
