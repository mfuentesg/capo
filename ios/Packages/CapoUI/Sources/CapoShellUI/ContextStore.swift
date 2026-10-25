import CapoDesign
import Foundation
import Observation

/// All / personal / team selection for one signed-in user, persisted in UserDefaults per user.
/// Like the web, a user with no stored choice starts on "All".
@Observable
@MainActor
final class ContextStore {
  let userID: UserID
  private let defaults: UserDefaults
  private(set) var teams: [TeamWithRole] = []
  private(set) var context: AppContext
  /// A persisted team that is not confirmed yet because the teams stream has not emitted.
  private var unconfirmedTeamID: TeamID?
  static let personalToken = "personal"
  private var hasLoadedTeams = false
  /// Where new items are created. Follows personal/team selections and is kept when the view is
  /// switched to "All" (web parity). Persisted separately because "All" clears the view key.
  private(set) var creationContext: AppContext

  init(userID: UserID, defaults: UserDefaults = .standard) {
    self.userID = userID
    self.defaults = defaults
    context = .all(userID: userID)
    creationContext = .personal(userID: userID)
    if let storedCreation = defaults.string(forKey: Self.creationKey(for: userID)),
      let id = UUID(uuidString: storedCreation)
    {
      creationTeamID = id
      creationContext = .team(teamID: id)
    }
    if let stored = defaults.string(forKey: Self.key(for: userID)) {
      if stored == Self.personalToken {
        context = .personal(userID: userID)
      } else if let id = UUID(uuidString: stored) {
        unconfirmedTeamID = id
        if creationTeamID == nil {
          creationTeamID = id
          creationContext = .team(teamID: id)
        }
      }
    }
  }

  /// Team picked as creation context, not confirmed against the teams list until it emits.
  private var creationTeamID: TeamID?

  static func key(for userID: UserID) -> String { "capo.context.\(userID.uuidString.lowercased())" }
  static func creationKey(for userID: UserID) -> String {
    "capo.creation.\(userID.uuidString.lowercased())"
  }

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
    case .all: break
    case .personal:
      creationContext = newContext
      creationTeamID = nil
      defaults.removeObject(forKey: Self.creationKey(for: userID))
    case .team(let id):
      creationContext = newContext
      creationTeamID = id
      defaults.set(id.uuidString.lowercased(), forKey: Self.creationKey(for: userID))
    }
    switch newContext {
    case .all: defaults.removeObject(forKey: Self.key(for: userID))
    case .personal: defaults.set(Self.personalToken, forKey: Self.key(for: userID))
    case .team(let id): defaults.set(id.uuidString.lowercased(), forKey: Self.key(for: userID))
    }
  }

  func selectPersonal() { select(.personal(userID: userID)) }
  func selectAll() { select(.all(userID: userID)) }

  /// Reconciles the selection with the latest team list (left a team, team deleted, restore).
  func update(teams newTeams: [TeamWithRole]) {
    teams = newTeams.sorted { $0.team.name.localizedCaseInsensitiveCompare($1.team.name) == .orderedAscending }
    hasLoadedTeams = true
    if let team = creationTeamID, !teams.contains(where: { $0.id == team }) {
      creationTeamID = nil
      creationContext = .personal(userID: userID)
      defaults.removeObject(forKey: Self.creationKey(for: userID))
    }
    if let pending = unconfirmedTeamID {
      unconfirmedTeamID = nil
      if teams.contains(where: { $0.id == pending }) { context = .team(teamID: pending) }
      return
    }
    if let current = context.teamID, !teams.contains(where: { $0.id == current }) {
      selectAll()
    }
  }
}
