import Foundation
import Testing

@testable import CapoPerformanceUI

@Suite struct StageKeyInfoTests {
  @Test func soundsInAndPlayShapesFollowTransposeAndCapo() throws {
    // G +2 sounds in A; with the capo on 2 the shapes are G.
    let info = try #require(StageKeyInfo(key: "G", transpose: 2, capo: 2))
    #expect(info.soundsIn == "A")
    #expect(info.playShapesIn == "G")
  }

  @Test func noCapoMeansNoSeparateShapes() throws {
    let info = try #require(StageKeyInfo(key: "G", transpose: 0, capo: 0))
    #expect(info.soundsIn == "G")
    #expect(info.playShapesIn == nil)
  }

  @Test func missingKeyHasNoChip() {
    #expect(StageKeyInfo(key: nil, transpose: 1, capo: 1) == nil)
    #expect(StageKeyInfo(key: "", transpose: 1, capo: 1) == nil)
  }
}

@Suite struct StageDockStateTests {
  @Test func preferenceDefaultsToExpandedAndPersists() throws {
    let suite = "stage-dock-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preference = StageDockPreference(defaults: defaults)
    #expect(preference.isExpanded)
    preference.isExpanded = false
    #expect(!StageDockPreference(defaults: defaults).isExpanded)
  }

  @Test func transientDockIgnoresThePersistedChoice() {
    #expect(StageFullscreen.showsFullDock(persisted: true, transient: false, usesTransient: true) == false)
    #expect(StageFullscreen.showsFullDock(persisted: false, transient: true, usesTransient: true))
    #expect(StageFullscreen.showsFullDock(persisted: true, transient: false, usesTransient: false))
    #expect(!StageFullscreen.showsFullDock(persisted: false, transient: true, usesTransient: false))
  }

  @Test func fullscreenBoostsTheFont() {
    #expect(StageFullscreen.fontScale(base: 1, isFullscreen: false) == 1)
    #expect(StageFullscreen.fontScale(base: 1.2, isFullscreen: true) == 1.5)
  }

  @Test func swipeUpExpandsTheDock() {
    #expect(StageFullscreen.isExpandSwipe(translation: CGSize(width: 4, height: -40)))
    #expect(!StageFullscreen.isExpandSwipe(translation: CGSize(width: 0, height: -10)))
    #expect(!StageFullscreen.isExpandSwipe(translation: CGSize(width: 80, height: -30)))
    #expect(!StageFullscreen.isExpandSwipe(translation: CGSize(width: 0, height: 40)))
  }
}

@Suite struct TitlePillVisibilityTests {
  let start = Date(timeIntervalSinceReferenceDate: 1000)

  @Test func hiddenUntilShown() {
    #expect(!TitlePillVisibility().isVisible(at: start))
  }

  @Test func autoHidesAfterThreeSeconds() {
    var pill = TitlePillVisibility()
    pill.show(at: start)
    #expect(pill.isVisible(at: start.addingTimeInterval(2.9)))
    #expect(!pill.isVisible(at: start.addingTimeInterval(3)))
    #expect(pill.remaining(at: start.addingTimeInterval(1)) == 2)
    #expect(pill.remaining(at: start.addingTimeInterval(5)) == 0)
  }

  @Test func tappingAgainRestartsTheTimer() {
    var pill = TitlePillVisibility()
    pill.show(at: start)
    pill.show(at: start.addingTimeInterval(2.5))
    #expect(pill.isVisible(at: start.addingTimeInterval(5)))
    #expect(!pill.isVisible(at: start.addingTimeInterval(5.6)))
    pill.hide()
    #expect(!pill.isVisible(at: start.addingTimeInterval(2.6)))
  }
}

@Suite struct StageScrollMetricsTests {
  @Test func thumbAndProgress() {
    let top = StageScrollMetrics(offset: 0, viewport: 500, content: 2000)
    #expect(top.thumbFraction == 0.25)
    #expect(top.progress == 0)
    #expect(top.thumbStart == 0)
    let bottom = StageScrollMetrics(offset: 1500, viewport: 500, content: 2000)
    #expect(bottom.progress == 1)
    #expect(bottom.thumbStart == 0.75)
    let middle = StageScrollMetrics(offset: 750, viewport: 500, content: 2000)
    #expect(middle.progress == 0.5)
  }

  @Test func shortContentFillsTheRailAndHidesIt() {
    let fits = StageScrollMetrics(offset: 0, viewport: 800, content: 600)
    #expect(fits.thumbFraction == 1)
    #expect(fits.progress == 0)
    #expect(!fits.isScrollable)
    #expect(StageScrollMetrics().thumbFraction == 1)
  }

  @Test func bouncingPastTheEndsIsClamped() {
    #expect(StageScrollMetrics(offset: -40, viewport: 500, content: 2000).progress == 0)
    #expect(StageScrollMetrics(offset: 1700, viewport: 500, content: 2000).progress == 1)
  }
}

@Suite struct StageAutoScrollLabelTests {
  @Test func labels() {
    #expect(StageAutoScrollLabel.speed(30) == "30 px/s")
    #expect(StageAutoScrollLabel.tempoSource(bpm: 72) == "72 BPM")
    #expect(StageAutoScrollLabel.tempoSource(bpm: 0) == nil)
    #expect(StageAutoScrollLabel.tempoSource(bpm: nil) == nil)
    #expect(StageAutoScrollLabel.signed(2) == "+2")
    #expect(StageAutoScrollLabel.signed(0) == "0")
    #expect(StageAutoScrollLabel.signed(-3) == "-3")
  }
}
