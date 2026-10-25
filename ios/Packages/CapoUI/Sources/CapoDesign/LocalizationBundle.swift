import Foundation

extension Bundle {
  /// CapoDesign's resource bundle. UI targets without resources of their own (Auth, Shell) use it for
  /// `String(localized:bundle:)` lookups; prefer the generated `L10n` accessors.
  public static var capoDesign: Bundle { .module }
}
