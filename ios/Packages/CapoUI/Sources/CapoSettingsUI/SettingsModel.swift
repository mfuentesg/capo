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

  static func currentLanguageName(locale: Locale = .current) -> String {
    let code = Bundle.main.preferredLocalizations.first ?? locale.identifier
    let name = locale.localizedString(forIdentifier: code) ?? code
    return name.prefix(1).uppercased() + name.dropFirst()
  }

  static func appVersion(bundle: Bundle = .main) -> String {
    let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    return "\(short) (\(build))"
  }
}
