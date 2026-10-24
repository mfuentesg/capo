import CapoDesign
import CapoIcons
import SwiftUI

/// Selected / unselected chrome shared by the option cards (`border-primary/60 bg-primary/8 ring-1
/// ring-primary/40` vs `border-border bg-muted/40`).
private struct OptionCardChrome: ViewModifier {
  let selected: Bool
  let radius: CGFloat
  var fill: Bool = true

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
    content
      .background(
        fill ? (selected ? CapoTheme.primary.opacity(0.08) : CapoTheme.muted.opacity(0.4)) : Color.clear,
        in: shape
      )
      .overlay(shape.strokeBorder(selected ? CapoTheme.primary.opacity(0.6) : CapoTheme.border, lineWidth: 1))
      .overlay {
        if selected { shape.inset(by: 1).strokeBorder(CapoTheme.primary.opacity(0.4), lineWidth: 1) }
      }
      .clipShape(shape)
      .contentShape(shape)
  }
}

extension View {
  func optionCard(selected: Bool, radius: CGFloat, fill: Bool = true) -> some View {
    modifier(OptionCardChrome(selected: selected, radius: radius, fill: fill))
  }
}

/// The 4 pt active bar at the bottom of a selected card.
private struct ActiveBar: View {
  let scale: CGFloat
  var body: some View {
    Capsule().fill(CapoTheme.primary)
      .frame(width: 16 * scale, height: 4 * scale)
      .padding(.bottom, 6 * scale)
  }
}

extension View {
  fileprivate func activeBar(_ selected: Bool, scale: CGFloat) -> some View {
    overlay(alignment: .bottom) { if selected { ActiveBar(scale: scale) } }
  }
}

struct PaletteCard: View {
  @Environment(\.capoUIScale) private var scale
  let palette: CapoPalette
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          swatch(palette.preview.light)
          Color.gray.opacity(0.2).frame(width: 1)
          swatch(palette.preview.dark)
        }
        .frame(height: 48 * scale)
        VStack(alignment: .leading, spacing: 2 * scale) {
          Text(palette.name).capoText(.xs, weight: .semibold).foregroundStyle(CapoTheme.foreground)
          Text(palette.summary).capoText(.px10).foregroundStyle(CapoTheme.mutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10 * scale)
        .padding(.vertical, 8 * scale)
        .background(CapoTheme.card)
      }
      .optionCard(selected: selected, radius: CapoRadius.xl * scale, fill: false)
      .activeBar(selected, scale: scale)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(palette.name), \(palette.summary)")
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }

  private func swatch(_ preview: CapoPalette.Preview) -> some View {
    HStack(spacing: 6 * scale) {
      Circle().fill(color(preview.primary)).frame(width: 14 * scale, height: 14 * scale)
        .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
      Circle().fill(color(preview.accent1)).frame(width: 8 * scale, height: 8 * scale).opacity(0.75)
      Circle().fill(color(preview.accent2)).frame(width: 8 * scale, height: 8 * scale).opacity(0.6)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(color(preview.background))
  }

  private func color(_ hex: String) -> Color { Color(hex: hex) ?? .gray }
}

struct FontCard: View {
  @Environment(\.capoUIScale) private var scale
  let font: CapoUIFont
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6 * scale) {
        // The sample is set in the card's own font regardless of the current selection.
        Text("Aa").font(Self.sample(font, size: 24 * scale)).foregroundStyle(CapoTheme.foreground)
          .lineLimit(1)
        Text(font.name).capoText(.xs, weight: .medium).foregroundStyle(CapoTheme.foreground)
          .lineLimit(1).minimumScaleFactor(0.8)
        Text(font.summary).capoText(.px10).foregroundStyle(CapoTheme.mutedForeground)
          .lineLimit(1).minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12 * scale)
      .padding(.top, 14 * scale)
      .padding(.bottom, 20 * scale)
      .optionCard(selected: selected, radius: CapoRadius.xl * scale)
      .activeBar(selected, scale: scale)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(font.name), \(font.summary)")
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }

  /// "Aa" at semibold in `font`, independent of the app-wide selection.
  static func sample(_ font: CapoUIFont, size: CGFloat) -> Font {
    CapoFonts.register()
    return CapoFont.font(font, size: size, weight: .semibold)
  }
}

/// Icon over a label: theme and chord-hand cards.
struct OptionTile: View {
  @Environment(\.capoUIScale) private var scale
  let icon: CapoIconName
  let title: String
  let selected: Bool
  var mirrored = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8 * scale) {
        CapoIcon(icon, size: 20 * scale)
          .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        Text(title).capoText(.sm, weight: .medium)
      }
      .foregroundStyle(selected ? CapoTheme.primary : CapoTheme.mutedForeground)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12 * scale)
      .padding(.top, 16 * scale)
      .padding(.bottom, selected ? 20 * scale : 16 * scale)
      .optionCard(selected: selected, radius: CapoRadius.xl * scale)
      .activeBar(selected, scale: scale)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}

struct LanguageChip: View {
  @Environment(\.capoUIScale) private var scale
  let flag: String
  let name: String
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10 * scale) {
        Text(flag).capoText(.base)
        Text(name).capoText(.sm, weight: .medium)
      }
      .foregroundStyle(selected ? CapoTheme.primary : CapoTheme.mutedForeground)
      .padding(.horizontal, 16 * scale)
      .padding(.vertical, 12 * scale)
      .frame(minHeight: CapoMetrics.minHitTarget)
      .optionCard(selected: selected, radius: CapoRadius.xl * scale)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(name)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}
