import SwiftUI
import UIKit

extension Color {
  /// Parses `#rgb`, `#rrggbb` or `#rrggbbaa` (leading `#` optional). Returns nil when invalid.
  public init?(hex: String) {
    guard let rgba = HexColor.parse(hex) else { return nil }
    self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
  }
}

public enum HexColor {
  public nonisolated static let fallback = "#6b7280"

  public nonisolated static func parse(_ hex: String) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
    var text = hex.trimmingCharacters(in: .whitespaces)
    if text.hasPrefix("#") { text.removeFirst() }
    if text.count == 3 { text = text.map { "\($0)\($0)" }.joined() }
    guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
    let hasAlpha = text.count == 8
    let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
    let g = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
    let b = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
    let a = hasAlpha ? Double(value & 0xFF) / 255 : 1
    return (r, g, b, a)
  }

  /// Tag colour with the web default (`#6b7280`) when nil or invalid.
  public static func tagColor(_ hex: String?) -> Color {
    Color(hex: hex ?? fallback) ?? Color(hex: fallback) ?? .gray
  }

  /// Perceived luminance, used to pick a readable foreground for a solid tag colour.
  public static func isLight(_ hex: String?) -> Bool {
    guard let c = parse(hex ?? fallback) ?? parse(fallback) else { return false }
    return 0.299 * c.red + 0.587 * c.green + 0.114 * c.blue > 0.6
  }
}
