import CoreGraphics
import SwiftUI

/// Minimal SVG path-data parser (M L H V C S Q T A Z, absolute and relative) producing a SwiftUI `Path`.
/// Nonisolated so it can run from `Shape.path(in:)` off the main actor.
nonisolated enum SVGPathParser {
  static func path(from data: String) -> Path {
    var scanner = Scanner(Array(data.unicodeScalars))
    var path = Path()
    var current = CGPoint.zero
    var start = CGPoint.zero
    var lastCubicControl: CGPoint?
    var lastQuadControl: CGPoint?
    var command: Character = "M"

    while true {
      scanner.skipSeparators()
      if scanner.atEnd { break }
      if let c = scanner.peekCommand() {
        command = c
        scanner.advance()
        if command == "Z" || command == "z" {
          path.closeSubpath()
          current = start
          lastCubicControl = nil
          lastQuadControl = nil
          continue
        }
      } else if command == "M" {
        command = "L"
      } else if command == "m" {
        command = "l"
      }
      let rel = command.isLowercase
      let ox = rel ? current.x : 0
      let oy = rel ? current.y : 0
      var cubic: CGPoint?
      var quad: CGPoint?

      switch command {
      case "M", "m":
        guard let x = scanner.number(), let y = scanner.number() else { return path }
        current = CGPoint(x: x + ox, y: y + oy)
        start = current
        path.move(to: current)
      case "L", "l":
        guard let x = scanner.number(), let y = scanner.number() else { return path }
        current = CGPoint(x: x + ox, y: y + oy)
        path.addLine(to: current)
      case "H", "h":
        guard let x = scanner.number() else { return path }
        current = CGPoint(x: x + ox, y: current.y)
        path.addLine(to: current)
      case "V", "v":
        guard let y = scanner.number() else { return path }
        current = CGPoint(x: current.x, y: y + oy)
        path.addLine(to: current)
      case "C", "c":
        guard let x1 = scanner.number(), let y1 = scanner.number(),
          let x2 = scanner.number(), let y2 = scanner.number(),
          let x = scanner.number(), let y = scanner.number() else { return path }
        let c2 = CGPoint(x: x2 + ox, y: y2 + oy)
        let end = CGPoint(x: x + ox, y: y + oy)
        path.addCurve(to: end, control1: CGPoint(x: x1 + ox, y: y1 + oy), control2: c2)
        cubic = c2
        current = end
      case "S", "s":
        guard let x2 = scanner.number(), let y2 = scanner.number(),
          let x = scanner.number(), let y = scanner.number() else { return path }
        let c1 = lastCubicControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
        let c2 = CGPoint(x: x2 + ox, y: y2 + oy)
        let end = CGPoint(x: x + ox, y: y + oy)
        path.addCurve(to: end, control1: c1, control2: c2)
        cubic = c2
        current = end
      case "Q", "q":
        guard let x1 = scanner.number(), let y1 = scanner.number(),
          let x = scanner.number(), let y = scanner.number() else { return path }
        let c = CGPoint(x: x1 + ox, y: y1 + oy)
        let end = CGPoint(x: x + ox, y: y + oy)
        path.addQuadCurve(to: end, control: c)
        quad = c
        current = end
      case "T", "t":
        guard let x = scanner.number(), let y = scanner.number() else { return path }
        let c = lastQuadControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
        let end = CGPoint(x: x + ox, y: y + oy)
        path.addQuadCurve(to: end, control: c)
        quad = c
        current = end
      case "A", "a":
        guard let rx = scanner.number(), let ry = scanner.number(), let rot = scanner.number(),
          let large = scanner.flag(), let sweep = scanner.flag(),
          let x = scanner.number(), let y = scanner.number() else { return path }
        let end = CGPoint(x: x + ox, y: y + oy)
        addArc(&path, from: current, to: end, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
        current = end
      default:
        return path
      }
      lastCubicControl = cubic
      lastQuadControl = quad
    }
    return path
  }

  /// SVG endpoint arc -> cubic Bezier segments (spec F.6.5).
  private static func addArc(
    _ path: inout Path, from p0: CGPoint, to p1: CGPoint, rx rxIn: CGFloat, ry ryIn: CGFloat,
    rotation: CGFloat, large: Bool, sweep: Bool
  ) {
    var rx = abs(rxIn)
    var ry = abs(ryIn)
    if p0 == p1 { return }
    if rx == 0 || ry == 0 {
      path.addLine(to: p1)
      return
    }
    let phi = rotation * .pi / 180
    let cosPhi = cos(phi)
    let sinPhi = sin(phi)
    let dx = (p0.x - p1.x) / 2
    let dy = (p0.y - p1.y) / 2
    let x1p = cosPhi * dx + sinPhi * dy
    let y1p = -sinPhi * dx + cosPhi * dy
    let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lambda > 1 {
      let s = lambda.squareRoot()
      rx *= s
      ry *= s
    }
    let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    var coef = den == 0 ? 0 : (max(0, num) / den).squareRoot()
    if large == sweep { coef = -coef }
    let cxp = coef * rx * y1p / ry
    let cyp = -coef * ry * x1p / rx
    let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
    let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2

    func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
      let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
      return a
    }
    let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    var delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if !sweep && delta > 0 { delta -= 2 * .pi }
    if sweep && delta < 0 { delta += 2 * .pi }

    let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
    let step = delta / CGFloat(segments)
    let t = 4.0 / 3.0 * tan(step / 4)
    var a = theta1
    func point(_ ang: CGFloat) -> CGPoint {
      let x = rx * cos(ang)
      let y = ry * sin(ang)
      return CGPoint(x: cosPhi * x - sinPhi * y + cx, y: sinPhi * x + cosPhi * y + cy)
    }
    func derivative(_ ang: CGFloat) -> CGPoint {
      let x = -rx * sin(ang)
      let y = ry * cos(ang)
      return CGPoint(x: cosPhi * x - sinPhi * y, y: sinPhi * x + cosPhi * y)
    }
    for _ in 0..<segments {
      let b = a + step
      let pa = point(a)
      let pb = point(b)
      let da = derivative(a)
      let db = derivative(b)
      path.addCurve(
        to: pb,
        control1: CGPoint(x: pa.x + t * da.x, y: pa.y + t * da.y),
        control2: CGPoint(x: pb.x - t * db.x, y: pb.y - t * db.y))
      a = b
    }
  }

  private struct Scanner {
    let chars: [Unicode.Scalar]
    var i = 0
    init(_ chars: [Unicode.Scalar]) { self.chars = chars }
    var atEnd: Bool { i >= chars.count }

    mutating func advance() { i += 1 }

    mutating func skipSeparators() {
      while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" {
        i += 1
      }
    }

    func peekCommand() -> Character? {
      guard i < chars.count else { return nil }
      let c = Character(chars[i])
      return "MmLlHhVvCcSsQqTtAaZz".contains(c) ? c : nil
    }

    /// Arc flags are single `0`/`1` characters and may be packed without separators.
    mutating func flag() -> Bool? {
      skipSeparators()
      guard i < chars.count, chars[i] == "0" || chars[i] == "1" else { return nil }
      defer { i += 1 }
      return chars[i] == "1"
    }

    mutating func number() -> CGFloat? {
      skipSeparators()
      let begin = i
      if i < chars.count, chars[i] == "-" || chars[i] == "+" { i += 1 }
      var sawDot = false
      var digits = 0
      while i < chars.count {
        let c = chars[i]
        if c >= "0" && c <= "9" {
          digits += 1
          i += 1
        } else if c == "." && !sawDot {
          sawDot = true
          i += 1
        } else {
          break
        }
      }
      if digits > 0, i < chars.count, chars[i] == "e" || chars[i] == "E" {
        var j = i + 1
        if j < chars.count, chars[j] == "-" || chars[j] == "+" { j += 1 }
        if j < chars.count, chars[j] >= "0" && chars[j] <= "9" {
          while j < chars.count, chars[j] >= "0" && chars[j] <= "9" { j += 1 }
          i = j
        }
      }
      guard digits > 0 else {
        i = begin
        return nil
      }
      return Double(String(String.UnicodeScalarView(chars[begin..<i]))).map { CGFloat($0) }
    }
  }
}
