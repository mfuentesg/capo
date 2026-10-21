import CapoDesign
import CapoSettingsUI
import Foundation
import Observation

/// Per-user shell state fed by the service streams.
@Observable
@MainActor
final class ShellModel {
  let services: UserServices
  let session: AuthSession
  let contextStore: ContextStore
  let navigation = ShellNavigation()
  var syncStatus = SyncStatus(phase: .idle, lastSuccessAt: nil, pendingOperations: 0, conflicts: 0, failedOperations: 0)
  var conflictCount = 0
  var theme: AppTheme?
  let settingsContext: SettingsContext

  init(
    session: AuthSession, services: UserServices, settingsContext: SettingsContext = .empty,
    defaults: UserDefaults = .standard
  ) {
    self.session = session
    self.services = services
    self.settingsContext = settingsContext
    contextStore = ContextStore(userID: session.userID, defaults: defaults)
  }

  var context: AppContext { contextStore.context }

  func select(_ context: AppContext) {
    guard context != contextStore.context else { return }
    contextStore.select(context)
    navigation.resetSelections()
  }

  func observeTeams() async {
    for await teams in services.teams.teams() {
      let before = contextStore.context
      contextStore.update(teams: teams)
      if before != contextStore.context { navigation.resetSelections() }
    }
  }

  func observeSync() async {
    for await status in services.sync.status() { syncStatus = status }
  }

  func observeConflicts() async {
    for await list in services.conflicts.conflicts() { conflictCount = list.count }
  }

  func observePreferences() async {
    for await prefs in services.settings.preferences() { theme = prefs.theme }
  }

  func syncNow(_ reason: SyncReason) {
    let sync = services.sync
    Task { await sync.syncNow(reason: reason) }
  }
}
