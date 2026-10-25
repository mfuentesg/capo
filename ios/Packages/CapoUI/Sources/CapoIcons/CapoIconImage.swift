import SwiftUI
import UIKit

/// Lucide icons as template images, for APIs that only take an `Image` (tab items, swipe actions,
/// menu and context-menu labels, `Label` icons). Tint them like any template image.
public enum CapoIconImage {
  private static var cache: [String: UIImage] = [:]

  /// Template `UIImage` of the icon at `size` points (3x raster, cached).
  public static func uiImage(_ name: CapoIconName, size: CGFloat = 24, strokeWidth: CGFloat = 2) -> UIImage {
    let key = "\(name.rawValue)|\(size)|\(strokeWidth)"
    if let hit = cache[key] { return hit }
    let renderer = ImageRenderer(
      content: CapoIcon(name, size: size, strokeWidth: strokeWidth).foregroundStyle(Color.black))
    renderer.scale = 3
    let image = (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysTemplate)
    cache[key] = image
    return image
  }

  /// Template `Image` of the icon.
  public static func image(_ name: CapoIconName, size: CGFloat = 24, strokeWidth: CGFloat = 2) -> Image {
    Image(uiImage: uiImage(name, size: size, strokeWidth: strokeWidth)).renderingMode(.template)
  }
}

/// `Label` with a lucide icon, usable in menus, swipe actions and tab items.
public struct CapoIconLabel: View {
  let title: String
  let icon: CapoIconName
  let size: CGFloat

  public init(_ title: String, icon: CapoIconName, size: CGFloat = 20) {
    self.title = title
    self.icon = icon
    self.size = size
  }

  public var body: some View {
    Label {
      Text(title)
    } icon: {
      CapoIconImage.image(icon, size: size)
    }
  }
}
