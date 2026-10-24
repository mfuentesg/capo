import Observation
import SwiftUI
import os

/// A theme palette: one token set per appearance, holding the sRGB values the web actually renders
/// (the `oklch(...)` values in `app/globals.css`, not the hexes in its comments). The twelve web palettes
/// are generated into `Generated/PaletteTables.swift` by `ios/scripts/gen-palettes.mjs`.
public nonisolated struct CapoPalette: Sendable, Equatable, Identifiable {
  /// The web's colour tokens for one appearance, as `#rrggbb`.
  public nonisolated struct Tokens: Sendable, Equatable {
    public var background: String
    public var foreground: String
    public var card: String
    public var popover: String
    public var primary: String
    public var primaryForeground: String
    public var secondary: String
    public var muted: String
    public var mutedForeground: String
    public var accent: String
    public var destructive: String
    public var border: String
    public var input: String
    public var ring: String
    public var chord: String
    public var accentSongs: String
    public var accentPlaylists: String
    public var accentActivity: String
    public var sidebar: String
    public var sidebarAccent: String
    public var sidebarBorder: String
    /// `--section-accent` per section type. Types not listed fall back to `mutedForeground`.
    public var sectionAccents: [String: String]
    /// `--comment-color`.
    public var comment: String
    /// Performance-note colour (`{note:}`).
    public var note: String
    /// Warning / "recently played" amber (Tailwind amber-600 light, amber-400 dark).
    public var warning: String
  }

  /// The hard-coded swatches the web's palette picker draws (`palette-settings.tsx`).
  public nonisolated struct Preview: Sendable, Equatable {
    public var background: String
    public var primary: String
    public var accent1: String
    public var accent2: String
  }

  public var id: String
  /// Picker label and one-line description (web `PALETTE_LABELS`).
  public var name: String
  public var summary: String
  public var preview: (light: Preview, dark: Preview)
  public var light: Tokens
  public var dark: Tokens

  public nonisolated static func == (lhs: CapoPalette, rhs: CapoPalette) -> Bool {
    lhs.id == rhs.id && lhs.light == rhs.light && lhs.dark == rhs.dark
  }

  public nonisolated static let `default`: CapoPalette = .catppuccin

  /// The palette for a stored id; nil when unknown (callers fall back to the default).
  public nonisolated static func named(_ id: String?) -> CapoPalette? { all.first { $0.id == id } }

  public nonisolated func tokens(dark isDark: Bool) -> Tokens { isDark ? dark : light }
}

/// Process-wide current palette, readable from any thread. `UIColor` dynamic providers run off the main
/// actor, so the palette lives behind a lock rather than on an isolated object.
nonisolated enum CapoPaletteStorage {
  private static let lock = OSAllocatedUnfairLock(initialState: CapoPalette.catppuccin)

  static var current: CapoPalette {
    get { lock.withLock { $0 } }
    set { lock.withLock { $0 = newValue } }
  }
}

/// Observable handle on the current palette and UI font. Setting either updates the storage the theme
/// colours and `CapoFont` read and bumps `revision`. Colours are dynamic `UIColor`s and fonts are built in
/// view bodies, so nothing re-renders by itself: `capoTheme()` keys the app root on `revision` (the "root
/// refresh") and `\.capoPalette` publishes the palette to views that observe it.
@MainActor @Observable
public final class CapoPaletteStore {
  public static let shared = CapoPaletteStore()

  public var current: CapoPalette = CapoPaletteStorage.current {
    didSet {
      CapoPaletteStorage.current = current
      if oldValue != current { revision += 1 }
    }
  }

  public var uiFont: CapoUIFont = CapoUIFontStorage.current {
    didSet {
      CapoUIFontStorage.current = uiFont
      if oldValue != uiFont { revision += 1 }
    }
  }

  /// Increments on every palette or font change; `capoTheme()` uses it as the root view identity.
  public private(set) var revision = 0

  public init() {}

  /// Applies the stored `preferences.palette` / `preferences.uiFont` ids; unknown or missing ids fall back
  /// to the web defaults (catppuccin, geist).
  public func apply(paletteID: String?, uiFontID: String?) {
    let palette = CapoPalette.named(paletteID) ?? .default
    let font = CapoUIFont.named(uiFontID) ?? .default
    if palette != current { current = palette }
    if font != uiFont { uiFont = font }
  }
}

extension EnvironmentValues {
  @Entry public var capoPalette: CapoPalette = .catppuccin
}
