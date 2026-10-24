import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

/// Teams the user belongs to, with their role; tap for members and invitations.
public struct TeamsView: View {
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var appContext
  @State private var model = TeamsModel()
  @State private var showCreate = false
  @State private var iconTeam: Team?
  @State private var iconSelection: String?
  @State private var confirm: TeamWithRole?

  public init() {}

  private let columns = [GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)]

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        if model.isOffline { OfflineBanner() }
        search
        content
      }
      .padding(24)
    }
    .background(CapoTheme.background)
    .navigationTitle(TeamsStrings.title)
    .navigationDestination(for: TeamWithRole.self) { item in
      TeamDetailView(team: item.team, role: item.role)
    }
    .navigationDestination(for: InvitationsRoute.self) { _ in PendingInvitationsView() }
    .sheet(isPresented: $showCreate) { CreateTeamSheet(model: model) }
    .sheet(item: $iconTeam) { team in
      TeamIconPickerSheet(
        icon: Binding(get: { iconSelection }, set: { iconSelection = $0 })
      )
      .onDisappear {
        if let icon = iconSelection, icon != team.icon {
          Task { await model.setIcon(services.teams, team: team, icon: icon) }
        }
      }
    }
    .confirmationDialog(
      confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
      titleVisibility: .visible
    ) {
      if let item = confirm {
        Button(item.role == .owner ? L10n.Teams.deleteTeam : L10n.Teams.leaveShort, role: .destructive) {
          Task {
            if item.role == .owner {
              await model.delete(services.teams, teamID: item.id)
            } else {
              await model.leave(services.teams, teamID: item.id)
            }
          }
        }
      }
    }
    .capoToast($model.message)
    .refreshable { await model.loadCounts(services.teams) }
    .task {
      for await teams in services.teams.teams() {
        model.teams = teams
        model.loaded = true
        await model.loadCounts(services.teams)
      }
    }
  }

  private var confirmTitle: String {
    guard let item = confirm else { return "" }
    return item.role == .owner
      ? L10n.Teams.deleteTeamConfirmDescription(name: item.team.name)
      : L10n.Teams.leaveTeamConfirm(name: item.team.name)
  }

  // MARK: Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.Teams.manageTeams).capoText(.base).foregroundStyle(CapoTheme.subtext)
      HStack(spacing: 8) {
        NavigationLink(value: InvitationsRoute()) {
          HStack(spacing: 8) {
            CapoIcon(.mail, size: 16)
            Text(L10n.Nav.invitations).lineLimit(1)
            if model.pendingInvitationCount > 0 {
              Text("\(model.pendingInvitationCount)")
                .capoText(.px11)
                .foregroundStyle(CapoTheme.primaryForeground)
                .frame(minWidth: 18, minHeight: 18)
                .background(CapoTheme.primary, in: Capsule())
            }
          }
        }
        .buttonStyle(CapoSecondaryButtonStyle())
        Button { showCreate = true } label: {
          HStack(spacing: 8) {
            CapoIcon(.plus, size: 16)
            Text(L10n.Teams.createTeam).lineLimit(1)
          }
        }
        .buttonStyle(CapoPrimaryButtonStyle())
      }
    }
  }

  private var search: some View {
    HStack(spacing: 8) {
      CapoIcon(.search, size: 16).foregroundStyle(CapoTheme.subtext)
      TextField(TeamsStrings.searchTeams, text: $model.search)
        .capoText(.sm)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      if !model.search.isEmpty {
        Button { model.search = "" } label: {
          CapoIcon(.x, size: 16).foregroundStyle(CapoTheme.subtext).frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 44)
    .background(CapoTheme.muted.opacity(0.5), in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input))
  }

  @ViewBuilder
  private var content: some View {
    let teams = model.filtered
    if model.loaded && teams.isEmpty {
      EmptyStateView(
        title: L10n.Teams.noTeamsFound,
        message: model.teams.isEmpty ? L10n.Teams.manageTeams : TeamsStrings.noTeamMatches,
        systemImage: "person.2")
    } else {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(teams) { item in
          TeamCard(
            item: item, isActive: appContext.teamID == item.id, memberCount: model.memberCounts[item.id],
            onIconTap: {
              iconSelection = item.team.icon
              iconTeam = item.team
            },
            onLeaveOrDelete: { confirm = item })
        }
      }
    }
  }
}

struct InvitationsRoute: Hashable {}

struct OfflineBanner: View {
  var body: some View {
    HStack(spacing: 8) {
      CapoIcon(.alertCircle, size: 16)
      Text(TeamsStrings.offline)
    }
    .capoText(.sm)
    .foregroundStyle(CapoTheme.subtext)
  }
}

struct CreateTeamSheet: View {
  let model: TeamsModel
  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var icon: String? = TeamIconCatalog.defaultName
  @State private var isPublic = false

  var body: some View {
    NavigationStack {
      Form {
        if model.isOffline { OfflineBanner() }
        Section {
          TextField(L10n.Teams.teamNamePlaceholder, text: $name)
            .textInputAutocapitalization(.words)
          HStack {
            Text(TeamsStrings.iconPickerTitle).capoText(.sm)
            Spacer()
            TeamIconPickerButton(icon: $icon)
          }
          Toggle(isOn: $isPublic) {
            VStack(alignment: .leading, spacing: 2) {
              Text(L10n.Teams.publicTeam)
              Text(L10n.Teams.publicTeamDescription).capoText(.xs).foregroundStyle(CapoTheme.subtext)
            }
          }
        } header: {
          Text(L10n.Teams.teamInformation.uppercased()).capoSectionHeader()
        }
        .capoRowBackground()
      }
      .capoList()
      .navigationTitle(L10n.Teams.createNewTeam)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(TeamsStrings.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.Teams.createTeam) {
            Task {
              if await model.create(services.teams, name: name, icon: icon, isPublic: isPublic) {
                dismiss()
              }
            }
          }
          .font(CapoFont.style(.body, weight: .bold))
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || model.isBusy)
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
