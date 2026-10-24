import CoreGraphics

/// Geometry of one chord diagram in the web's SVG units (port of `chord-position-diagram.tsx`).
/// The view scales the 242 x 186 box to its width.
public nonisolated struct ChordDiagramGeometry: Equatable, Sendable {
  public static let stringSpacing: CGFloat = 40
  public static let fretSpacing: CGFloat = 36
  public static let padLeft: CGFloat = 36
  public static let padTop: CGFloat = 30
  public static let padRight: CGFloat = 16
  public static let padBottom: CGFloat = 12
  public static let fretCount = 4
  public static let stringCount = 6
  public static let dotRadius: CGFloat = 12
  public static let width: CGFloat = padLeft + CGFloat(stringCount - 1) * stringSpacing + padRight  // 242
  public static let height: CGFloat = padTop + CGFloat(fretCount) * fretSpacing + padBottom  // 186

  public struct Dot: Equatable, Sendable {
    public let string: Int
    public let center: CGPoint
    public let finger: Int
  }
  public struct Barre: Equatable, Sendable {
    public let fret: Int
    public let minString: Int
    public let maxString: Int
    public let finger: Int
    public let rect: CGRect
    public let center: CGPoint
  }
  public struct Marker: Equatable, Sendable {
    public let string: Int
    public let center: CGPoint
    public let isMuted: Bool
  }

  public let isNut: Bool
  public let nutRect: CGRect
  public let fretLineYs: [CGFloat]
  public let stringXs: [CGFloat]
  public let top: CGFloat
  public let bottom: CGFloat
  public let barres: [Barre]
  public let dots: [Dot]
  public let markers: [Marker]
  public let baseFretLabel: (value: Int, center: CGPoint)?

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.nutRect == rhs.nutRect && lhs.stringXs == rhs.stringXs && lhs.barres == rhs.barres
      && lhs.dots == rhs.dots && lhs.markers == rhs.markers
      && lhs.baseFretLabel?.value == rhs.baseFretLabel?.value
  }

  /// Finger numbers by fret order when the database has none (`autoAssignFingers`).
  public static func autoAssignFingers(frets: [Int], baseFret: Int) -> [Int] {
    let absolute = frets.map { $0 > 0 ? baseFret + $0 - 1 : 0 }
    let unique = Set(absolute.filter { $0 > 0 }).sorted()
    var map: [Int: Int] = [:]
    for (index, fret) in unique.prefix(4).enumerated() { map[fret] = index + 1 }
    return absolute.map { $0 > 0 ? map[$0] ?? 0 : 0 }
  }

  /// `mirror` is true for the left-hand setting (low string on the left), as on the web.
  public init(position: ChordPosition, mirror: Bool) {
    typealias G = ChordDiagramGeometry
    let ns = G.stringCount
    var frets = position.frets
    if frets.count < ns { frets += Array(repeating: -1, count: ns - frets.count) }
    frets = Array(frets.prefix(ns))
    let baseFret = position.baseFret
    isNut = baseFret == 1
    let fingers =
      position.fingers.allSatisfy { $0 == 0 }
      ? G.autoAssignFingers(frets: frets, baseFret: baseFret)
      : Array((position.fingers + Array(repeating: 0, count: ns)).prefix(ns))

    func sx(_ string: Int) -> CGFloat {
      mirror
        ? G.padLeft + CGFloat(string) * G.stringSpacing
        : G.padLeft + CGFloat(ns - 1 - string) * G.stringSpacing
    }
    func fy(_ fret: Int) -> CGFloat { G.padTop + CGFloat(fret) * G.fretSpacing }
    func dotY(_ fret: Int) -> CGFloat { G.padTop + (CGFloat(fret) - 0.5) * G.fretSpacing }

    stringXs = (0..<ns).map(sx)
    top = fy(0)
    bottom = fy(G.fretCount)
    fretLineYs = (0..<G.fretCount).map { fy($0 + 1) }
    nutRect = CGRect(
      x: G.padLeft, y: G.padTop - (isNut ? 5 : 1.5), width: CGFloat(ns - 1) * G.stringSpacing,
      height: isNut ? 5 : 2)

    // Explicit barres, split into contiguous runs so a gap does not get a bar drawn over it.
    struct Datum: Equatable {
      var fret: Int
      var minString: Int
      var maxString: Int
      var finger: Int
    }
    var explicit: [Datum] = []
    for barreFret in position.barres {
      let barred = frets.enumerated().filter { $0.element == barreFret }.map(\.offset)
      guard barred.count >= 2 else { continue }
      let finger = barred.map { fingers[$0] }.filter { $0 > 0 }.min() ?? 1
      var start = barred[0]
      for index in 1...barred.count {
        if index == barred.count || barred[index] != barred[index - 1] + 1 {
          if barred[index - 1] - start >= 1 {
            explicit.append(Datum(fret: barreFret, minString: start, maxString: barred[index - 1], finger: finger))
          }
          if index < barred.count { start = barred[index] }
        }
      }
    }
    // Inferred barres: one finger on 2+ strings at the same fret.
    var groupOrder: [String] = []
    var groups: [String: (finger: Int, fret: Int, strings: [Int])] = [:]
    for (string, fret) in frets.enumerated() where fret > 0 && fingers[string] > 0 {
      let key = "\(fingers[string])-\(fret)"
      if groups[key] == nil {
        groupOrder.append(key)
        groups[key] = (fingers[string], fret, [])
      }
      groups[key]?.strings.append(string)
    }
    var inferred: [Datum] = []
    for key in groupOrder {
      guard let group = groups[key], group.strings.count >= 2,
        let low = group.strings.min(), let high = group.strings.max()
      else { continue }
      if explicit.contains(where: { $0.fret == group.fret && $0.minString <= low && $0.maxString >= high }) {
        continue
      }
      inferred.append(Datum(fret: group.fret, minString: low, maxString: high, finger: group.finger))
    }
    var seen = Set<String>()
    let data = (explicit + inferred).filter {
      seen.insert("\($0.fret)-\($0.minString)-\($0.maxString)").inserted
    }

    var covered = Set<String>()
    for datum in data {
      for string in datum.minString...datum.maxString { covered.insert("\(string)-\(datum.fret)") }
    }
    // A flat barre makes any lower fret inside its span impossible to sound.
    var blocked = Set<Int>()
    for barreFret in position.barres {
      let barred = frets.enumerated().filter { $0.element == barreFret }.map(\.offset)
      guard barred.count >= 2, let low = barred.min(), let high = barred.max() else { continue }
      for string in low...high where frets[string] > 0 && frets[string] < barreFret { blocked.insert(string) }
    }

    barres = data.map { datum in
      let xs = [sx(datum.minString), sx(datum.maxString)]
      let left = xs.min() ?? 0
      let right = xs.max() ?? 0
      let y = dotY(datum.fret)
      return Barre(
        fret: datum.fret, minString: datum.minString, maxString: datum.maxString,
        finger: datum.finger,
        rect: CGRect(x: left - 9, y: y - 10, width: right - left + 18, height: 20),
        center: CGPoint(x: (left + right) / 2, y: y))
    }
    baseFretLabel = isNut ? nil : (baseFret, CGPoint(x: G.padLeft - 20, y: dotY(1) + 5))
    dots = frets.enumerated().compactMap { string, fret in
      guard fret > 0, !covered.contains("\(string)-\(fret)"), !blocked.contains(string) else { return nil }
      return Dot(string: string, center: CGPoint(x: sx(string), y: dotY(fret)), finger: fingers[string])
    }
    markers = frets.enumerated().compactMap { string, fret in
      guard fret == -1 || fret == 0 else { return nil }
      return Marker(string: string, center: CGPoint(x: sx(string), y: G.padTop - 15), isMuted: fret == -1)
    }
  }

  /// Spoken description, strings low to high: "muted, 3, 2, open, 1, open".
  public static func spokenFrets(of position: ChordPosition, muted: String, open: String) -> String {
    position.frets.map { fret in
      fret < 0 ? muted : fret == 0 ? open : String(fret + position.baseFret - 1)
    }.joined(separator: ", ")
  }
}
