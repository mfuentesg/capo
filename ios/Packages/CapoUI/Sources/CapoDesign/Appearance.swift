import CapoCore
import Foundation

/// Palette and font selection rules shared by Settings and the avatar menu.
public nonisolated enum CapoAppearance {
  /// "Surprise me" (web `palette-settings.tsx:229`, `profile-menu-actions.tsx:21`): a random palette and
  /// UI font, never the current ones. `flipTheme` (the avatar menu version) also picks light or dark,
  /// excluding the current theme.
  public static func surprise<G: RandomNumberGenerator>(
    palette: String?, font: String?, theme: AppTheme?, flipTheme: Bool, using generator: inout G
  ) -> (palette: CapoPalette, font: CapoUIFont, theme: AppTheme?) {
    let currentPalette = CapoPalette.named(palette)?.id ?? CapoPalette.default.id
    let currentFont = CapoUIFont.named(font)?.id ?? CapoUIFont.default.id
    let newPalette = CapoPalette.all.filter { $0.id != currentPalette }.randomElement(using: &generator) ?? .default
    let newFont = CapoUIFont.all.filter { $0.id != currentFont }.randomElement(using: &generator) ?? .default
    var newTheme: AppTheme?
    if flipTheme {
      newTheme = [AppTheme.light, .dark].filter { $0 != theme }.randomElement(using: &generator) ?? .dark
    }
    return (newPalette, newFont, newTheme)
  }

  /// The patch that persists a selection (`theme` only when it changed).
  public static func patch(palette: CapoPalette, font: CapoUIFont, theme: AppTheme? = nil) -> PreferencesPatch {
    PreferencesPatch(theme: theme, palette: palette.id, uiFont: font.id)
  }
}
