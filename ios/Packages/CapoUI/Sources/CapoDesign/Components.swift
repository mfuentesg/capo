@_exported import CapoChordPro
import CapoIcons
import SwiftUI
import UIKit

// WP5 design system. Public signatures follow PLAN §5.7.

// MARK: - Section accents

/// Section accent per section type, taken from the `--section-accent` rules in `app/globals.css`
/// (default palette), light and dark.
public enum SectionAccent {
  public static func color(for sectionType: String) -> Color {
    CapoTheme.accent(for: sectionType)
  }

  /// Section background tint: 6% in light mode, 12% in dark mode.
  public static func background(for sectionType: String) -> Color {
    CapoTheme.sectionBackground(for: sectionType)
  }
}

// MARK: - Flag badge

/// Mirrors `FLAG_CONFIG` in `features/lyrics-editor/components/rendered-song.tsx`.
public struct FlagBadge: View {
  let flag: SectionFlag
  @Environment(\.colorScheme) private var scheme

  public init(_ flag: SectionFlag) { self.flag = flag }

  struct Style: Equatable {
    var label: String
    var italic: Bool
    var lightBackground: String?
    var lightForeground: String?
    var darkBackground: String?
    var darkForeground: String?
  }

  static func style(for flag: SectionFlag) -> Style {
    switch flag {
    case .attention:
      Style(label: "!", italic: false, lightBackground: "#fef3c7", lightForeground: "#b45309", darkBackground: "#78350f", darkForeground: "#fbbf24")
    case .skip: Style(label: "skip", italic: false)
    case .forte:
      Style(label: "f", italic: true, lightBackground: "#fee2e2", lightForeground: "#b91c1c", darkBackground: "#7f1d1d", darkForeground: "#f87171")
    case .piano:
      Style(label: "p", italic: true, lightBackground: "#dbeafe", lightForeground: "#1d4ed8", darkBackground: "#1e3a8a", darkForeground: "#60a5fa")
    case .vamp:
      Style(label: "vamp", italic: false, lightBackground: "#f3e8ff", lightForeground: "#7e22ce", darkBackground: "#581c87", darkForeground: "#c084fc")
    case .tag:
      Style(label: "tag", italic: false, lightBackground: "#dcfce7", lightForeground: "#15803d", darkBackground: "#14532d", darkForeground: "#4ade80")
    case .break: Style(label: "break", italic: false)
    case .inline: Style(label: "inline", italic: false)
    case .label: Style(label: "label", italic: false)
    }
  }

  public var body: some View {
    let style = Self.style(for: flag)
    let isDark = scheme == .dark
    let background: Color =
      (isDark ? style.darkBackground : style.lightBackground).flatMap { Color(hex: $0) }
      .map { isDark ? $0.opacity(0.4) : $0 } ?? CapoTheme.surface
    let foreground: Color =
      (isDark ? style.darkForeground : style.lightForeground).flatMap { Color(hex: $0) }
      ?? CapoTheme.subtext
    Text(style.label)
      .font(CapoFont.ui(11, weight: .bold, relativeTo: .caption2))
      .italic(style.italic)
      .textCase(.uppercase)
      .tracking(0.4)
      .foregroundStyle(foreground)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
      .accessibilityLabel(flag.rawValue)
  }
}

// MARK: - Tag chip

public struct TagChip: View {
  let name: String
  let colorHex: String?
  let isSelected: Bool

  public init(name: String, colorHex: String?, isSelected: Bool = false) {
    self.name = name
    self.colorHex = colorHex
    self.isSelected = isSelected
  }

  public var body: some View {
    let color = HexColor.tagColor(colorHex)
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(name).lineLimit(1)
    }
    .font(CapoFont.style(.footnote, weight: .medium))
    .foregroundStyle(isSelected ? (HexColor.isLight(colorHex) ? Color.black : Color.white) : CapoTheme.text)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(minHeight: 32)
    .background(isSelected ? color : color.opacity(0.18), in: Capsule())
    .overlay(Capsule().strokeBorder(color.opacity(isSelected ? 0 : 0.35), lineWidth: 1))
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

// MARK: - Sync status

public struct SyncStatusBadge: View {
  let status: SyncStatus
  public init(status: SyncStatus) { self.status = status }

  static func symbol(for status: SyncStatus) -> (name: String, tint: Color) {
    if status.conflicts > 0 { return ("exclamationmark.arrow.triangle.2.circlepath", .orange) }
    if status.failedOperations > 0 { return ("exclamationmark.icloud", .red) }
    switch status.phase {
    case .idle:
      return status.pendingOperations > 0
        ? ("icloud.and.arrow.up", .secondary) : ("checkmark.icloud", .secondary)
    case .pushing: return ("icloud.and.arrow.up", .accentColor)
    case .pulling: return ("icloud.and.arrow.down", .accentColor)
    case .offline: return ("icloud.slash", .orange)
    case .error: return ("exclamationmark.icloud", .red)
    }
  }

  public static func label(for status: SyncStatus) -> String {
    switch status.phase {
    case .idle:
      status.pendingOperations > 0
        ? L10n.Ios.Sync.pending
        : L10n.Ios.Sync.upToDate
    case .pushing, .pulling:
      L10n.Ios.Sync.syncing
    case .offline:
      L10n.Ios.Sync.offline
    case .error:
      L10n.Ios.Sync.error
    }
  }

  public var body: some View {
    let symbol = Self.symbol(for: status)
    HStack(spacing: 4) {
      Image(systemName: symbol.name)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(symbol.tint)
        .symbolEffect(.pulse, isActive: status.phase == .pushing || status.phase == .pulling)
      if status.pendingOperations > 0 {
        Text("\(status.pendingOperations)")
          .font(CapoFont.style(.caption2, weight: .semibold).monospacedDigit())
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.label(for: status))
  }
}

// MARK: - Empty state

/// The web's `Empty` block (`components/ui/empty.tsx`): a 40px tinted icon tile, a medium title and a
/// muted description. `tint` colours the tile (default: muted); `bordered` adds the dashed outline.
public struct EmptyStateView: View {
  /// The tile glyph: the web uses a lucide icon; SF Symbols remain for screens not yet converted.
  enum Glyph { case system(String), lucide(CapoIconName) }

  @Environment(\.capoUIScale) private var scale
  let title: String
  let message: String?
  let glyph: Glyph
  let tint: Color?
  let bordered: Bool

  public init(
    title: String, message: String?, systemImage: String, tint: Color? = nil, bordered: Bool = false
  ) {
    self.init(title: title, message: message, glyph: .system(systemImage), tint: tint, bordered: bordered)
  }

  /// Same block with a lucide icon, as on the web (`<EmptyMedia variant="icon"><Icon/></EmptyMedia>`).
  public init(
    title: String, message: String?, icon: CapoIconName, tint: Color? = nil, bordered: Bool = false
  ) {
    self.init(title: title, message: message, glyph: .lucide(icon), tint: tint, bordered: bordered)
  }

  init(title: String, message: String?, glyph: Glyph, tint: Color?, bordered: Bool) {
    self.title = title
    self.message = message
    self.glyph = glyph
    self.tint = tint
    self.bordered = bordered
  }

  @ViewBuilder private var glyphView: some View {
    switch glyph {
    case .system(let name): Image(systemName: name).font(.system(size: 24 * scale, weight: .regular))
    case .lucide(let icon): CapoIcon(icon, size: 24 * scale)
    }
  }

  public var body: some View {
    let tile = RoundedRectangle(cornerRadius: CapoRadius.base * scale, style: .continuous)
    VStack(spacing: 16) {
      glyphView
        .foregroundStyle(tint ?? CapoTheme.foreground)
        .frame(width: 40 * scale, height: 40 * scale)
        .background(tint.map { $0.opacity(0.10) } ?? CapoTheme.muted, in: tile)
        .overlay { if let tint { tile.strokeBorder(tint.opacity(0.20), lineWidth: 1) } }
        .accessibilityHidden(true)
      VStack(spacing: 4) {
        Text(title)
          .capoText(.lg, weight: .medium, tracking: -0.025)
          .multilineTextAlignment(.center)
        if let message {
          Text(message)
            .capoText(.sm)
            .foregroundStyle(CapoTheme.mutedForeground)
            .multilineTextAlignment(.center)
        }
      }
    }
    .padding(24)
    .frame(maxWidth: .infinity)
    .overlay {
      if bordered {
        RoundedRectangle(cornerRadius: CapoRadius.base * scale, style: .continuous)
          .strokeBorder(CapoTheme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
      }
    }
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Fonts

public enum CapoFont {
  public static let baseLyricsPointSize: CGFloat = 16

  static func postScriptName(_ weight: Font.Weight, mono: Bool = false) -> String {
    // Only Regular and Bold ship for Geist Mono; medium maps to regular, semibold and above to bold.
    if mono { return weight == .bold || weight == .semibold || weight == .heavy || weight == .black ? "GeistMono-Bold" : "GeistMono-Regular" }
    let font = CapoUIFontStorage.current
    return font.staticPostScriptName(weight: CapoUIFontFactory.numericWeight(weight))
      ?? CapoUIFont.geist.staticPostScriptName(weight: CapoUIFontFactory.numericWeight(weight)) ?? "Geist-Regular"
  }

  /// The selected UI font (Geist by default) at `size`, scaling with Dynamic Type relative to `textStyle`.
  public static func ui(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
    CapoFonts.register()
    let selected = CapoUIFontStorage.current
    if let variable = selected.variablePostScriptName {
      let scaled = UIFontMetrics(forTextStyle: textStyle.uiTextStyle).scaledValue(for: size)
      return Font(
        CapoUIFontFactory.variableFont(
          postScriptName: variable, weight: CapoUIFontFactory.numericWeight(weight), size: scaled))
    }
    return .custom(postScriptName(weight), size: size, relativeTo: textStyle)
  }

  /// `family` at a fixed `size`, regardless of the selected UI font (picker samples).
  public static func font(_ family: CapoUIFont, size: CGFloat, weight: Font.Weight = .regular) -> Font {
    CapoFonts.register()
    let numeric = CapoUIFontFactory.numericWeight(weight)
    if let variable = family.variablePostScriptName {
      return Font(CapoUIFontFactory.variableFont(postScriptName: variable, weight: numeric, size: size))
    }
    return .custom(family.staticPostScriptName(weight: numeric) ?? "Geist-Regular", fixedSize: size)
  }

  /// Geist Mono at `size`, scaling with Dynamic Type.
  public static func mono(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
    CapoFonts.register()
    return .custom(postScriptName(weight, mono: true), size: size, relativeTo: textStyle)
  }

  /// UI-font equivalent of a system text style (same point sizes).
  public static func style(_ textStyle: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
    let (size, defaultWeight): (CGFloat, Font.Weight) = switch textStyle {
    case .largeTitle: (34, .bold)
    case .title: (28, .bold)
    case .title2: (22, .bold)
    case .title3: (20, .semibold)
    case .headline: (17, .semibold)
    case .callout: (16, .regular)
    case .subheadline: (15, .regular)
    case .footnote: (13, .regular)
    case .caption: (12, .regular)
    case .caption2: (11, .regular)
    default: (17, .regular)
    }
    return ui(size, weight: weight ?? defaultWeight, relativeTo: textStyle)
  }

  /// Lyrics are Geist Mono (`<pre>` uses `--font-mono` on the web), 16pt x scale, ignoring Dynamic Type.
  public static func lyrics(scale: Double) -> Font {
    CapoFonts.register()
    return .custom("GeistMono-Regular", fixedSize: baseLyricsPointSize * scale)
  }

  public static func chord(scale: Double) -> Font {
    CapoFonts.register()
    return .custom("GeistMono-Bold", fixedSize: baseLyricsPointSize * scale)
  }
}

// MARK: - Shared layout constants

public enum CapoMetrics {
  /// Minimum touch target; the app is used on stage, so this is above Apple's 44pt minimum.
  public static let minTouchTarget: CGFloat = 48
  /// Hit area for controls whose visual size follows the web (h-8 / h-9 buttons).
  public static let minHitTarget: CGFloat = 44
  public static let cornerRadius: CGFloat = CapoRadius.medium
}

/// Placeholder text shared by the WP0 entry-view stubs.
public struct StubScreen: View {
  let name: String
  public init(_ name: String) { self.name = name }

  public var body: some View {
    EmptyStateView(title: name, message: "Coming soon", systemImage: "hammer")
  }
}

extension Font.TextStyle {
  var uiTextStyle: UIFont.TextStyle {
    switch self {
    case .largeTitle: .largeTitle
    case .title: .title1
    case .title2: .title2
    case .title3: .title3
    case .headline: .headline
    case .subheadline: .subheadline
    case .callout: .callout
    case .footnote: .footnote
    case .caption: .caption1
    case .caption2: .caption2
    default: .body
    }
  }
}
