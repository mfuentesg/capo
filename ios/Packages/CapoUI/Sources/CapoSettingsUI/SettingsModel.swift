import CapoDesign
import Foundation
import Observation

@Observable
@MainActor
final class SettingsModel {
  var preferences = UserPreferences.default
  var status = SyncStatus(phase: .idle, lastSuccessAt: nil, pendingOperations: 0, conflicts: 0, failedOperations: 0)
  var isDeleting = false

  var isSyncing: Bool { status.phase == .pushing || status.phase == .pulling }

  /// Feeds preferences until the surrounding task is cancelled.
  func observePreferences(_ settings: any SettingsRepository) async {
    for await prefs in settings.preferences() { preferences = prefs }
  }

  /// Feeds sync status until the surrounding task is cancelled.
  func observeStatus(_ sync: any SyncService) async {
    for await status in sync.status() { self.status = status }
  }

  /// The web's two locales (`lib/i18n/config.ts`, `language-settings.tsx`).
  static let languages: [(code: String, name: String, flag: String)] = [
    ("en", "English", "\u{1F1EC}\u{1F1E7}"), ("es", "Español", "\u{1F1EA}\u{1F1F8}")
  ]

  /// Language the running process localised to (changes only after a relaunch).
  static var runningLanguageCode: String {
    String((Bundle.main.preferredLocalizations.first ?? "en").prefix(2))
  }

  /// The in-app choice, else the stored `preferences.locale`, else the process language.
  var currentLanguageCode: String {
    AppLanguage.shared.code ?? preferences.locale ?? Self.runningLanguageCode
  }

  static func currentLanguageName(locale: Locale = .current) -> String {
    let code = Bundle.main.preferredLocalizations.first ?? locale.identifier
    let name = locale.localizedString(forIdentifier: code) ?? code
    return name.prefix(1).uppercased() + name.dropFirst()
  }

  /// Names of owned teams that other people also belong to; deleting the account deletes them.
  var sharedOwnedTeams: [String] = []

  func loadSharedOwnedTeams(_ teams: any TeamRepository) async {
    var owned: [Team] = []
    for await list in teams.teams() {
      owned = list.filter { $0.role == .owner }.map(\.team)
      break
    }
    var shared: [String] = []
    for team in owned {
      // Offline or failing lookups just skip the team; the generic confirmation still applies.
      if let members = try? await teams.members(teamID: team.id), members.count > 1 {
        shared.append(team.name)
      }
    }
    sharedOwnedTeams = shared
  }

  static func appVersion(bundle: Bundle = .main) -> String {
    let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    return "\(short) (\(build))"
  }
}
