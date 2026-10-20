@_exported import CapoChordPro
import SwiftUI

// WP0 stubs with the §5.7 signatures. WP5 owns and restyles them.

public enum SectionAccent {
  public static func color(for sectionType: String) -> Color {
    switch sectionType {
    case "chorus": .purple
    case "verse": .blue
    case "bridge": .pink
    case "pre_chorus": .orange
    case "intro", "outro": .teal
    default: .secondary
    }
  }
}

public struct FlagBadge: View {
  let flag: SectionFlag
  public init(_ flag: SectionFlag) { self.flag = flag }

  public var body: some View {
    Text(flag.rawValue)
      .font(.caption2.weight(.semibold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(.quaternary, in: Capsule())
  }
}

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
    Text(name)
      .font(.caption)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Capsule())
  }
}

public struct SyncStatusBadge: View {
  let status: SyncStatus
  public init(status: SyncStatus) { self.status = status }

  public var body: some View {
    Image(systemName: status.phase == .offline ? "icloud.slash" : "checkmark.icloud")
      .foregroundStyle(.secondary)
  }
}

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

public enum CapoFont {
  public static let baseLyricsPointSize: CGFloat = 16

  public static func lyrics(scale: Double) -> Font {
    .system(size: baseLyricsPointSize * scale)
  }

  public static func chord(scale: Double) -> Font {
    .system(size: baseLyricsPointSize * scale, weight: .bold, design: .monospaced)
  }
}

/// Placeholder text shared by the WP0 entry-view stubs.
public struct StubScreen: View {
  let name: String
  public init(_ name: String) { self.name = name }

  public var body: some View {
    EmptyStateView(title: name, message: "Coming soon", systemImage: "hammer")
  }
}
