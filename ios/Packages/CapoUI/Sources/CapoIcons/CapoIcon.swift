import SwiftUI

/// Lucide icon outline as a `Shape`, scaled from lucide's 24x24 grid to the proposed rect.
/// Stroke it with round caps and joins (see `CapoIcon`).
public nonisolated struct CapoIconShape: Shape {
  public let name: CapoIconName

  public init(_ name: CapoIconName) { self.name = name }

  public func path(in rect: CGRect) -> Path {
    let side = min(rect.width, rect.height)
    let scale = side / CapoIconName.grid
    let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
    return CapoIconName.cachedPath(for: name)
      .applying(CGAffineTransform(scaleX: scale, y: scale))
      .offsetBy(dx: origin.x, dy: origin.y)
  }
}

nonisolated extension CapoIconName {
  /// Lucide's design grid.
  public static let grid: CGFloat = 24

  /// Icon used when a stored name is unknown (the web falls back to `Users`).
  public static let fallback: CapoIconName = .users

  /// Resolves a stored lucide component name (`teams.icon`, e.g. "Guitar"); nil if unknown.
  public static func lookup(_ name: String?) -> CapoIconName? {
    guard let name else { return nil }
    return CapoIconName(rawValue: name)
  }

  /// Resolves a stored lucide component name, falling back to `.users`.
  public static func named(_ name: String?) -> CapoIconName { lookup(name) ?? fallback }

  /// Parsed path on the 24 grid.
  public var path: Path { Self.cachedPath(for: self) }

  fileprivate static func cachedPath(for name: CapoIconName) -> Path {
    cache.withLock { store in
      if let hit = store[name] { return hit }
      let parsed = SVGPathParser.path(from: name.pathData)
      store[name] = parsed
      return parsed
    }
  }

  private static let cache = PathCache()
}

private nonisolated final class PathCache: @unchecked Sendable {
  private let lock = NSLock()
  private var store: [CapoIconName: Path] = [:]

  func withLock<T>(_ body: (inout [CapoIconName: Path]) -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body(&store)
  }
}

/// Crisp lucide icon. Tint with `.foregroundStyle`; stroke is `strokeWidth` on the 24 grid, scaled with
/// `size` exactly like the web's SVG (2 px at 24, 1.33 px at 16), round caps and joins.
///
///     CapoIcon(.users, size: 18).foregroundStyle(.secondary)
///     CapoIcon.named(team.icon, size: 20)
public struct CapoIcon: View {
  public let name: CapoIconName
  public let size: CGFloat
  public let strokeWidth: CGFloat

  public init(_ name: CapoIconName, size: CGFloat = 16, strokeWidth: CGFloat = 2) {
    self.name = name
    self.size = size
    self.strokeWidth = strokeWidth
  }

  /// Builds an icon from a stored lucide name; unknown or nil names render the fallback icon.
  public static func named(_ name: String?, size: CGFloat = 16, strokeWidth: CGFloat = 2) -> CapoIcon {
    CapoIcon(CapoIconName.named(name), size: size, strokeWidth: strokeWidth)
  }

  public var body: some View {
    CapoIconShape(name)
      .stroke(
        style: StrokeStyle(
          lineWidth: strokeWidth * size / CapoIconName.grid, lineCap: .round, lineJoin: .round)
      )
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}
