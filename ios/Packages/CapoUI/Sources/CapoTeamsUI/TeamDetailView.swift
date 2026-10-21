import CapoCore
import CapoDesign
import SwiftUI

/// Members and invitations for one team; actions are gated by the viewer's role.
struct TeamDetailView: View {
  let team: Team
  let role: TeamRole

  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var model = TeamDetailModel()
  @State private var showInvite = false
  @State private var confirm: Confirmation?

  private var permissions: TeamPermissions { TeamPermissions(role: role) }

  enum Confirmation: Identifiable {
    case remove(TeamMember), transfer(TeamMember), leave, delete
    var id: String {
      switch self {
      case .remove(let m): "remove-\(m.id)"
      case .transfer(let m): "transfer-\(m.id)"
      case .leave: "leave"
      case .delete: "delete"
      }
    }
  }

  var body: some View {
    List {
      if model.isOffline { OfflineBanner() }
      membersSection
      if permissions.canManageMembers { invitationsSection }
      dangerSection
    }
    .capoList()
    .navigationTitle(team.name)
    .toolbar {
      if permissions.canManageMembers {
        ToolbarItem(placement: .topBarTrailing) {
          Button { showInvite = true } label: {
            Label(L10n.Teams.inviteMember, systemImage: "person.badge.plus")
          }
        }
      }
    }
    .sheet(isPresented: $showInvite) {
      InviteSheet(model: model, teamID: team.id, roles: permissions.assignableRoles)
    }
    .confirmationDialog(
      confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
      titleVisibility: .visible
    ) {
      if let confirm { confirmButton(confirm) }
    }
    .capoToast($model.message)
    .refreshable { await model.load(services.teams, teamID: team.id) }
    .task { await model.load(services.teams, teamID: team.id) }
  }

  // MARK: Sections

  private var membersSection: some View {
    Section {
      if model.loaded && model.members.isEmpty {
        Text(L10n.Teams.noMembersYet).foregroundStyle(CapoTheme.subtext).capoRowBackground()
      }
      ForEach(model.members) { member in
        MemberRow(
          name: model.displayName(member), email: member.profile?.email,
          role: member.membership.role, isMe: member.membership.userID == services.userID)
        .swipeActions(edge: .trailing) {
          if permissions.canModify(member.membership.role),
            member.membership.userID != services.userID
          {
            Button(L10n.Teams.removeMember, role: .destructive) { confirm = .remove(member) }
          }
        }
        .contextMenu { memberMenu(member) }
        .capoRowBackground()
      }
    } header: {
      Text(L10n.Teams.members.uppercased()).capoSectionHeader()
    }
  }

  @ViewBuilder
  private func memberMenu(_ member: TeamMember) -> some View {
    let target = member.membership.role
    if permissions.canModify(target) {
      Menu(L10n.Teams.changeRole) {
        ForEach(permissions.assignableRoles.filter { $0 != target }, id: \.self) { newRole in
          Button(TeamsStrings.roleName(newRole)) {
            Task { await model.changeRole(services.teams, teamID: team.id, member: member, to: newRole) }
          }
        }
      }
    }
    if permissions.canTransferOwnership, target != .owner {
      Button(L10n.Teams.transferOwnership) { confirm = .transfer(member) }
    }
    if permissions.canModify(target), member.membership.userID != services.userID {
      Button(L10n.Teams.removeMember, role: .destructive) { confirm = .remove(member) }
    }
  }

  private var invitationsSection: some View {
    Section {
      if model.loaded && model.invitations.isEmpty {
        Text(TeamsStrings.noInvitations).foregroundStyle(CapoTheme.subtext).capoRowBackground()
      }
      ForEach(model.invitations) { invitation in
        HStack {
          Text(invitation.email).foregroundStyle(CapoTheme.text).lineLimit(1)
          Spacer(minLength: 8)
          RoleBadge(role: invitation.role)
        }
        .frame(minHeight: 48)
        .swipeActions(edge: .trailing) {
          Button(L10n.Teams.cancelInvitation, role: .destructive) {
            Task { await model.revoke(services.teams, teamID: team.id, invitation: invitation) }
          }
        }
        .capoRowBackground()
      }
    } header: {
      Text(L10n.Teams.pendingInvitations.uppercased()).capoSectionHeader()
    }
  }

  private var dangerSection: some View {
    Section {
      if permissions.canLeave {
        Button(L10n.Teams.leaveTeam, role: .destructive) { confirm = .leave }
          .frame(minHeight: 48).capoRowBackground()
      } else {
        Text(L10n.Teams.leaveAsOwner).font(.footnote).foregroundStyle(CapoTheme.subtext)
          .capoRowBackground()
      }
      if permissions.canDeleteTeam {
        Button(L10n.Teams.deleteTeam, role: .destructive) { confirm = .delete }
          .frame(minHeight: 48).capoRowBackground()
      }
    }
  }

  // MARK: Confirmation

  private var confirmTitle: String {
    switch confirm {
    case .remove(let m): L10n.Teams.removeMemberConfirm(name: model.displayName(m))
    case .transfer(let m): "\(L10n.Teams.transferOwnership): \(model.displayName(m))"
    case .leave: L10n.Teams.leaveTeamConfirm(name: team.name)
    case .delete: L10n.Teams.deleteTeamConfirmDescription(name: team.name)
    case nil: ""
    }
  }

  @ViewBuilder
  private func confirmButton(_ action: Confirmation) -> some View {
    switch action {
    case .remove(let member):
      Button(L10n.Teams.removeMember, role: .destructive) {
        Task { await model.remove(services.teams, teamID: team.id, member: member) }
      }
    case .transfer(let member):
      Button(L10n.Teams.transferShort, role: .destructive) {
        Task { await model.transfer(services.teams, teamID: team.id, to: member) }
      }
    case .leave:
      Button(L10n.Teams.leaveShort, role: .destructive) {
        Task { if await model.leave(services.teams, teamID: team.id) { dismiss() } }
      }
    case .delete:
      Button(L10n.Teams.deleteTeam, role: .destructive) {
        Task { if await model.delete(services.teams, teamID: team.id) { dismiss() } }
      }
    }
  }
}

struct MemberRow: View {
  let name: String
  let email: String?
  let role: TeamRole
  let isMe: Bool

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(name).font(.headline).foregroundStyle(CapoTheme.text).lineLimit(1)
        if let email, email != name {
          Text(email).font(.caption).foregroundStyle(CapoTheme.subtext).lineLimit(1)
        }
      }
      Spacer(minLength: 8)
      RoleBadge(role: role)
    }
    .frame(minHeight: 56)
    .accessibilityElement(children: .combine)
  }
}

struct InviteSheet: View {
  let model: TeamDetailModel
  let teamID: TeamID
  let roles: [TeamRole]

  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var email = ""
  @State private var role: TeamRole = .member

  var body: some View {
    NavigationStack {
      Form {
        if model.isOffline { OfflineBanner() }
        TextField(TeamsStrings.email, text: $email)
          .textContentType(.emailAddress)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Picker(TeamsStrings.role, selection: $role) {
          ForEach(roles, id: \.self) { Text(TeamsStrings.roleName($0)).tag($0) }
        }
      }
      .capoList()
      .navigationTitle(L10n.Teams.inviteMember)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(TeamsStrings.cancel) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(L10n.Teams.sendInvitation) {
            Task {
              if await model.invite(services.teams, teamID: teamID, email: email, role: role) {
                dismiss()
              }
            }
          }
          .font(.body.weight(.bold))
          .disabled(!email.contains("@") || model.isBusy)
        }
      }
    }
    .presentationDetents([.medium])
    .onAppear { if !roles.contains(role), let first = roles.first { role = first } }
  }
}
