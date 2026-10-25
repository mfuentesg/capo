import CoreGraphics
import Testing

@testable import CapoPerformanceUI

@Suite struct FloatingControlsMathTests {
  let size = CGSize(width: 400, height: 800)

  @Test func fractionRoundTripsInsideTheArea() {
    let center = CGPoint(x: 120, y: 300)
    let fraction = FloatingControlsMath.fraction(center: center, in: size)
    #expect(FloatingControlsMath.center(fraction: fraction, in: size) == center)
  }

  @Test func dragPastTheEdgeStaysFullyVisible() {
    let inset = FloatingControlsMath.buttonSize / 2 + FloatingControlsMath.margin
    let corner = FloatingControlsMath.center(fraction: CGPoint(x: 5, y: -3), in: size)
    #expect(corner == CGPoint(x: size.width - inset, y: inset))
  }

  @Test func panelOpensTowardTheRoomierHalf() {
    #expect(FloatingControlsMath.opensAbove(center: CGPoint(x: 200, y: 700), in: size))
    #expect(!FloatingControlsMath.opensAbove(center: CGPoint(x: 200, y: 100), in: size))
  }

  @Test func degenerateAreaFallsBackToDefault() {
    #expect(FloatingControlsMath.fraction(center: .zero, in: .zero) == FloatingControlsPreference.defaultFraction)
  }
}
