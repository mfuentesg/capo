import CapoDesign
import SwiftUI

/// The performance controls collapsed into one round button that can be dragged anywhere over the
/// lyrics. Tapping it opens the full control panel next to it, on the side with more room.
struct FloatingControls<Panel: View>: View {
  @Binding var isOpen: Bool
  let isPlaying: Bool
  @ViewBuilder let panel: () -> Panel

  @AppStorage(FloatingControlsPreference.xKey) private var storedX = FloatingControlsPreference.defaultFraction.x
  @AppStorage(FloatingControlsPreference.yKey) private var storedY = FloatingControlsPreference.defaultFraction.y
  @GestureState private var dragOffset = CGSize.zero
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let rest = FloatingControlsMath.center(fraction: CGPoint(x: storedX, y: storedY), in: size)
      let live = FloatingControlsMath.clamp(
        CGPoint(x: rest.x + dragOffset.width, y: rest.y + dragOffset.height), in: size)
      let above = FloatingControlsMath.opensAbove(center: live, in: size)
      let half = FloatingControlsMath.buttonSize / 2
      ZStack {
        if isOpen {
          panel()
            .frame(maxWidth: min(size.width - 2 * FloatingControlsMath.margin, 640))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: above ? .bottom : .top)
            .padding(above ? .bottom : .top, above ? size.height - (live.y - half) + 8 : live.y + half + 8)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
        button
          .position(live)
          .gesture(
            DragGesture(minimumDistance: 6, coordinateSpace: .local)
              .updating($dragOffset) { value, state, _ in state = value.translation }
              .onEnded { value in
                let end = CGPoint(x: rest.x + value.translation.width, y: rest.y + value.translation.height)
                let fraction = FloatingControlsMath.fraction(center: end, in: size)
                storedX = fraction.x
                storedY = fraction.y
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
