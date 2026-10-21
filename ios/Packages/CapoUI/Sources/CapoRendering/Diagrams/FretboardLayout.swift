import CoreGraphics

/// Pure geometry for a chord diagram, in a unit coordinate space the view scales.
public nonisolated struct FretboardLayout: Equatable, Sendable {
  public struct Dot: Equatable, Sendable {
    public let string: Int
    public let row: Int
  }
  public struct Barre: Equatable, Sendable {
    public let row: Int
    public let fromString: Int
    public let toString: Int
  }

  public static let visibleFrets = 4

  public let stringCount: Int
  public let baseFret: Int
  public let dots: [Dot]
  public let barres: [Barre]
  public let mutedStrings: [Int]
  public let openStrings: [Int]

  public init(position: ChordPosition) {
    stringCount = position.frets.count
    baseFret = max(position.baseFret, 1)
    var dots: [Dot] = []
    var muted: [Int] = []
    var open: [Int] = []
    for (string, fret) in position.frets.enumerated() {
      if fret < 0 {
        muted.append(string)
      } else if fret == 0 {
        open.append(string)
      } else {
        dots.append(Dot(string: string, row: fret - 1))
      }
    }
    var barres: [Barre] = []
    for fret in position.barres {
      let strings = position.frets.enumerated().filter { $0.element == fret }.map(\.offset)
      // A barre needs at least two strings at its fret to be visible.
      guard let from = strings.first, let to = strings.last, from != to else { continue }
      barres.append(Barre(row: fret - 1, fromString: from, toString: to))
    }
    // Barred strings are drawn by the bar, not as separate dots.
    self.dots = dots.filter { dot in
      !barres.contains { $0.row == dot.row && dot.string >= $0.fromString && dot.string <= $0.toString }
    }
    self.barres = barres
    mutedStrings = muted
    openStrings = open
  }

  /// X of a string line within `width` (strings spaced evenly, edge to edge).
  public func stringX(_ string: Int, width: CGFloat) -> CGFloat {
    guard stringCount > 1 else { return width / 2 }
    return width * CGFloat(string) / CGFloat(stringCount - 1)
  }

  /// Y of the centre of a fret row within `height` (rows 0..<visibleFrets).
  public func rowY(_ row: Int, height: CGFloat) -> CGFloat {
    height * (CGFloat(row) + 0.5) / CGFloat(Self.visibleFrets)
  }

  /// Fret label shown beside the first row, nil at the nut.
  public var fretLabel: Int? { baseFret > 1 ? baseFret : nil }

  /// Spoken description, strings low to high: "muted, 3, 2, open, 1, open".
  public static func spokenFrets(of position: ChordPosition, muted: String, open: String) -> String {
    position.frets.map { fret in
      fret < 0 ? muted : fret == 0 ? open : String(fret + position.baseFret - 1)
    }.joined(separator: ", ")
  }
}
