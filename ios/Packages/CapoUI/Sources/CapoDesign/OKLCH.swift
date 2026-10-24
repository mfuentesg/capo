import SwiftUI
import UIKit

/// OKLCH to sRGB conversion, so the iOS palette can reuse the exact `oklch(...)` values from
/// `app/globals.css`.
public struct OKLCH: Hashable, Sendable {
  public var lightness: Double
  public var chroma: Double
  public var hue: Double

  public init(_ lightness: Double, _ chroma: Double, _ hue: Double) {
    self.lightness = lightness
    self.chroma = chroma
    self.hue = hue
  }

  /// Gamut-clamped sRGB components in 0...1.
  public var srgb: (red: Double, green: Double, blue: Double) {
    let radians = hue * .pi / 180
    let a = chroma * cos(radians)
    let b = chroma * sin(radians)
    let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
    let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
    let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
    let linear = (
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    )
    func encode(_ value: Double) -> Double {
      let clamped = min(max(value, 0), 1)
      return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
    return (encode(linear.0), encode(linear.1), encode(linear.2))
  }

  /// `#rrggbb` of the clamped sRGB value.
  public var hex: String {
    let c = srgb
    func byte(_ v: Double) -> Int { Int((v * 255).rounded()) }
    return String(format: "#%02x%02x%02x", byte(c.red), byte(c.green), byte(c.blue))
  }

  public var uiColor: UIColor {
    let c = srgb
    return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
  }

  /// A colour that switches between the light and dark value with the interface style.
  public static func dynamic(light: OKLCH, dark: OKLCH) -> Color {
    Color(
      uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
      })
  }
}
