import CapoCore
import Foundation
import Supabase

/// Online-only teams and sharing calls. Failures are mapped to `CapoError`
/// (`offlineUnavailable` for transport errors, `permissionDenied`, `server(message)` otherwise).
public final class SupabaseTeamsRemote: TeamsRemote {
  private let client: SupabaseClient
  private let webBaseURL: URL

  public init(client: SupabaseClient, webBaseURL: URL) {
    self.client = client
    self.webBaseURL = webBaseURL
  }

  public func members(teamID: TeamID) async throws -> [TeamMember] {
    try await run {
      let rows: [TeamMemberWithProfileRow] = try await client.from("team_members")
        .select("*, profiles(full_name,email,avatar_url)")
        .eq("team_id", value: teamID.pg).order("joined_at", ascending: true).execute().value
      return rows.map { row in
        let membership = row.member.model
        let profile = ProfileSummary(
          id: membership.userID, email: row.profile?.email, fullName: row.profile?.fullName,
          avatarURL: row.profile?.avatarURL)
        return TeamMember(membership: membership, profile: row.profile == nil ? nil : profile)
      }
    }
  }

  public func invitations(teamID: TeamID) async throws -> [TeamInvitation] {
    try await run {
      let rows: [TeamInvitationRow] = try await client.from("team_invitations").select()
        .eq("team_id", value: teamID.pg).is("accepted_at", value: nil)
        .order("created_at", ascending: false).execute().value
      return rows.map(\.model)
    }
  }

  public func pendingInvitations() async throws -> [PendingInvitation] {
    // An RPC: the team_invitations SELECT policy only shows rows to members of the inviting team.
    try await run {
      let rows: [PendingInvitationRow] = try await client.rpc("get_my_pending_invitations")
        .execute().value
      return rows.map(\.model)
    }
  }

  public func createTeam(name: String, icon: String?, isPublic: Bool) async throws -> Team {
    try await run {
      var params: [String: JSONValue] = [
        "team_name": .string(name), "team_is_public": .bool(isPublic)
      ]
      if let icon, !icon.isEmpty { params["team_icon"] = .string(icon) }
      let data = try await client.rpc("create_team_with_owner", params: params).execute().data
      let decoder = JSONDecoder()
      if let rows = try? decoder.decode([TeamRow].self, from: data), let row = rows.first {
        return row.model
      }
      return try decoder.decode(TeamRow.self, from: data).model
    }
  }

  public func updateTeam(id: TeamID, name: String, icon: String?) async throws {
    try await run {
      let rows: [TeamRow] = try await client.from("teams")
        .update(
          ["name": JSONValue.string(name), "icon": JSONValue.nonEmptyString(icon ?? "")],
          returning: .representation
        )
        .eq("id", value: id.pg).select().execute().value
      // RLS filters a forbidden update down to zero rows instead of failing.
      if rows.isEmpty { throw CapoError.permissionDenied }
    }
  }

  public func deleteTeam(id: TeamID) async throws {
    try await run {
      let rows: [TeamRow] = try await client.from("teams").delete(returning: .representation)
        .eq("id", value: id.pg).select().execute().value
      if rows.isEmpty { throw CapoError.permissionDenied }
    }
  }

  public func leaveTeam(id: TeamID) async throws {
    try await run {
      try await client.rpc("leave_team", params: ["target_team_id": id.pg]).execute()
    }
  }

  public func invite(email: String, role: TeamRole, teamID: TeamID) async throws -> TeamInvitation
  {
    try await run {
      let data = try await client.rpc(
        "invite_team_member",
        params: [
          "target_team_id": teamID.pg, "member_email": email, "member_role": role.rawValue
        ]
      ).execute().data
      let decoder = JSONDecoder()
      if let row = try? decoder.decode(TeamInvitationRow.self, from: data) { return row.model }
      guard let row = try decoder.decode([TeamInvitationRow].self, from: data).first else {
        throw CapoError.server("Failed to create invitation")
      }
      return row.model
    }
  }

  public func revokeInvitation(id: UUID) async throws {
    try await run {
      try await client.from("team_invitations").delete(returning: .minimal)
        .eq("id", value: id.pg).execute()
    }
  }

  public func declineInvitation(token: String) async throws {
    try await run {
      try await client.rpc("decline_team_invitation", params: ["p_token": token]).execute()
    }
  }

  public func resendInvitation(id: UUID) async throws -> TeamInvitation {
    try await run {
      let data = try await client.rpc("resend_team_invitation", params: ["p_invitation_id": id.pg])
        .execute().data
      let decoder = JSONDecoder()
      if let row = try? decoder.decode(TeamInvitationRow.self, from: data) { return row.model }
      guard let row = try decoder.decode([TeamInvitationRow].self, from: data).first else {
        throw CapoError.server("Failed to resend invitation")
      }
      return row.model
    }
  }

  public func acceptInvitation(token: String) async throws -> TeamID {
    try await run {
      let data = try await client.rpc("accept_team_invitation", params: ["invitation_token": token])
        .execute().data
      let raw = try JSONDecoder().decode(String.self, from: data)
      guard let id = UUID(uuidString: raw) else { throw CapoError.server("Invalid team id") }
      return id
    }
  }

  public func changeRole(userID: UserID, teamID: TeamID, role: TeamRole) async throws {
    try await run {
      try await client.rpc(
        "change_team_member_role",
        params: [
          "target_team_id": teamID.pg, "target_user_id": userID.pg, "new_role": role.rawValue
        ]
      ).execute()
    }
  }

  public func removeMember(userID: UserID, teamID: TeamID) async throws {
    try await run {
      try await client.rpc(
        "remove_team_member",
        params: ["target_team_id": teamID.pg, "target_user_id": userID.pg]
      ).execute()
    }
  }

  public func transferOwnership(teamID: TeamID, to userID: UserID) async throws {
    try await run {
      try await client.rpc(
        "transfer_team_ownership",
        params: ["target_team_id": teamID.pg, "new_owner_id": userID.pg]
      ).execute()
    }
  }

  public func ensureShareCode(playlistID: PlaylistID) async throws -> String {
    try await run {
      let data = try await client.rpc("ensure_share_code", params: ["playlist_id": playlistID.pg])
        .execute().data
      return try JSONDecoder().decode(String.self, from: data)
    }
  }

  // MARK: Helpers

  @discardableResult
  private func run<T>(_ body: () async throws -> T) async throws -> T {
    do {
      return try await body()
    } catch {
      throw RemoteErrors.capoError(error)
    }
  }

  /// `ilike` is used for a case-insensitive exact match, so `%`, `_` and `\` must be literal.
  static func escapeLikePattern(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "%", with: "\\%")
      .replacingOccurrences(of: "_", with: "\\_")
  }
}
