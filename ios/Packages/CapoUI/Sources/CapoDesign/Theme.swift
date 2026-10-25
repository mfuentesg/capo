import CoreText
import SwiftUI
import UIKit

// Colour tokens come from `CapoPalette` (the web's rendered values); see Palette.swift.

public enum CapoTheme {
  /// Fixed light/dark pair, independent of the current palette.
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

  /// A palette token that follows both the interface style and the current palette.
  public static func token(_ keyPath: KeyPath<CapoPalette.Tokens, String> & Sendable) -> Color {
    Color(uiColor: tokenUIColor(keyPath))
  }

  static func tokenUIColor(
    _ keyPath: KeyPath<CapoPalette.Tokens, String> & Sendable, alpha: [Double] = [1, 1]
  ) -> UIColor {
    UIColor { @Sendable traits in
      let isDark = traits.userInterfaceStyle == .dark
      let tokens = CapoPaletteStorage.current.tokens(dark: isDark)
      return UIColor(hex: tokens[keyPath: keyPath]).withAlphaComponent(alpha[isDark ? 1 : 0])
    }
  }

  public static let background = token(\.background)
  public static let card = token(\.card)
  public static let popover = token(\.popover)
  /// Sidebar (unused by the web layout; kept for the iOS sidebar).
  public static let sidebar = token(\.sidebar)
  public static let sidebarAccent = token(\.sidebarAccent)
  public static let sidebarBorder = token(\.sidebarBorder)
  /// `--foreground`.
  public static let foreground = token(\.foreground)
  /// Primary text (alias of `foreground`).
  public static let text = foreground
  /// `--muted-foreground`.
  public static let mutedForeground = token(\.mutedForeground)
  /// Secondary text (alias of `mutedForeground`).
  public static let subtext = mutedForeground
  /// `--secondary` (also `--accent` in the default palette): active nav fill, hover fills.
  public static let secondary = token(\.secondary)
  public static let muted = token(\.muted)
  public static let accent = token(\.accent)
  /// Alias of `secondary`.
  public static let surface = secondary
  /// Alias of `border`.
  public static let surfaceStrong = token(\.border)
  public static let border = token(\.border)
  public static let input = token(\.input)
  public static let ring = token(\.ring)
  public static let primary = token(\.primary)
  /// `--primary-foreground`: light in light mode, the dark background in dark mode.
  public static let primaryForeground = token(\.primaryForeground)
  /// Alias of `primaryForeground`.
  public static let onPrimary = primaryForeground
  /// Selected row / active nav item fill. The web uses `secondary` for active nav items.
  public static let selection = secondary
  public static let chord = token(\.chord)
  /// `.clp-col .chord` badge background: chord colour at 12%.
  public static let chordFill = chord.opacity(0.12)
  /// `--accent-songs` (also the "info" tone).
  public static let accentSongs = token(\.accentSongs)
  public static let accentPlaylists = token(\.accentPlaylists)
  public static let accentActivity = token(\.accentActivity)
  public static let info = accentSongs
  public static let success = accentActivity
  public static let destructive = token(\.destructive)
  public static let warning = token(\.warning)

  /// Per-section accent (light/dark pairs from the web).
  public static func accent(for sectionType: String) -> Color {
    Color(uiColor: accentUIColor(for: sectionType, alpha: [1, 1]))
  }

  /// Section block background: the accent at 6% in light mode and 12% in dark mode.
  public static func sectionBackground(for sectionType: String) -> Color {
    Color(uiColor: accentUIColor(for: sectionType, alpha: [0.06, 0.12]))
  }

  private static func accentUIColor(for sectionType: String, alpha: [Double]) -> UIColor {
    UIColor { @Sendable traits in
      let isDark = traits.userInterfaceStyle == .dark
      let tokens = CapoPaletteStorage.current.tokens(dark: isDark)
      let hex = tokens.sectionAccents[sectionType] ?? tokens.mutedForeground
      return UIColor(hex: hex).withAlphaComponent(alpha[isDark ? 1 : 0])
    }
  }
}

/// Radii from `--radius: 0.65rem` (phone px; the tablet root scale multiplies them by 1.0625).
public enum CapoRadius {
  /// `rounded-sm` (r - 4).
  public static let sm: CGFloat = 6.4
  /// `rounded-md` (r - 2): buttons, inputs, menu items.
  public static let md: CGFloat = 8.4
  /// `rounded-lg` (r): cards, alerts, dialogs.
  public static let base: CGFloat = 10.4
  /// `rounded-xl` (r + 4): list rows, settings cards.
  public static let xl: CGFloat = 14.4
  /// `rounded-2xl`: panels, floating control bars.
  public static let xxl: CGFloat = 16

  /// Previous names, now mapped onto the web scale: small = md, medium = xl, large = 2xl.
  public static let small: CGFloat = md
  public static let medium: CGFloat = xl
  public static let large: CGFloat = xxl
}

nonisolated extension UIColor {
  convenience init(hex: String) {
    let c = HexColor.parse(hex) ?? (0.5, 0.5, 0.5, 1)
    self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
  }
}

// MARK: - Button styles

/// Visual heights from `components/ui/button.tsx` (h-9, h-8, h-10, xs h-6). The hit area is always at
/// least `CapoMetrics.minHitTarget` tall; the extra area is invisible.
public enum CapoButtonSize: Sendable {
  case extraSmall, regular, small, large

  var height: CGFloat {
    switch self {
    case .extraSmall: 24
    case .regular: 36
    case .small: 32
    case .large: 40
    }
  }

  var horizontalPadding: CGFloat {
    switch self {
    case .extraSmall: 8
    case .small: 12
    case .regular: 16
    case .large: 24
    }
  }

  /// `text-xs` for the xs button, `text-sm` otherwise.
  var textSize: CapoTextSize { self == .extraSmall ? .xs : .sm }
}

private struct CapoButtonChrome: ViewModifier {
  @Environment(\.capoUIScale) private var scale
  let size: CapoButtonSize

  func body(content: Content) -> some View {
    let height = size.height * scale
    let extra = max(0, (CapoMetrics.minHitTarget - height) / 2)
    content
      .capoText(size.textSize, weight: .medium)
      .lineLimit(1)
      .padding(.horizontal, size.horizontalPadding * scale)
      .frame(minHeight: height)
      // Grow the hit area to 44pt without growing the layout.
      .padding(.vertical, extra)
      .contentShape(Rectangle())
      .padding(.vertical, -extra)
  }
}

public struct CapoPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.capoUIScale) private var scale
  let size: CapoButtonSize
  public init(size: CapoButtonSize = .regular) { self.size = size }
  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(CapoTheme.primaryForeground)
      .modifier(CapoButtonChrome(size: size))
      .background(CapoTheme.primary, in: RoundedRectangle(cornerRadius: CapoRadius.md * scale, style: .continuous))
      .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.5)
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// The web's `outline` variant: background fill, 1px border, `shadow-xs`. In dark mode the fill is
/// `input/30` (`dark:bg-input/30`, hover `input/50`).
public struct CapoSecondaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.capoUIScale) private var scale
  @Environment(\.colorScheme) private var colorScheme
  let size: CapoButtonSize
  public init(size: CapoButtonSize = .regular) { self.size = size }
  public func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: CapoRadius.md * scale, style: .continuous)
    configuration.label
      .foregroundStyle(CapoTheme.foreground)
      .modifier(CapoButtonChrome(size: size))
      .background(fill(pressed: configuration.isPressed), in: shape)
      .overlay(shape.strokeBorder(CapoTheme.input, lineWidth: 1))
      .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
      .opacity(isEnabled ? 1 : 0.5)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }

  private func fill(pressed: Bool) -> Color {
    if colorScheme == .dark { return CapoTheme.input.opacity(pressed ? 0.5 : 0.3) }
    return pressed ? CapoTheme.accent : CapoTheme.background
  }
}

/// The web's `ghost` variant: transparent until pressed, then the accent fill (`accent/50` in dark).
public struct CapoGhostButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.capoUIScale) private var scale
  @Environment(\.colorScheme) private var colorScheme
  let size: CapoButtonSize
  public init(size: CapoButtonSize = .regular) { self.size = size }
  public func makeBody(configuration: Configuration) -> some View {
    let shape = RoundedRectangle(cornerRadius: CapoRadius.md * scale, style: .continuous)
    let pressed = CapoTheme.accent.opacity(colorScheme == .dark ? 0.5 : 1)
    configuration.label
      .foregroundStyle(CapoTheme.foreground)  // accent-foreground equals foreground in every palette
      .modifier(CapoButtonChrome(size: size))
      .background(configuration.isPressed ? pressed : Color.clear, in: shape)
      .opacity(isEnabled ? 1 : 0.5)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// The web's `destructive` variant (`dark:bg-destructive/60`).
public struct CapoDestructiveButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.capoUIScale) private var scale
  @Environment(\.colorScheme) private var colorScheme
  let size: CapoButtonSize
  public init(size: CapoButtonSize = .regular) { self.size = size }
  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(Color.white)
      .modifier(CapoButtonChrome(size: size))
      .background(
        CapoTheme.destructive.opacity(colorScheme == .dark ? 0.6 : 1),
        in: RoundedRectangle(cornerRadius: CapoRadius.md * scale, style: .continuous)
      )
      .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.5)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

public struct CapoIconButtonStyle: ButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(CapoTheme.foreground)
      .frame(minWidth: CapoMetrics.minHitTarget, minHeight: CapoMetrics.minHitTarget)
      .contentShape(Rectangle())
      .background(
        configuration.isPressed ? CapoTheme.accent : Color.clear,
        in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
      )
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

// MARK: - Text field

private struct CapoFieldModifier: ViewModifier {
  @Environment(\.capoUIScale) private var scale
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: CapoRadius.md * scale, style: .continuous)
    content
      .capoText(.sm)
      .padding(.horizontal, 12 * scale)
      .frame(minHeight: CapoMetrics.minHitTarget)
      // components/ui/input.tsx: transparent, `dark:bg-input/30`, 1px `border-input`, shadow-xs.
      .background(colorScheme == .dark ? CapoTheme.input.opacity(0.3) : Color.clear, in: shape)
      .overlay(shape.strokeBorder(CapoTheme.input, lineWidth: 1))
      .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
      .opacity(isEnabled ? 1 : 0.5)
  }
}

extension View {
  /// The web `Input` chrome for a `TextField` or a menu-style picker label.
  public func capoField() -> some View { modifier(CapoFieldModifier()) }
}

// MARK: - Modifier

private struct CapoWidthKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct CapoThemeModifier: ViewModifier {
  @State private var width: CGFloat = 0
  let refreshOnChange: Bool
  var palette: CapoPalette { CapoPaletteStore.shared.current }

  func body(content: Content) -> some View {
    content
      .id(refreshOnChange ? CapoPaletteStore.shared.revision : 0)
      .environment(\.capoPalette, palette)
      .environment(\.capoUIScale, CapoScale.factor(forWidth: width))
      .tint(CapoTheme.primary)
      .font(CapoFont.style(.body))
      .foregroundStyle(CapoTheme.foreground)
      .background(GeometryReader { Color.clear.preference(key: CapoWidthKey.self, value: $0.size.width) })
      .onPreferenceChange(CapoWidthKey.self) { width = $0 }
      .background(CapoTheme.background.ignoresSafeArea())
  }
}

extension View {
  /// Applies the palette tint, text colour, page background and the tablet UI scale (17px root at
  /// >= 768pt wide). Does not touch the colour scheme.
  ///
  /// A palette or UI-font change re-creates the content (root refresh). Pass `refreshOnChange: false` for a
  /// screen that re-keys only part of itself on `CapoPaletteStore.shared.revision` (Settings keeps its
  /// scroll position that way).
  public func capoTheme(refreshOnChange: Bool = true) -> some View {
    modifier(CapoThemeModifier(refreshOnChange: refreshOnChange))
  }
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

/// Song key pill (`lib/badge-colors.ts`): Geist Mono, `accent-songs` text on a 10% fill with a 30% border.
public struct KeyBadge: View {
  let key: String
  public init(_ key: String) { self.key = key }

  public var body: some View {
    Text(key)
      .font(CapoFont.mono(12, weight: .medium, relativeTo: .caption))
      .foregroundStyle(CapoTheme.accentSongs)
      .padding(.horizontal, 8)
      .frame(minWidth: 32, minHeight: 24)
      .background(CapoTheme.accentSongs.opacity(0.10), in: Capsule())
      .overlay(Capsule().strokeBorder(CapoTheme.accentSongs.opacity(0.30), lineWidth: 1))
      .accessibilityLabel(key)
  }
}
