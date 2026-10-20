import Testing
import SwiftUI
import UIKit
@testable import CapoDesign

@MainActor @Suite struct CapoDesignTests {
  @Test func hexParsing() throws {
    let c = try #require(HexColor.parse("#6b7280"))
    #expect(abs(c.red - 107.0 / 255) < 0.001)
    #expect(HexColor.parse("fff")?.red == 1)
    #expect(HexColor.parse("#12345") == nil)
    #expect(HexColor.parse("zzzzzz") == nil)
    #expect(Color(hex: "#ff0000") != nil)
  }

  @Test func tagColorFallsBackToDefault() {
    #expect(HexColor.isLight("#ffffff"))
    #expect(!HexColor.isLight("#000000"))
    #expect(!HexColor.isLight(nil))
  }

  @Test func oklchKnownValues() {
    let white = OKLCH(1, 0, 0).srgb
    #expect(abs(white.red - 1) < 0.001 && abs(white.green - 1) < 0.001 && abs(white.blue - 1) < 0.001)
    let black = OKLCH(0, 0, 0).srgb
    #expect(black.red < 0.001 && black.green < 0.001 && black.blue < 0.001)
    // Mid blue accent (verse) must be blue-dominant.
    let verse = OKLCH(0.48, 0.16, 248).srgb
    #expect(verse.blue > verse.red && verse.blue > verse.green)
  }

  @Test func lightAndDarkAccentsDiffer() {
    let light = OKLCH(0.5, 0.17, 288).srgb
    let dark = OKLCH(0.72, 0.16, 288).srgb
    #expect(dark.red > light.red && dark.blue > light.blue)
    #expect(SectionAccent.color(for: "chorus") != SectionAccent.color(for: "verse"))
  }

  @Test func flagStylesMirrorWebConfig() {
    #expect(FlagBadge.style(for: .attention).label == "!")
    #expect(FlagBadge.style(for: .forte).italic)
    #expect(FlagBadge.style(for: .piano).label == "p")
    #expect(FlagBadge.style(for: .skip).lightBackground == nil)
    for flag in SectionFlag.allCases { #expect(!FlagBadge.style(for: flag).label.isEmpty) }
  }

  @Test func syncSymbolPriority() {
    func status(_ phase: SyncPhase, pending: Int = 0, conflicts: Int = 0, failed: Int = 0) -> SyncStatus {
      SyncStatus(phase: phase, lastSuccessAt: nil, pendingOperations: pending, conflicts: conflicts, failedOperations: failed)
    }
    #expect(SyncStatusBadge.symbol(for: status(.idle)).name == "checkmark.icloud")
    #expect(SyncStatusBadge.symbol(for: status(.offline)).name == "icloud.slash")
    #expect(SyncStatusBadge.symbol(for: status(.idle, conflicts: 1)).name.contains("exclamationmark"))
    #expect(SyncStatusBadge.symbol(for: status(.idle, failed: 1)).name == "exclamationmark.icloud")
  }

  @Test func fontScalesWithBase() {
    #expect(CapoFont.baseLyricsPointSize == 16)
  }
}
