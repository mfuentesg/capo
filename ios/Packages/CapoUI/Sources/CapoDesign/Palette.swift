import Observation
import SwiftUI
import os

/// A theme palette: one token set per appearance, holding the sRGB values the web actually renders
/// (the `oklch(...)` values in `app/globals.css`, not the hexes in its comments). The other eleven web
/// palettes (WEB_PARITY_ANALYSIS §5.4) can be added later as more `CapoPalette` values.
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

  public var id: String
  public var light: Tokens
  public var dark: Tokens

  public func tokens(dark isDark: Bool) -> Tokens { isDark ? dark : light }
}

extension CapoPalette {
  /// The default web palette ("catppuccin"), rendered values from WEB_PARITY_ANALYSIS §5.4.
  public nonisolated static let catppuccin = CapoPalette(
    id: "catppuccin",
    light: Tokens(
      background: "#e3e4ea", foreground: "#393c4d", card: "#ededf2", popover: "#ededf2",
      primary: "#eb5100", primaryForeground: "#ededf2", secondary: "#c8c9d0", muted: "#c8c9d0",
      mutedForeground: "#5a5c6d", accent: "#c8c9d0", destructive: "#b30037", border: "#b6b8bf",
      input: "#b6b8bf", ring: "#eb5100", chord: "#750fe3", accentSongs: "#0057d8",
      accentPlaylists: "#750fe3", accentActivity: "#1f9240", sidebar: "#dadbe2",
      sidebarAccent: "#c8c9d0", sidebarBorder: "#b6b8bf",
      sectionAccents: [
        "verse": "#005fb2", "chorus": "#624bbc", "bridge": "#a13170", "comment": "#008687",
        "repeat": "#9e4800", "tab": "#626369", "grid": "#626369", "intro": "#1b7e2a",
        "outro": "#007982", "pre_chorus": "#7d45a2"
      ],
      comment: "#008687", note: "#ae6700", warning: "#e17100"),
    dark: Tokens(
      background: "#080916", foreground: "#c5ceec", card: "#171928", popover: "#171928",
      primary: "#fca463", primaryForeground: "#080916", secondary: "#2a2c3c", muted: "#171928",
      mutedForeground: "#7983a1", accent: "#2a2c3c", destructive: "#f5789d", border: "#2a2c3c",
      input: "#2a2c3c", ring: "#fca463", chord: "#bb95ff", accentSongs: "#70adff",
      accentPlaylists: "#bb95ff", accentActivity: "#92e9aa", sidebar: "#04050f",
      sidebarAccent: "#171928", sidebarBorder: "#171928",
      sectionAccents: [
        "verse": "#45a4f6", "chorus": "#a192ff", "bridge": "#e670ac", "comment": "#00afaf",
        "repeat": "#f29520", "tab": "#8e8f95", "grid": "#8e8f95", "intro": "#67bb6b",
        "outro": "#00b6be", "pre_chorus": "#bf8ae6"
      ],
      comment: "#00afaf", note: "#eca760", warning: "#ffb900"))

  /// Palettes the app can currently select. Only the default exists so far.
  public nonisolated static let all: [CapoPalette] = [.catppuccin]
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

/// Observable handle on the current palette. Setting `current` updates the storage the theme colours read
/// and publishes the change to views that observe it or read `\.capoPalette`.
@MainActor @Observable
public final class CapoPaletteStore {
  public static let shared = CapoPaletteStore()

  public var current: CapoPalette = CapoPaletteStorage.current {
    didSet { CapoPaletteStorage.current = current }
  }

  public init() {}
}

extension EnvironmentValues {
  @Entry public var capoPalette: CapoPalette = .catppuccin
}
