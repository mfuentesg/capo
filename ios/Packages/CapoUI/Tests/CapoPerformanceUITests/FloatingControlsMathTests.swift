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

  @Test func fullscreenInsetsKeepTheButtonOffTheStatusBarAndHomeIndicator() {
    let inset = FloatingControlsMath.buttonSize / 2 + FloatingControlsMath.margin
    let top = FloatingControlsMath.clamp(CGPoint(x: 200, y: 0), in: size, top: 56, bottom: 34)
    let bottom = FloatingControlsMath.clamp(CGPoint(x: 200, y: 900), in: size, top: 56, bottom: 34)
    #expect(top.y == inset + 56 && bottom.y == size.height - inset - 34)
  }

  @Test func placementsAreRememberedPerShape() {
    let portrait = FloatingPlacements.shape(size: CGSize(width: 390, height: 800), isRegularWidth: false)
    let landscape = FloatingPlacements.shape(size: CGSize(width: 1000, height: 700), isRegularWidth: true)
    #expect(portrait == "p-c" && landscape == "l-r")
    var placements = FloatingPlacements(raw: "")
    let fallback = CGPoint(x: 0.9, y: 0.8)
    #expect(placements.fraction(for: portrait, fallback: fallback) == fallback)
    placements.set(CGPoint(x: 0.1, y: 0.2), for: portrait)
    let restored = FloatingPlacements(raw: placements.raw)
    #expect(restored.fraction(for: portrait, fallback: fallback) == CGPoint(x: 0.1, y: 0.2))
    #expect(restored.fraction(for: landscape, fallback: fallback) == fallback)
    #expect(FloatingPlacements(raw: "junk;a=1;b=x,y").raw == "")
  }
}
