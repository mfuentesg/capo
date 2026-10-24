import SwiftUI

/// The web sets `html { font-size: 17px }` at >= 768 px, so every rem value (type, spacing, radii) is
/// multiplied by 1.0625 on tablet-width containers. Lyrics are px-based and unaffected.
public enum CapoScale {
  public static let tabletBreakpoint: CGFloat = 768
  public static let tabletFactor: CGFloat = 17.0 / 16.0

  /// UI scale for a container of the given width (points).
  public static func factor(forWidth width: CGFloat) -> CGFloat {
    width >= tabletBreakpoint ? tabletFactor : 1
  }
}

extension EnvironmentValues {
  /// Multiplier for rem-based UI metrics; set by `capoTheme()` from the container width.
  @Entry public var capoUIScale: CGFloat = 1
}

/// Tailwind text sizes in phone px (rem x 16), with their line-height multipliers.
public enum CapoTextSize: CaseIterable, Sendable {
  case px9, px10, px11, px12
  case xs, sm, base, lg, xl, xl2, xl3, xl4

  public var size: CGFloat {
    switch self {
    case .px9: 9
    case .px10: 10
    case .px11: 11
    case .px12, .xs: 12
    case .sm: 14
    case .base: 16
    case .lg: 18
    case .xl: 20
    case .xl2: 24
    case .xl3: 30
    case .xl4: 36
    }
  }

  /// Line height as a multiple of the size (nil for the fixed-px badge sizes).
  public var lineHeight: CGFloat? {
    switch self {
    case .px9, .px10, .px11, .px12: nil
    case .xs: 16.0 / 12
    case .sm: 20.0 / 14
    case .base: 1.5
    case .lg: 28.0 / 18
    case .xl: 28.0 / 20
    case .xl2: 32.0 / 24
    case .xl3: 1.2
    case .xl4: 40.0 / 36
    }
  }

  /// The Dynamic Type style the size scales with.
  var textStyle: Font.TextStyle {
    switch self {
    case .px9, .px10, .px11, .px12, .xs: .caption
    case .sm: .subheadline
    case .base: .body
    case .lg: .title3
    case .xl: .title3
    case .xl2: .title2
    case .xl3: .title
    case .xl4: .largeTitle
    }
  }
}

extension CapoFont {
  /// Geist at a Tailwind text size. `scale` is `\.capoUIScale` (1 phone, 1.0625 tablet); the fixed-px
  /// badge sizes (`px9`...`px12`) do not scale because the web writes them in px.
  public static func web(_ size: CapoTextSize, weight: Font.Weight = .regular, scale: CGFloat = 1) -> Font {
    let factor = size.lineHeight == nil ? 1 : scale
    return ui(size.size * factor, weight: weight, relativeTo: size.textStyle)
  }
}

private struct CapoTextModifier: ViewModifier {
  @Environment(\.capoUIScale) private var scale
  let size: CapoTextSize
  let weight: Font.Weight
  let tracking: CGFloat

  func body(content: Content) -> some View {
    let factor = size.lineHeight == nil ? 1 : scale
    let points = size.size * factor
    // Geist's natural line height is roughly 1.2 em; add the difference up to the Tailwind leading.
    let extra = max(0, ((size.lineHeight ?? 1.2) - 1.2) * points)
    content
      .font(CapoFont.web(size, weight: weight, scale: scale))
      .tracking(tracking * points)
      .lineSpacing(extra)
  }
}

extension View {
  /// Applies a Tailwind text size at the current UI scale. `tracking` is in em (for example -0.025).
  public func capoText(_ size: CapoTextSize, weight: Font.Weight = .regular, tracking: CGFloat = 0) -> some View {
    modifier(CapoTextModifier(size: size, weight: weight, tracking: tracking))
  }
}
