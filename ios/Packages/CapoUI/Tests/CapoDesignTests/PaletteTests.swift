import CapoCore
import CoreText
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

  @Test func buttonSizesFollowTheWebVariants() {
    // components/ui/button.tsx: xs h-6 px-2 text-xs, sm h-8 px-3, default h-9 px-4, lg h-10 px-6.
    #expect(CapoButtonSize.extraSmall.height == 24 && CapoButtonSize.extraSmall.horizontalPadding == 8)
    #expect(CapoButtonSize.small.height == 32 && CapoButtonSize.small.horizontalPadding == 12)
    #expect(CapoButtonSize.regular.height == 36 && CapoButtonSize.regular.horizontalPadding == 16)
    #expect(CapoButtonSize.large.height == 40 && CapoButtonSize.large.horizontalPadding == 24)
    #expect(CapoButtonSize.extraSmall.textSize == .xs && CapoButtonSize.regular.textSize == .sm)
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

@MainActor @Suite struct PaletteTableTests {
  private static let hex = /^#[0-9a-f]{6}$/

  @Test func twelveWebPalettesInWebOrder() {
    #expect(CapoPalette.all.map(\.id) == [
      "catppuccin", "aura", "nord", "rose-pine", "dracula", "one-dark-pro", "tokyo-night", "gruvbox",
      "monokai", "night-owl", "horizon", "shades-of-purple"
    ])
    #expect(CapoUIFont.all.map(\.id) == [
      "geist", "inter", "roboto", "poppins", "nunito", "outfit", "dm-sans", "plus-jakarta-sans",
      "montserrat", "lato", "space-grotesk", "manrope"
    ])
  }

  @Test func everyTokenIsAValidHex() {
    for palette in CapoPalette.all {
      for tokens in [palette.light, palette.dark] {
        let values = [
          tokens.background, tokens.foreground, tokens.card, tokens.popover, tokens.primary,
          tokens.primaryForeground, tokens.secondary, tokens.muted, tokens.mutedForeground, tokens.accent,
          tokens.destructive, tokens.border, tokens.input, tokens.ring, tokens.chord, tokens.accentSongs,
          tokens.accentPlaylists, tokens.accentActivity, tokens.sidebar, tokens.sidebarAccent,
          tokens.sidebarBorder
        ] + Array(tokens.sectionAccents.values)
        for value in values { #expect(value.wholeMatch(of: Self.hex) != nil, "\(palette.id) \(value)") }
        #expect(tokens.sectionAccents.count == 10)
      }
    }
  }

  /// Spot checks against WEB_PARITY_ANALYSIS §5.4 for each non-default palette (light, dark).
  @Test func renderedValuesMatchTheAnalysisTables() {
    let expected: [(String, String, String, String, String)] = [
      // id, light background, light primary, dark background, dark primary
      ("aura", "#f1f2ff", "#673ad0", "#09071a", "#9d67ff"),
      ("nord", "#e9f0f7", "#3d75a2", "#132331", "#79bccd"),
      ("rose-pine", "#fcecdd", "#a2507a", "#120c22", "#e2699d"),
      ("dracula", "#f7f7f2", "#7a59c3", "#19172b", "#b995ff"),
      ("one-dark-pro", "#f3f5f8", "#0076b3", "#141a24", "#25b2e8"),
      ("tokyo-night", "#dfe0e7", "#2d46a1", "#0b091e", "#729bf8"),
      ("gruvbox", "#fff7d3", "#b01f00", "#161616", "#fd7920"),
      ("monokai", "#f8f8f8", "#d10073", "#13130f", "#f2009d"),
      ("night-owl", "#f9f9f9", "#266ed4", "#000b1b", "#9de05f"),
      ("horizon", "#ffece7", "#d32579", "#0b0b13", "#ed428e"),
      ("shades-of-purple", "#f2f0ff", "#673ad0", "#251347", "#ffd304")
    ]
    for (id, lightBg, lightPrimary, darkBg, darkPrimary) in expected {
      let palette = CapoPalette.named(id)
      #expect(palette?.light.background == lightBg, "\(id) light bg")
      #expect(palette?.light.primary == lightPrimary, "\(id) light primary")
      #expect(palette?.dark.background == darkBg, "\(id) dark bg")
      #expect(palette?.dark.primary == darkPrimary, "\(id) dark primary")
    }
    #expect(CapoPalette.nord.dark.sidebarBorder == "#1f3245")
    #expect(CapoPalette.horizon.dark.accentSongs == "#ed428e")
  }

  @Test func rosePineOverridesSectionAccentsOnly() {
    #expect(CapoPalette.rosePine.light.sectionAccents["verse"] != CapoPalette.catppuccin.light.sectionAccents["verse"])
    #expect(CapoPalette.rosePine.dark.sectionAccents["chorus"] == "#b7a1f5")
    #expect(CapoPalette.rosePine.dark.sectionAccents["verse"] == "#8cd3e4")
    #expect(CapoPalette.rosePine.light.sectionAccents["tab"] == CapoPalette.catppuccin.light.sectionAccents["tab"])
    #expect(CapoPalette.dracula.dark.sectionAccents == CapoPalette.catppuccin.dark.sectionAccents)
    #expect(CapoPalette.rosePine.light.comment == "#008687")
  }

  @Test func previewSwatchesComeFromThePicker() {
    #expect(CapoPalette.catppuccin.preview.light.background == "#eff1f5")
    #expect(CapoPalette.shadesOfPurple.preview.dark.primary == "#fad000")
    #expect(CapoPalette.rosePine.name == "Rosé Pine")
  }

  @Test func unknownIdsFallBackToDefaults() {
    #expect(CapoPalette.named("nope") == nil)
    let store = CapoPaletteStore()
    store.apply(paletteID: "nord", uiFontID: "lato")
    #expect(store.current.id == "nord" && store.uiFont.id == "lato")
    let revision = store.revision
    store.apply(paletteID: "nord", uiFontID: "lato")
    #expect(store.revision == revision)
    store.apply(paletteID: "bogus", uiFontID: nil)
    #expect(store.current.id == "catppuccin" && store.uiFont.id == "geist")
    #expect(store.revision > revision)
  }

  @Test func staticFontsPickTheNearestWeight() {
    #expect(CapoUIFont.lato.staticPostScriptName(weight: 500) == "Lato-Regular")
    #expect(CapoUIFont.lato.staticPostScriptName(weight: 600) == "Lato-Bold")
    #expect(CapoUIFont.poppins.staticPostScriptName(weight: 600) == "Poppins-SemiBold")
    #expect(CapoUIFont.geist.staticPostScriptName(weight: 900) == "Geist-Bold")
    #expect(CapoUIFont.inter.variablePostScriptName == "Inter-Variable")
  }

  @Test func bundledFontsResolveForEveryFamily() {
    CapoFonts.register()
    for font in CapoUIFont.all {
      for name in font.postScriptNames {
        let ct = CTFontCreateWithName(name as CFString, 16, nil)
        #expect(CTFontCopyPostScriptName(ct) as String == name, "\(name) not registered")
      }
    }
  }

  @Test func surpriseMeNeverRepeatsCurrentChoices() {
    var rng = SystemRandomNumberGenerator()
    for _ in 0..<50 {
      let result = CapoAppearance.surprise(
        palette: "nord", font: "inter", theme: .light, flipTheme: true, using: &rng)
      #expect(result.palette.id != "nord" && result.font.id != "inter")
      #expect(result.theme == .dark)
    }
    let settingsVersion = CapoAppearance.surprise(
      palette: nil, font: nil, theme: nil, flipTheme: false, using: &rng)
    #expect(settingsVersion.theme == nil && settingsVersion.palette.id != "catppuccin")
  }
}
