import CapoDesign
import Foundation

/// Settings copy that has no `L10n` key yet. CapoSettingsUI has no resources of its own, so the
/// lookup goes through CapoDesign's bundle; WP12 harvests the `ios.settings.*` keys in Wave 3.
enum SettingsStrings {

  // TODO(i18n)
  static var account: String { String(localized: "ios.settings.account", defaultValue: "Account", bundle: .capoDesign) }
  // TODO(i18n)
  static var signOut: String { String(localized: "ios.settings.signOut", defaultValue: "Sign out", bundle: .capoDesign) }
  // TODO(i18n)
  static var signOutTitle: String {
    String(localized: "ios.settings.signOutTitle", defaultValue: "Sign out of Capo?", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var signOutMessage: String {
    String(
      localized: "ios.settings.signOutMessage",
      defaultValue: "Your songs stay on this device and sync again when you sign back in.", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var lyrics: String { String(localized: "ios.settings.lyrics", defaultValue: "Lyrics", bundle: .capoDesign) }
  // TODO(i18n)
  static var defaultColumns: String {
    String(localized: "ios.settings.defaultColumns", defaultValue: "Default layout", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var openLanguageSettings: String {
    String(localized: "ios.settings.openLanguageSettings", defaultValue: "Change in iOS Settings", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var sync: String { String(localized: "ios.settings.sync", defaultValue: "Sync", bundle: .capoDesign) }
  // TODO(i18n)
  static var status: String { String(localized: "ios.settings.status", defaultValue: "Status", bundle: .capoDesign) }
  // TODO(i18n)
  static var lastSync: String {
    String(localized: "ios.settings.lastSync", defaultValue: "Last sync", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var pendingChanges: String {
    String(localized: "ios.settings.pendingChanges", defaultValue: "Pending changes", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var viewConflicts: String {
    String(localized: "ios.settings.viewConflicts", defaultValue: "Review conflicts", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var about: String { String(localized: "ios.settings.about", defaultValue: "About", bundle: .capoDesign) }
  // TODO(i18n)
  static var version: String { String(localized: "ios.settings.version", defaultValue: "Version", bundle: .capoDesign) }
  // TODO(i18n)
  static var data: String { String(localized: "ios.settings.data", defaultValue: "Data on this device", bundle: .capoDesign) }
  // TODO(i18n)
  static var eraseAndSignOut: String {
    String(localized: "ios.settings.eraseAndSignOut", defaultValue: "Erase local data and sign out", bundle: .capoDesign)
  }
  // TODO(i18n)
  static var deleteFailed: String {
    String(localized: "ios.settings.deleteFailed", defaultValue: "Could not delete the account. Try again.", bundle: .capoDesign)
  }
}
