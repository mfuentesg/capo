import CapoChordPro
import Observation

/// The song currently on stage, published by the performance screen for secondary displays.
@Observable
public final class CurrentPerformance {
  public static let shared = CurrentPerformance()

  public struct Snapshot: Equatable {
    public var title: String
    public var subtitle: String?
    public var rendered: RenderedSong
    public var fontScale: Double
    public var showChords: Bool

    public init(
      title: String, subtitle: String?, rendered: RenderedSong, fontScale: Double, showChords: Bool
    ) {
      self.title = title
      self.subtitle = subtitle
      self.rendered = rendered
      self.fontScale = fontScale
      self.showChords = showChords
    }
  }

  public var snapshot: Snapshot?

  public init() {}
}
