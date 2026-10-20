import CapoDesign
import CapoRendering
import SwiftUI

public struct PerformanceNavigation {
  public var positionLabel: String?
  public var onNext: (@MainActor () -> Void)?
  public var onPrevious: (@MainActor () -> Void)?

  public init(
    positionLabel: String? = nil, onNext: (@MainActor () -> Void)? = nil,
    onPrevious: (@MainActor () -> Void)? = nil
  ) {
    self.positionLabel = positionLabel
    self.onNext = onNext
    self.onPrevious = onPrevious
  }

  public static let standalone = PerformanceNavigation()
}

/// WP0 stub. WP7b owns it.
public struct SongPerformanceView: View {
  let songID: SongID
  let navigation: PerformanceNavigation

  public init(songID: SongID, navigation: PerformanceNavigation = .standalone) {
    self.songID = songID
    self.navigation = navigation
  }

  public var body: some View { StubScreen("Performance") }
}
