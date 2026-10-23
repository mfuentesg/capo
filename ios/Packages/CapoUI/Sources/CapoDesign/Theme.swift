import CoreText
import SwiftUI
import UIKit

// Catppuccin Latte (light) / Mocha (dark), mirroring `app/globals.css`.

public enum CapoTheme {
  static func adaptive(light: String, dark: String) -> Color {
    // Resolve both colors up front: UIKit/SwiftUI call the provider off the main thread (async render),
    // and this module defaults to MainActor isolation, which traps if the closure touches isolated state.
    let lightColor = UIColor(hex: light)
    let darkColor = UIColor(hex: dark)
    return Color(
      uiColor: UIColor { @Sendable traits in
        traits.userInterfaceStyle == .dark ? darkColor : lightColor
      })
  }

  public static let background = adaptive(light: "#e6e9ef", dark: "#1e1e2e")
  public static let card = adaptive(light: "#eff1f5", dark: "#313244")
  /// Sidebar / crust.
  public static let sidebar = adaptive(light: "#dce0e8", dark: "#181825")
  public static let text = adaptive(light: "#4c4f69", dark: "#cdd6f4")
  public static let subtext = adaptive(light: "#6c6f85", dark: "#9399b2")
  public static let surface = adaptive(light: "#ccd0da", dark: "#313244")
  public static let surfaceStrong = adaptive(light: "#bcc0cc", dark: "#45475a")
  public static let border = adaptive(light: "#bcc0cc", dark: "#45475a")
  public static let primary = adaptive(light: "#fe640b", dark: "#fab387")
  /// Selected row / nav item fill: a solid peach tint (a translucent peach over the sidebar reads muddy pink).
  public static let selection = adaptive(light: "#f9d9c6", dark: "#3d3037")
  /// Text on a peach fill; always dark for contrast.
  public static let onPrimary = Color(uiColor: UIColor(hex: "#1e1e2e"))
  public static let chord = adaptive(light: "#8839ef", dark: "#cba6f7")
  public static let chordFill = chord.opacity(0.14)
  public static let info = adaptive(light: "#1e66f5", dark: "#89b4fa")
  public static let success = adaptive(light: "#40a02b", dark: "#a6e3a1")
  public static let destructive = adaptive(light: "#d20f39", dark: "#f38ba8")
  public static let warning = adaptive(light: "#df8e1d", dark: "#f9e2af")

  /// Per-section accent (light/dark pairs from the web).
  public static func accent(for sectionType: String) -> Color {
    switch sectionType {
    case "verse": adaptive(light: "#1e66f5", dark: "#89b4fa")
    case "chorus": adaptive(light: "#8839ef", dark: "#cba6f7")
    case "bridge": adaptive(light: "#ea76cb", dark: "#f5c2e7")
    case "comment": adaptive(light: "#179299", dark: "#94e2d5")
    case "repeat": adaptive(light: "#df8e1d", dark: "#f9e2af")
    case "intro": adaptive(light: "#40a02b", dark: "#a6e3a1")
    case "outro": adaptive(light: "#04a5e5", dark: "#89dceb")
    case "pre_chorus": adaptive(light: "#ea76cb", dark: "#f5c2e7")
    default: subtext
    }
  }
}

public enum CapoRadius {
  public static let small: CGFloat = 8
  public static let medium: CGFloat = 12
  public static let large: CGFloat = 16
}

extension UIColor {
  convenience init(hex: String) {
    let c = HexColor.parse(hex) ?? (0.5, 0.5, 0.5, 1)
    self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
  }
}

// MARK: - Button styles

public struct CapoPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  public init() {}
  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(CapoFont.style(.body, weight: .semibold))
      .foregroundStyle(CapoTheme.onPrimary)
      .padding(.horizontal, 18)
      .frame(minHeight: CapoMetrics.minTouchTarget)
      .background(CapoTheme.primary, in: RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous))
      .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

public struct CapoSecondaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  public init() {}
  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(CapoFont.style(.body, weight: .medium))
      .foregroundStyle(CapoTheme.text)
      .padding(.horizontal, 18)
      .frame(minHeight: CapoMetrics.minTouchTarget)
      .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous)
          .strokeBorder(CapoTheme.border, lineWidth: 1))
      .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

public struct CapoIconButtonStyle: ButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(CapoTheme.text)
      .frame(minWidth: CapoMetrics.minTouchTarget, minHeight: CapoMetrics.minTouchTarget)
      .contentShape(Rectangle())
      .background(
        configuration.isPressed ? CapoTheme.surface : Color.clear,
        in: RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous)
      )
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

// MARK: - Modifier

private struct CapoThemeModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .tint(CapoTheme.primary)
      .font(CapoFont.style(.body))
      .foregroundStyle(CapoTheme.text)
      .background(CapoTheme.background.ignoresSafeArea())
  }
}

extension View {
  /// Applies the Catppuccin tint, text colour and page background. Does not touch the colour scheme.
  public func capoTheme() -> some View { modifier(CapoThemeModifier()) }
}

// MARK: - Font registration

public enum CapoFonts {
  private static let registered: Bool = {
    let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
    for url in urls { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    return !urls.isEmpty
  }()

  /// Registers the bundled Geist fonts with CoreText. Idempotent; returns whether any font was found.
  @discardableResult
  public static func register() -> Bool { registered }
}

// MARK: - Key badge

/// Song key pill: mauve text on a mauve 14% fill, like the web's chord pills.
public struct KeyBadge: View {
  let key: String
  public init(_ key: String) { self.key = key }

  public var body: some View {
    Text(key)
      .font(CapoFont.mono(14, weight: .bold, relativeTo: .subheadline))
      .foregroundStyle(CapoTheme.chord)
      .padding(.horizontal, 10)
      .frame(minWidth: 40, minHeight: 28)
      .background(CapoTheme.chordFill, in: RoundedRectangle(cornerRadius: CapoRadius.small, style: .continuous))
      .accessibilityLabel(key)
  }
}
