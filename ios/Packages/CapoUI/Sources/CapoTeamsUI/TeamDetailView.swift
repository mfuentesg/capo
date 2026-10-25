import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

/// Members and invitations for one team; actions are gated by the viewer's role
/// (web `team-detail-header`, `team-members-section`, `team-danger-zone`).
struct TeamDetailView: View {
  let team: Team
  let role: TeamRole

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var appContext
  @Environment(\.dismiss) private var dismiss
  @State private var model = TeamDetailModel()
  @State private var showInvite = false
  @State private var confirm: Confirmation?
  @State private var name: String
  @State private var icon: String?
  @State private var newOwnerID: UUID?
  @FocusState private var nameFocused: Bool

  init(team: Team, role: TeamRole) {
    self.team = team
    self.role = role
    _name = State(initialValue: team.name)
    _icon = State(initialValue: team.icon)
  }

  private var permissions: TeamPermissions { TeamPermissions(role: role) }

  enum Confirmation: Identifiable {
    case remove(TeamMember), transfer(TeamMember), transferAndLeave(TeamMember)
    case cancelInvitation(TeamInvitation), leave, delete
    var id: String {
      switch self {
      case .remove(let m): "remove-\(m.id)"
      case .transfer(let m): "transfer-\(m.id)"
      case .transferAndLeave(let m): "transferLeave-\(m.id)"
      case .cancelInvitation(let i): "cancel-\(i.id)"
      case .leave: "leave"
      case .delete: "delete"
      }
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if model.isOffline { OfflineBanner() }
        headerSection
        membersSection
        dangerSection
      }
      .padding(24)
    }
    .background(CapoTheme.background)
    .navigationTitle(team.name)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showInvite) {
      InviteSheet(model: model, teamID: team.id, roles: permissions.assignableRoles)
    }
    .confirmationDialog(
      confirmTitle, isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
      titleVisibility: .visible
    ) {
      if let confirm { confirmButton(confirm) }
    } message: {
      if let confirm, let text = confirmMessage(confirm) { Text(text) }
    }
    .capoToast($model.message)
    .refreshable { await model.load(services.teams, teamID: team.id) }
    .task { await model.load(services.teams, teamID: team.id) }
  }

  // MARK: Header

  private var headerSection: some View {
    HStack(alignment: .center, spacing: 16) {
      if permissions.canManageMembers {
        ZStack(alignment: .bottomTrailing) {
          TeamIconPickerButtonLarge(icon: $icon, tint: role.cardAccent) { newIcon in
            Task { _ = await model.rename(services.teams, team: team, name: name, icon: newIcon) }
          }
          CapoIcon(.pencil, size: 10)
            .foregroundStyle(CapoTheme.primaryForeground)
            .frame(width: 20, height: 20)
            .background(CapoTheme.primary, in: Circle())
            .offset(x: 4, y: 4)
            .allowsHitTesting(false)
        }
      } else {
        TeamIconTile(icon: icon, tint: role.cardAccent, size: 56, iconSize: 28)
      }
      VStack(alignment: .leading, spacing: 6) {
        if permissions.canManageMembers {
          TextField("", text: $name)
            .capoText(.xl2, weight: .bold, tracking: -0.025)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit { commitName() }
            .onChange(of: nameFocused) { _, focused in if !focused { commitName() } }
        } else {
          Text(name).capoText(.xl2, weight: .bold, tracking: -0.025)
        }
        HStack(spacing: 8) {
          RoleBadge(role: role)
          if appContext.teamID == team.id { StatusPill(text: L10n.Teams.active, prominent: true) }
          if team.isPublic { StatusPill(text: L10n.Filters.public) }
        }
      }
    }
  }

  private func commitName() {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      name = team.name
      return
    }
    guard trimmed != team.name else { return }
    Task { _ = await model.rename(services.teams, team: team, name: trimmed, icon: icon) }
  }

  // MARK: Members

  private var membersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        HStack(spacing: 8) {
          CapoIcon(.users, size: 20)
          Text(L10n.Teams.members).capoText(.xl, weight: .semibold, tracking: -0.025)
        }
        Spacer()
        if permissions.canManageMembers {
          Button { showInvite = true } label: {
            HStack(spacing: 8) {
              CapoIcon(.userPlus, size: 16)
              Text(L10n.Teams.addMember)
            }
          }
          .buttonStyle(CapoPrimaryButtonStyle(size: .small))
        }
      }
      if model.loaded && model.members.isEmpty {
        Text(L10n.Teams.noMembersYet).capoText(.sm).foregroundStyle(CapoTheme.subtext)
      }
      VStack(spacing: 0) {
        ForEach(model.members) { member in
          memberRow(member)
          if member.id != model.members.last?.id { Divider().overlay(CapoTheme.border) }
        }
      }
      if permissions.canManageMembers { invitationsBlock }
    }
    .teamSurface()
  }

  private func memberRow(_ member: TeamMember) -> some View {
    let target = member.membership.role
    let isMe = member.membership.userID == services.userID
    return HStack(spacing: 12) {
      AvatarInitial(text: model.displayName(member))
      VStack(alignment: .leading, spacing: 2) {
        Text(model.displayName(member)).capoText(.sm, weight: .medium).lineLimit(1)
        if let email = member.profile?.email, email != model.displayName(member) {
          Text(email).capoText(.xs).foregroundStyle(CapoTheme.subtext).lineLimit(1)
        }
      }
      Spacer(minLength: 8)
      if permissions.canModify(target) && !isMe {
        roleMenu(member)
        Menu {
          if permissions.canTransferOwnership {
            Button(L10n.Teams.transferOwnership) { confirm = .transfer(member) }
          }
          Button(L10n.Teams.removeMember, role: .destructive) { confirm = .remove(member) }
        } label: {
          CapoIcon(.moreVertical, size: 16).foregroundStyle(CapoTheme.text).frame(width: 44, height: 44)
        }
        .accessibilityLabel(L10n.Teams.manageTeam)
      } else {
        RoleBadge(role: target)
      }
    }
    .frame(minHeight: 56)
    .accessibilityElement(children: .contain)
  }

  private func roleMenu(_ member: TeamMember) -> some View {
    let current = member.membership.role
    return Menu {
      ForEach(permissions.assignableRoles, id: \.self) { newRole in
        Button {
          guard newRole != current else { return }
          Task { await model.changeRole(services.teams, teamID: team.id, member: member, to: newRole) }
        } label: {
          Label {
            Text(TeamsStrings.roleName(newRole))
          } icon: {
            if newRole == current { Image(systemName: "checkmark") }
          }
        }
      }
    } label: {
      HStack(spacing: 6) {
        CapoIcon(.shield, size: 16)
        Text(TeamsStrings.roleName(current)).capoText(.sm, weight: .medium)
        CapoIcon(.chevronDown, size: 12)
      }
      .foregroundStyle(CapoTheme.text)
      .padding(.horizontal, 12).frame(minHeight: 44)
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input))
    }
    .accessibilityLabel(L10n.Teams.changeRole)
  }

  // MARK: Invitations

  @ViewBuilder
  private var invitationsBlock: some View {
    if !model.activeInvitations.isEmpty {
      invitationGroup(title: L10n.Teams.pendingInvitations, invitations: model.activeInvitations, expired: false)
    }
    if !model.expiredInvitations.isEmpty {
      invitationGroup(title: L10n.Teams.expiredInvitations, invitations: model.expiredInvitations, expired: true)
    }
    if model.loaded && model.invitations.isEmpty {
      Text(TeamsStrings.noInvitations).capoText(.sm).foregroundStyle(CapoTheme.subtext)
    }
  }

  private func invitationGroup(title: String, invitations: [TeamInvitation], expired: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased()).capoSectionHeader()
      ForEach(invitations) { invitation in
        HStack(spacing: 12) {
          CapoIcon(.mail, size: 16)
            .foregroundStyle(CapoTheme.subtext)
            .frame(width: 36, height: 36)
            .background(CapoTheme.muted, in: Circle())
          VStack(alignment: .leading, spacing: 2) {
            Text(invitation.email).capoText(.sm, weight: .medium).lineLimit(1)
            HStack(spacing: 4) {
              CapoIcon(.clock, size: 12)
              Text(
                expired
                  ? L10n.Teams.invitationExpired
                  : L10n.Teams.invitedOn(date: Self.dateText(invitation.createdAt)))
            }
            .capoText(.xs)
            .foregroundStyle(expired ? CapoTheme.destructive : CapoTheme.subtext)
          }
          Spacer(minLength: 8)
          RoleBadge(role: invitation.role)
          if expired {
            iconButton(.refreshCw, label: L10n.Teams.resendInvitation) {
              Task { await model.resend(services.teams, teamID: team.id, invitation: invitation) }
            }
          } else {
            iconButton(.copy, label: L10n.Teams.copyInvitationLink) { copyLink(invitation) }
          }
          iconButton(.trash2, label: L10n.Teams.cancelInvitation, tint: CapoTheme.destructive) {
            confirm = .cancelInvitation(invitation)
          }
        }
        .frame(minHeight: 52)
      }
    }
  }

  private func iconButton(
    _ icon: CapoIconName, label: String, tint: Color = CapoTheme.text, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      CapoIcon(icon, size: 16).foregroundStyle(tint).frame(width: 44, height: 44).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  private func copyLink(_ invitation: TeamInvitation) {
    UIPasteboard.general.string = TeamInvitationLink.url(
      token: invitation.token, base: services.sharing.shareURL(forCode: "x"))?.absoluteString
    model.message = L10n.Teams.invitationLinkCopied
  }

  static func dateText(_ stamp: ServerTimestamp) -> String {
    (stamp.date ?? .now).formatted(.dateTime.month(.abbreviated).day().year())
  }

  // MARK: Danger zone

  private var otherMembers: [TeamMember] {
    model.members.filter { $0.membership.userID != services.userID }
  }

  private var selectedNewOwner: TeamMember? {
    otherMembers.first { $0.membership.userID == newOwnerID }
  }

  private var dangerSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.Account.dangerZone).capoText(.xl, weight: .semibold, tracking: -0.025)
        .foregroundStyle(CapoTheme.destructive)
      if role == .owner {
        ownerActions
      } else {
        dangerRow(
          title: L10n.Teams.leaveTeam, detail: L10n.Teams.leaveTeamWarning, icon: .logOut,
          button: L10n.Teams.leaveShort
        ) { confirm = .leave }
      }
    }
    .teamSurface(
      border: CapoTheme.destructive.opacity(0.3), fill: CapoTheme.destructive.opacity(0.02))
  }

  @ViewBuilder
  private var ownerActions: some View {
    if otherMembers.isEmpty {
      if model.loaded {
        dangerRow(
          title: L10n.Teams.deleteTeam, detail: L10n.Teams.noOtherMembers, icon: .trash2,
          button: L10n.Teams.deleteAndLeave
        ) { confirm = .delete }
      }
    } else {
      VStack(alignment: .leading, spacing: 12) {
        Text(L10n.Teams.transferOwnership).capoText(.sm, weight: .medium)
        Text(L10n.Teams.transferOwnershipStayDescription).capoText(.xs).foregroundStyle(CapoTheme.subtext)
        Picker(L10n.Teams.selectNewOwner, selection: $newOwnerID) {
          Text(L10n.Teams.selectNewOwner).tag(UUID?.none)
          ForEach(otherMembers) { member in
            Text(model.displayName(member)).tag(Optional(member.membership.userID))
          }
        }
        .pickerStyle(.menu)
        .tint(CapoTheme.text)
        .frame(minHeight: 44)
        HStack(spacing: 8) {
          Button {
            if let member = selectedNewOwner { confirm = .transfer(member) }
          } label: {
            HStack(spacing: 8) {
              CapoIcon(.arrowLeftRight, size: 16)
              Text(L10n.Teams.transferAndStay).lineLimit(1)
            }
          }
          .buttonStyle(CapoSecondaryButtonStyle())
          .disabled(selectedNewOwner == nil || model.isBusy)
          Button {
            if let member = selectedNewOwner { confirm = .transferAndLeave(member) }
          } label: {
            HStack(spacing: 8) {
              CapoIcon(.logOut, size: 16)
              Text(L10n.Teams.transferAndLeave).lineLimit(1)
            }
          }
          .buttonStyle(CapoSecondaryButtonStyle())
          .disabled(selectedNewOwner == nil || model.isBusy)
        }
      }
      Divider().overlay(CapoTheme.destructive.opacity(0.2))
      dangerRow(
        title: L10n.Teams.deleteTeam, detail: L10n.Teams.deleteTeamDescription, icon: .trash2,
        button: L10n.Teams.deleteTeam
      ) { confirm = .delete }
    }
  }

  private func dangerRow(
    title: String, detail: String, icon: CapoIconName, button: String, action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).capoText(.sm, weight: .medium)
        Text(detail).capoText(.xs).foregroundStyle(CapoTheme.subtext)
      }
      Button(action: action) {
        HStack(spacing: 8) {
          CapoIcon(icon, size: 16)
          Text(button)
        }
        .foregroundStyle(CapoTheme.destructive)
      }
      .buttonStyle(CapoSecondaryButtonStyle())
      .disabled(model.isBusy)
    }
  }

  // MARK: Confirmation

  private var confirmTitle: String {
    switch confirm {
    case .remove(let m): L10n.Teams.removeMemberConfirm(name: model.displayName(m))
    case .transfer(let m), .transferAndLeave(let m):
      "\(L10n.Teams.transferOwnership): \(model.displayName(m))"
    case .cancelInvitation(let i): L10n.Teams.cancelInvitationConfirm(email: i.email)
    case .leave: L10n.Teams.leaveTeamConfirm(name: team.name)
    case .delete: L10n.Teams.deleteTeamConfirmDescription(name: team.name)
    case nil: ""
    }
  }

  private func confirmMessage(_ action: Confirmation) -> String? {
    switch action {
    case .remove: L10n.Teams.removeMemberWarning
    case .cancelInvitation: L10n.Teams.cancelInvitationWarning
    case .leave: L10n.Teams.leaveTeamWarning
    default: nil
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
    case .transferAndLeave(let member):
      Button(L10n.Teams.transferAndLeave, role: .destructive) {
        Task { if await model.transferAndLeave(services.teams, teamID: team.id, to: member) { dismiss() } }
      }
    case .cancelInvitation(let invitation):
      Button(L10n.Teams.cancelInvitation, role: .destructive) {
        Task { await model.revoke(services.teams, teamID: team.id, invitation: invitation) }
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

/// Web `teams/accept-invitation?token=` link, derived from the playlist share URL's origin because the
/// UI layer does not know the web base URL.
nonisolated enum TeamInvitationLink {
  static func url(token: String, base shareURL: URL) -> URL? {
    guard var parts = URLComponents(url: shareURL, resolvingAgainstBaseURL: false) else { return nil }
    parts.path = "/teams/accept-invitation"
    parts.queryItems = [URLQueryItem(name: "token", value: token)]
    return parts.url
  }
}

struct AvatarInitial: View {
  let text: String

  var body: some View {
    Text(String(text.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
      .capoText(.sm, weight: .semibold)
      .foregroundStyle(CapoTheme.text)
      .frame(width: 36, height: 36)
      .background(CapoTheme.primary.opacity(0.1), in: Circle())
      .accessibilityHidden(true)
  }
}

/// 56 px tile that opens the icon picker and reports the chosen name.
struct TeamIconPickerButtonLarge: View {
  @Binding var icon: String?
  let tint: Color
  var onChange: (String) -> Void
  @State private var open = false

  var body: some View {
    Button { open = true } label: {
      TeamIconTile(icon: icon, tint: tint, size: 56, iconSize: 28)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(TeamsStrings.iconPickerTitle)
    .sheet(isPresented: $open) { TeamIconPickerSheet(icon: $icon) }
    .onChange(of: icon) { old, new in
      if let new, new != old { onChange(new) }
    }
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
          .font(CapoFont.style(.body, weight: .bold))
          .disabled(!email.contains("@") || model.isBusy)
        }
      }
    }
    .presentationDetents([.medium])
    .onAppear { if !roles.contains(role), let first = roles.first { role = first } }
  }
}
