import CapoDesign
import SwiftUI

public nonisolated struct SongRenderStyle: Hashable, Sendable {
  public var fontScale = 1.0, columns = 1, showChords = true, showLyrics = true, collapsible = true
  public init() {}
}

/// WP0 stub: prints the plain text lines. WP7a replaces the body.
public struct ChordProContentView: View {
  let rendered: RenderedSong
  let style: SongRenderStyle
  let onChordTap: ((String) -> Void)?

  public init(rendered: RenderedSong, style: SongRenderStyle, onChordTap: ((String) -> Void)? = nil) {
    self.rendered = rendered
    self.style = style
    self.onChordTap = onChordTap
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(Array(rendered.segments.enumerated()), id: \.offset) { _, segment in
        if case .normal(let body) = segment {
          ForEach(Array(body.lines.enumerated()), id: \.offset) { _, line in
            if case .text(let text) = line {
              Text(text).font(CapoFont.lyrics(scale: style.fontScale))
            }
          }
        }
      }
    }
  }
}
