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
  var songCount = 0
  private var didDebugOpen = false
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
    #if DEBUG
      // Screenshot/validation hook: launch with `-CapoTab songs|playlists|chords|teams|settings`
      // (`-CapoSidebar` is the legacy spelling).
      let launch = UserDefaults.standard
      if let name = launch.string(forKey: "CapoTab") ?? launch.string(forKey: "CapoSidebar") {
        if name.lowercased() == "settings" {
          navigation.showSettings = true
        } else if let item = ShellTab.debug(name) {
          navigation.open(item)
        }
      }
    #endif
  }

  var hasPalettes: Bool { true }
  private var palette: String?
  private var uiFont: String?

  /// Avatar-menu "Surprise me": random palette and font plus the opposite of light/dark (web
  /// `profile-menu-actions.tsx`), applied now and saved to preferences.
  func surpriseMe() {
    var rng = SystemRandomNumberGenerator()
    let pick = CapoAppearance.surprise(
      palette: palette, font: uiFont, theme: theme, flipTheme: true, using: &rng)
    palette = pick.palette.id
    uiFont = pick.font.id
    theme = pick.theme
    CapoPaletteStore.shared.current = pick.palette
    CapoPaletteStore.shared.uiFont = pick.font
    let settings = services.settings
    let patch = CapoAppearance.patch(palette: pick.palette, font: pick.font, theme: pick.theme)
    Task { try? await settings.updatePreferences(patch) }
  }

  func setTheme(_ newTheme: AppTheme) {
    theme = newTheme
    let settings = services.settings
    Task { try? await settings.updatePreferences(PreferencesPatch(theme: newTheme)) }
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

  /// Songs saved on this device for the current context, for the sidebar footer.
  func observeSongCount() async {
    let query = SongQuery(context: context, statuses: Set(SongStatus.allCases))
    for await items in services.songs.songs(query) {
      songCount = items.count
      #if DEBUG
        // Screenshot/validation hook: launch with `-CapoOpenFirstSong YES`.
        if !didDebugOpen, UserDefaults.standard.bool(forKey: "CapoOpenFirstSong"), let first = items.first {
          didDebugOpen = true
          navigation.openSong(first.id)
        }
      #endif
    }
  }

  func observePreferences() async {
    for await prefs in services.settings.preferences() {
      theme = prefs.theme
      palette = prefs.palette
      uiFont = prefs.uiFont
      var paletteID = prefs.palette, fontID = prefs.uiFont
      #if DEBUG
        // Screenshot hook: `-CapoDebugPalette rose-pine -CapoDebugFont lato`.
        paletteID = UserDefaults.standard.string(forKey: "CapoDebugPalette") ?? paletteID
        fontID = UserDefaults.standard.string(forKey: "CapoDebugFont") ?? fontID
      #endif
      CapoPaletteStore.shared.apply(paletteID: paletteID, uiFontID: fontID)
    }
  }

  func syncNow(_ reason: SyncReason) {
    let sync = services.sync
    Task { await sync.syncNow(reason: reason) }
  }
}
