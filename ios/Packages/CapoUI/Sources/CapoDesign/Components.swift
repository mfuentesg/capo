@_exported import CapoChordPro
import SwiftUI
import UIKit

// WP5 design system. Public signatures follow PLAN §5.7.

// MARK: - Section accents

/// Section accent per section type, taken from the `--section-accent` rules in `app/globals.css`
/// (default palette), light and dark.
public enum SectionAccent {
  private static let palette: [String: (light: OKLCH, dark: OKLCH)] = [
    "verse": (OKLCH(0.48, 0.16, 248), OKLCH(0.7, 0.15, 248)),
    "chorus": (OKLCH(0.5, 0.17, 288), OKLCH(0.72, 0.16, 288)),
    "bridge": (OKLCH(0.5, 0.16, 350), OKLCH(0.7, 0.16, 350)),
    "comment": (OKLCH(0.55, 0.12, 195), OKLCH(0.68, 0.12, 195)),
    "repeat": (OKLCH(0.5, 0.16, 65), OKLCH(0.75, 0.16, 65)),
    "tab": (OKLCH(0.5, 0.01, 280), OKLCH(0.65, 0.01, 280)),
    "grid": (OKLCH(0.5, 0.01, 280), OKLCH(0.65, 0.01, 280)),
    "intro": (OKLCH(0.52, 0.15, 145), OKLCH(0.72, 0.14, 145)),
    "outro": (OKLCH(0.5, 0.14, 200), OKLCH(0.7, 0.13, 200)),
    "pre_chorus": (OKLCH(0.5, 0.15, 310), OKLCH(0.72, 0.14, 310))
  ]

  public static func color(for sectionType: String) -> Color {
    guard let entry = palette[sectionType] else { return .secondary }
    return OKLCH.dynamic(light: entry.light, dark: entry.dark)
  }

  /// Section background tint (6% light, 12% dark in the web CSS).
  public static func background(for sectionType: String) -> Color {
    color(for: sectionType).opacity(0.1)
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
      .map { isDark ? $0.opacity(0.4) : $0 } ?? Color(.tertiarySystemFill)
    let foreground: Color =
      (isDark ? style.darkForeground : style.lightForeground).flatMap { Color(hex: $0) }
      ?? .secondary
    Text(style.label)
      .font(.system(size: 11, weight: .bold))
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
    .font(.footnote.weight(.medium))
    .foregroundStyle(isSelected ? (HexColor.isLight(colorHex) ? Color.black : Color.white) : Color.primary)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(minHeight: 32)
    .background(isSelected ? color : color.opacity(0.14), in: Capsule())
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
          .font(.caption2.monospacedDigit().weight(.semibold))
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Self.label(for: status))
  }
}

// MARK: - Empty state

public struct EmptyStateView: View {
  let title: String
  let message: String?
  let systemImage: String

  public init(title: String, message: String?, systemImage: String) {
    self.title = title
    self.message = message
    self.systemImage = systemImage
  }

  public var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
    } description: {
      if let message { Text(message) }
    }
  }
}

// MARK: - Fonts

public enum CapoFont {
  public static let baseLyricsPointSize: CGFloat = 16

  /// Lyrics are 16pt x scale and ignore Dynamic Type, like the web.
  public static func lyrics(scale: Double) -> Font {
    .system(size: baseLyricsPointSize * scale)
  }

  public static func chord(scale: Double) -> Font {
    .system(size: baseLyricsPointSize * scale, weight: .bold, design: .monospaced)
  }
}

// MARK: - Shared layout constants

public enum CapoMetrics {
  /// Minimum touch target; the app is used on stage, so this is above Apple's 44pt minimum.
  public static let minTouchTarget: CGFloat = 48
  public static let cornerRadius: CGFloat = 12
}

/// Placeholder text shared by the WP0 entry-view stubs.
public struct StubScreen: View {
  let name: String
  public init(_ name: String) { self.name = name }

  public var body: some View {
    EmptyStateView(title: name, message: "Coming soon", systemImage: "hammer")
  }
}
