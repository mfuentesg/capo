import CapoDesign
import SwiftUI

/// Large-type, control-free mirror of the song being performed, for an external display.
public struct ExternalDisplayView: View {
  let performance: CurrentPerformance

  public init(performance: CurrentPerformance = .shared) {
    self.performance = performance
  }

  public var body: some View {
    Group {
      if let snapshot = performance.snapshot {
        VStack(alignment: .leading, spacing: 16) {
          Text(snapshot.title).font(.system(size: 56, weight: .bold)).lineLimit(1)
          if let subtitle = snapshot.subtitle {
            Text(subtitle).font(.system(size: 28)).foregroundStyle(.secondary).lineLimit(1)
          }
          ChordProContentView(rendered: snapshot.rendered, style: style(snapshot))
          Spacer(minLength: 0)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      } else {
        Image(systemName: "music.note").font(.system(size: 120)).foregroundStyle(.secondary)
      }
    }
    .background(Color(uiColor: .systemBackground))
    .environment(\.colorScheme, .dark)
  }

  private func style(_ snapshot: CurrentPerformance.Snapshot) -> SongRenderStyle {
    var style = SongRenderStyle()
    // Large type for the room; the audience cannot scroll, so the song is clipped to one screen.
    style.fontScale = max(snapshot.fontScale, 1) * 1.6
    style.columns = 2
    style.showChords = snapshot.showChords
    style.collapsible = false
    return style
  }
}
