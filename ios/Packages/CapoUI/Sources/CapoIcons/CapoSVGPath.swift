import SwiftUI

/// Public entry to the SVG path-data parser, for one-off vector artwork such as the wordmark.
public nonisolated enum CapoSVGPath {
  public static func path(from data: String) -> Path { SVGPathParser.path(from: data) }
}
