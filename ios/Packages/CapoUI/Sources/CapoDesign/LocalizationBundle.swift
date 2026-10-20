import Foundation

extension Bundle {
  /// CapoDesign's resource bundle. UI targets without resources of their own (Auth, Shell) use it for
  /// `String(localized:defaultValue:bundle:)` fallbacks until WP12 harvests the keys into L10n.
  public static var capoDesign: Bundle { .module }
}
