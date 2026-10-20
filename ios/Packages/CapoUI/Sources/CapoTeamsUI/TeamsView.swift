import CapoCore
import CapoDesign
import SwiftUI

/// Teams the user belongs to, with their role; tap for members and invitations.
public struct TeamsView: View {
  @Environment(\.userServices) private var services
  @State private var model = TeamsModel()
  @State private var showCreate = false

  public init() {}

  public var body: some View {
    List {
      if model.isOffline { OfflineBanner() }
      ForEach(model.teams) { item in
        NavigationLink {
          TeamDetailView(team: item.team, role: item.role)
        } label: {
          TeamRowView(item: item)
        }
      }
    }
    .overlay {
      if model.loaded && model.teams.isEmpty {
        EmptyStateView(
          title: L10n.Teams.noTeamsFound, message: L10n.Teams.manageTeams,
          systemImage: "person.3")
      }
    }
    .navigationTitle(TeamsStrings.title)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showCreate = true } label: {
          Label(L10n.Teams.createTeam, systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $showCreate) {
      CreateTeamSheet(model: model)
    }
    .capoToast($model.message)
    .task {
      for await teams in services.teams.teams() {
        model.teams = teams
        model.loaded = true
      }
    }
  }
}

struct TeamRowView: View {
  let item: TeamWithRole

  var body: some View {
    HStack(spacing: 12) {
      Text(item.team.icon ?? "👥").font(.title2).frame(width: 36)
      VStack(alignment: .leading, spacing: 2) {
        Text(item.team.name).font(.headline).lineLimit(1)
        Text(TeamsStrings.roleName(item.role)).font(.subheadline).foregroundStyle(.secondary)
      }
    }
    .frame(minHeight: 48)
    .accessibilityElement(children: .combine)
  }
}

struct OfflineBanner: View {
  var body: some View {
    Label(TeamsStrings.offline, systemImage: "wifi.slash")
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .listRowBackground(Color.clear)
  }
}

struct CreateTeamSheet: View {
  let model: TeamsModel
  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var icon = ""

  var body: some View {
    NavigationStack {
      Form {
        if model.isOffline { OfflineBanner() }
        Section(L10n.Teams.teamInformation) {
          TextField(L10n.Teams.teamNamePlaceholder, text: $name)
            .textInputAutocapitalization(.words)
          TextField(TeamsStrings.icon, text: $icon)
        }
      }
      .navigationTitle(L10n.Teams.createNewTeam)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(TeamsStrings.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.Teams.createTeam) {
            Task { if await model.create(services.teams, name: name, icon: icon) { dismiss() } }
          }
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || model.isBusy)
        }
      }
    }
    .presentationDetents([.medium])
  }
}
