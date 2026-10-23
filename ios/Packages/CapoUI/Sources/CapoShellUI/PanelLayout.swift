import CapoDesign
import CoreGraphics
import Foundation

/// Persisted layout of the library list/detail split on regular width (the web's `ResizablePanel`).
struct SplitLayout: Equatable, RawRepresentable {
  static let defaultFraction = 0.35
  static let minListWidth: CGFloat = 280
  static let minDetailWidth: CGFloat = 360

  var listFraction: Double = SplitLayout.defaultFraction
  var isListCollapsed = false

  init(listFraction: Double = SplitLayout.defaultFraction, isListCollapsed: Bool = false) {
    self.listFraction = listFraction
    self.isListCollapsed = isListCollapsed
  }

  /// "fraction,collapsed" so it can live in `@AppStorage`.
  init?(rawValue: String) {
    let parts = rawValue.split(separator: ",")
    guard parts.count == 2, let fraction = Double(parts[0]), fraction.isFinite else { return nil }
    self.init(listFraction: min(max(fraction, 0.05), 0.95), isListCollapsed: parts[1] == "1")
  }

  var rawValue: String { "\(listFraction),\(isListCollapsed ? 1 : 0)" }

  /// Width of the list column inside `total`: fraction clamped to [280, total - 360]; 0 when collapsed.
  func listWidth(total: CGFloat) -> CGFloat {
    guard !isListCollapsed, total > 0 else { return 0 }
    return Self.clamp(CGFloat(listFraction) * total, total: total)
  }

  static func clamp(_ width: CGFloat, total: CGFloat) -> CGFloat {
    let upper = max(minListWidth, total - minDetailWidth)
    return min(max(width, minListWidth), upper)
  }

  /// Applies a drag that put the divider at `width`.
  mutating func setListWidth(_ width: CGFloat, total: CGFloat) {
    guard total > 0 else { return }
    listFraction = Double(Self.clamp(width, total: total) / total)
  }

  mutating func toggleList() { isListCollapsed.toggle() }
}

enum SidebarMetrics {
  static let expandedWidth: CGFloat = 264
  static let railWidth: CGFloat = 84
  static func width(collapsed: Bool) -> CGFloat { collapsed ? railWidth : expandedWidth }
}

/// Strings for the collapsible panels (en/es). Kept local to avoid regenerating the shared catalog.
enum PanelStrings {
  static var collapseSidebar: String { L10n.Ios.Shell.collapseSidebar }
  static var expandSidebar: String { L10n.Ios.Shell.expandSidebar }
  static var collapseList: String { L10n.Ios.Shell.collapseList }
  static var expandList: String { L10n.Ios.Shell.expandList }
}
