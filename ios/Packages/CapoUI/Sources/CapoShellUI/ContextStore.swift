import CapoDesign
import Foundation
import Observation

/// Personal-or-team selection for one signed-in user, persisted in UserDefaults per user.
@Observable
@MainActor
final class ContextStore {
  let userID: UserID
  private let defaults: UserDefaults
  private(set) var teams: [TeamWithRole] = []
  private(set) var context: AppContext
  /// A persisted team that is not confirmed yet because the teams stream has not emitted.
  private var unconfirmedTeamID: TeamID?
  private var hasLoadedTeams = false

  init(userID: UserID, defaults: UserDefaults = .standard) {
    self.userID = userID
    self.defaults = defaults
    context = .personal(userID: userID)
    if let stored = defaults.string(forKey: Self.key(for: userID)), let id = UUID(uuidString: stored) {
      unconfirmedTeamID = id
    }
  }

  static func key(for userID: UserID) -> String { "capo.context.\(userID.uuidString.lowercased())" }

  var role: TeamRole? {
    guard let teamID = context.teamID else { return nil }
    return teams.first { $0.id == teamID }?.role
  }

  var selectedTeam: Team? {
    guard let teamID = context.teamID else { return nil }
    return teams.first { $0.id == teamID }?.team
  }

  func select(_ newContext: AppContext) {
    context = newContext
    unconfirmedTeamID = nil
    switch newContext {
    case .personal: defaults.removeObject(forKey: Self.key(for: userID))
    case .team(let id): defaults.set(id.uuidString.lowercased(), forKey: Self.key(for: userID))
    }
  }

  func selectPersonal() { select(.personal(userID: userID)) }

  /// Reconciles the selection with the latest team list (left a team, team deleted, restore).
  func update(teams newTeams: [TeamWithRole]) {
    teams = newTeams.sorted { $0.team.name.localizedCaseInsensitiveCompare($1.team.name) == .orderedAscending }
    hasLoadedTeams = true
    if let pending = unconfirmedTeamID {
      unconfirmedTeamID = nil
      if teams.contains(where: { $0.id == pending }) { context = .team(teamID: pending) }
      return
    }
    if let current = context.teamID, !teams.contains(where: { $0.id == current }) {
      selectPersonal()
    }
  }
}
