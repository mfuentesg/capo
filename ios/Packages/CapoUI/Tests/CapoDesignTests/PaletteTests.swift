import Testing
import SwiftUI
import UIKit
@testable import CapoDesign

@MainActor @Suite struct PaletteTests {
  /// (token, oklch, expected rendered hex) from WEB_PARITY_ANALYSIS §5.4, default palette.
  static let light: [(String, OKLCH, String)] = [
    ("background", OKLCH(0.920, 0.008, 281), "#e3e4ea"),
    ("foreground", OKLCH(0.360, 0.030, 278), "#393c4d"),
    ("card", OKLCH(0.948, 0.006, 287), "#ededf2"),
    ("primary", OKLCH(0.638, 0.205, 42), "#eb5100"),
    ("secondary", OKLCH(0.838, 0.010, 279), "#c8c9d0"),
    ("mutedForeground", OKLCH(0.480, 0.027, 278), "#5a5c6d"),
    ("destructive", OKLCH(0.465, 0.222, 12), "#b30037"),
    ("border", OKLCH(0.782, 0.011, 276), "#b6b8bf"),
    ("chord", OKLCH(0.495, 0.265, 295), "#750fe3"),
    ("accentSongs", OKLCH(0.495, 0.215, 258), "#0057d8"),
    ("accentActivity", OKLCH(0.580, 0.155, 148), "#1f9240"),
    ("comment", OKLCH(0.55, 0.12, 195), "#008687"),
    ("note", OKLCH(0.58, 0.13, 65), "#ae6700")
  ]
  static let dark: [(String, OKLCH, String)] = [
    ("background", OKLCH(0.148, 0.028, 277), "#080916"),
    ("foreground", OKLCH(0.855, 0.042, 272), "#c5ceec"),
    ("card", OKLCH(0.220, 0.028, 277), "#171928"),
    ("primary", OKLCH(0.793, 0.132, 56), "#fca463"),
    ("secondary", OKLCH(0.298, 0.030, 278), "#2a2c3c"),
    ("mutedForeground", OKLCH(0.612, 0.048, 272), "#7983a1"),
    ("destructive", OKLCH(0.727, 0.158, 3), "#f5789d"),
    ("chord", OKLCH(0.749, 0.160, 298), "#bb95ff"),
    ("accentSongs", OKLCH(0.742, 0.139, 257), "#70adff"),
    ("accentActivity", OKLCH(0.862, 0.121, 152), "#92e9aa"),
    ("comment", OKLCH(0.68, 0.12, 195), "#00afaf"),
    ("note", OKLCH(0.78, 0.12, 65), "#eca760")
  ]

  private func value(_ name: String, in t: CapoPalette.Tokens) -> String? {
    switch name {
    case "background": t.background
    case "foreground": t.foreground
    case "card": t.card
    case "primary": t.primary
    case "secondary": t.secondary
    case "mutedForeground": t.mutedForeground
    case "destructive": t.destructive
    case "border": t.border
    case "chord": t.chord
    case "accentSongs": t.accentSongs
    case "accentActivity": t.accentActivity
    case "comment": t.comment
    case "note": t.note
    default: nil
    }
  }

  @Test func defaultPaletteHoldsRenderedHexes() throws {
    for (name, _, hex) in Self.light { #expect(value(name, in: CapoPalette.catppuccin.light) == hex, "light \(name)") }
    for (name, _, hex) in Self.dark { #expect(value(name, in: CapoPalette.catppuccin.dark) == hex, "dark \(name)") }
  }

  @Test func oklchSourcesConvertToTheDocumentedHexes() {
    // The oklch triplets in globals.css convert (via OKLCH.swift) to the hexes the palette stores.
    // Allow one unit per channel for rounding differences.
    func close(_ a: String, _ b: String) -> Bool {
      guard let x = HexColor.parse(a), let y = HexColor.parse(b) else { return false }
      return abs(x.red - y.red) * 255 <= 1.01 && abs(x.green - y.green) * 255 <= 1.01
        && abs(x.blue - y.blue) * 255 <= 1.01
    }
    for (name, oklch, hex) in Self.light + Self.dark {
      #expect(close(oklch.hex, hex), "\(name): \(oklch.hex) vs \(hex)")
    }
  }

  @Test func lightPrimaryForegroundIsLight() {
    #expect(CapoPalette.catppuccin.light.primaryForeground == "#ededf2")
    #expect(CapoPalette.catppuccin.dark.primaryForeground == "#080916")
  }

  @Test func sectionAccentsMatchTheWeb() {
    let l = CapoPalette.catppuccin.light.sectionAccents
    let d = CapoPalette.catppuccin.dark.sectionAccents
    #expect(l["verse"] == "#005fb2" && d["verse"] == "#45a4f6")
    #expect(l["chorus"] == "#624bbc" && d["chorus"] == "#a192ff")
    #expect(l["bridge"] == "#a13170" && d["bridge"] == "#e670ac")
    #expect(l["comment"] == "#008687" && d["comment"] == "#00afaf")
    #expect(l["repeat"] == "#9e4800" && d["repeat"] == "#f29520")
    #expect(l["tab"] == "#626369" && d["grid"] == "#8e8f95")
    #expect(l["intro"] == "#1b7e2a" && d["intro"] == "#67bb6b")
    #expect(l["outro"] == "#007982" && d["outro"] == "#00b6be")
    #expect(l["pre_chorus"] == "#7d45a2" && d["pre_chorus"] == "#bf8ae6")
  }

  @Test func themeColorsResolvePerInterfaceStyle() {
    func resolved(_ color: Color, _ style: UIUserInterfaceStyle) -> String {
      let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
      var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
      ui.getRed(&r, green: &g, blue: &b, alpha: &a)
      return String(format: "#%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
    #expect(resolved(CapoTheme.background, .light) == "#e3e4ea")
    #expect(resolved(CapoTheme.background, .dark) == "#080916")
    #expect(resolved(CapoTheme.onPrimary, .light) == "#ededf2")
    #expect(resolved(CapoTheme.accent(for: "verse"), .dark) == "#45a4f6")
    #expect(resolved(CapoTheme.accent(for: "unknown"), .light) == "#5a5c6d")
  }

  @Test func sectionBackgroundAlphaFollowsScheme() {
    func alpha(_ style: UIUserInterfaceStyle) -> CGFloat {
      UIColor(CapoTheme.sectionBackground(for: "verse"))
        .resolvedColor(with: UITraitCollection(userInterfaceStyle: style)).cgColor.alpha
    }
    #expect(abs(alpha(.light) - 0.06) < 0.001)
    #expect(abs(alpha(.dark) - 0.12) < 0.001)
  }

  @Test func tabletScaleStartsAt768() {
    #expect(CapoScale.factor(forWidth: 767) == 1)
    #expect(CapoScale.factor(forWidth: 768) == 1.0625)
  }

  @Test func radiiFollowTheWebScale() {
    #expect(CapoRadius.base == 10.4 && CapoRadius.md == 8.4 && CapoRadius.xl == 14.4 && CapoRadius.xxl == 16)
  }

  @Test func lyricsAndChordsUseGeistMono() {
    #expect(CapoFont.postScriptName(.regular, mono: true) == "GeistMono-Regular")
    #expect(CapoTextSize.sm.size == 14 && CapoTextSize.xl2.size == 24 && CapoTextSize.px12.lineHeight == nil)
  }

  @Test func storeUpdatesCurrentPalette() {
    let store = CapoPaletteStore()
    var custom = CapoPalette.catppuccin
    custom.id = "test"
    store.current = custom
    #expect(CapoPaletteStorage.current.id == "test")
    store.current = .catppuccin
    #expect(CapoPaletteStorage.current.id == "catppuccin")
  }
}
