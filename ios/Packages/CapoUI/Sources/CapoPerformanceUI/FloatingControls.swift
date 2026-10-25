import CapoDesign
import SwiftUI

/// The performance controls collapsed into one round button that can be dragged anywhere over the
/// lyrics. Tapping it opens the full control panel next to it, on the side with more room.
struct FloatingControls<Panel: View>: View {
  @Binding var isOpen: Bool
  let isPlaying: Bool
  /// Insets that keep the button clear of the status bar / home indicator in full screen.
  var topInset: CGFloat = 0
  var bottomInset: CGFloat = 0
  @ViewBuilder let panel: () -> Panel

  @AppStorage(FloatingPlacements.key) private var placementsRaw = ""
  @AppStorage(FloatingControlsPreference.xKey) private var legacyX = FloatingControlsPreference.defaultFraction.x
  @AppStorage(FloatingControlsPreference.yKey) private var legacyY = FloatingControlsPreference.defaultFraction.y
  @Environment(\.horizontalSizeClass) private var sizeClass
  @GestureState private var dragOffset = CGSize.zero
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let shape = FloatingPlacements.shape(size: size, isRegularWidth: sizeClass == .regular)
      let stored = FloatingPlacements(raw: placementsRaw)
        .fraction(for: shape, fallback: CGPoint(x: legacyX, y: legacyY))
      let rest = FloatingControlsMath.clamp(
        CGPoint(x: stored.x * size.width, y: stored.y * size.height), in: size,
        top: topInset, bottom: bottomInset)
      let live = FloatingControlsMath.clamp(
        CGPoint(x: rest.x + dragOffset.width, y: rest.y + dragOffset.height), in: size,
        top: topInset, bottom: bottomInset)
      let above = FloatingControlsMath.opensAbove(center: live, in: size)
      let half = FloatingControlsMath.buttonSize / 2
      ZStack {
        if isOpen {
          panel()
            .frame(maxWidth: min(size.width - 2 * FloatingControlsMath.margin, 640))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: above ? .bottom : .top)
            .padding(above ? .bottom : .top, above ? size.height - (live.y - half) + 8 : live.y + half + 8)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .accessibilitySortPriority(0)
        }
        button
          .accessibilitySortPriority(1)  // VoiceOver reaches the toggle before its panel
          .position(live)
          .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .local)
              .updating($dragOffset) { value, state, _ in state = value.translation }
              .onEnded { value in
                let end = CGPoint(x: rest.x + value.translation.width, y: rest.y + value.translation.height)
                let fraction = FloatingControlsMath.fraction(
                  center: FloatingControlsMath.clamp(end, in: size, top: topInset, bottom: bottomInset),
                  in: size)
                var placements = FloatingPlacements(raw: placementsRaw)
                placements.set(fraction, for: shape)
                placementsRaw = placements.raw
              }
          )
      }
      .frame(width: size.width, height: size.height)
    }
  }

  private var button: some View {
    ZStack {
      Circle().fill(isOpen ? CapoTheme.primary : CapoTheme.surfaceStrong)
      Circle().strokeBorder(CapoTheme.border, lineWidth: 1)
      Image(systemName: isOpen ? "xmark" : (isPlaying ? "pause.fill" : "slider.horizontal.3"))
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(isOpen ? CapoTheme.primaryForeground : CapoTheme.text)
    }
    .frame(width: FloatingControlsMath.buttonSize, height: FloatingControlsMath.buttonSize)
    .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    .contentShape(Circle())
    .onTapGesture {
      if reduceMotion { isOpen.toggle() } else { withAnimation(.easeInOut(duration: 0.2)) { isOpen.toggle() } }
    }
    .accessibilityElement()
    .accessibilityLabel(isOpen ? StageStrings.collapseControls : StageStrings.showControls)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint(StageStrings.floatControls)
  }
}
