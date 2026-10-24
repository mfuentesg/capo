import CapoDesign
import SwiftUI

/// Analyzer state (web `useChordAnalyzer`): -1 muted, 0 open, 1... fret relative to `baseFret`.
@MainActor @Observable
final class ChordAnalyzerModel {
  static let defaultFrets = Array(repeating: -1, count: 6)
  static let baseFretRange = 1...12

  var frets = ChordAnalyzerModel.defaultFrets
  var baseFret = 1

  var hasInput: Bool { frets.contains { $0 >= 0 } }
  var results: [ChordIdentifier.Identified] { hasInput ? ChordIdentifier.identify(frets, baseFret: baseFret) : [] }
  var notes: [String] { hasInput ? ChordIdentifier.notes(frets, baseFret: baseFret) : [] }

  /// Span of pressed absolute frets; more than 3 is a stretch.
  var isStretch: Bool {
    let pressed = frets.filter { $0 > 0 }.map { baseFret + $0 - 1 }
    guard let lo = pressed.min(), let hi = pressed.max() else { return false }
    return hi - lo > 3
  }

  func tapCell(string: Int, fret: Int) { frets[string] = frets[string] == fret ? 0 : fret }
  func tapMarker(string: Int) { frets[string] = frets[string] == -1 ? 0 : -1 }
  func reset() {
    frets = Self.defaultFrets
    baseFret = 1
  }
  func step(_ delta: Int) {
    baseFret = min(max(baseFret + delta, Self.baseFretRange.lowerBound), Self.baseFretRange.upperBound)
  }
}

/// Interactive fretboard (port of `fretboard-input.tsx`, 358 x 160 SVG units).
struct FretboardInput: View {
  @Bindable var model: ChordAnalyzerModel

  private enum Layout {
    static let fretCount = 7
    static let padL: CGFloat = 52, padR: CGFloat = 12, padT: CGFloat = 32, padB: CGFloat = 18
    static let stringGap: CGFloat = 22, fretGap: CGFloat = 42
    static let width = padL + CGFloat(fretCount) * fretGap + padR
    static let height = padT + 5 * stringGap + padB
    static let labels = ["E", "A", "D", "G", "B", "e"]
    static let markers = [3, 5, 7, 9, 12]
    /// Low E at the bottom, as in the SVG.
    static func y(_ string: Int) -> CGFloat { padT + CGFloat(5 - string) * stringGap }
    static func midX(_ fret: Int) -> CGFloat { padL + (CGFloat(fret) - 0.5) * fretGap }
    static func divX(_ fret: Int) -> CGFloat { padL + CGFloat(fret) * fretGap }
  }

  var body: some View {
    VStack(spacing: 12) {
      board
        .frame(maxWidth: 512)
        .aspectRatio(Layout.width / Layout.height, contentMode: .fit)
        .accessibilityLabel(L10n.Chords.Analyzer.fretboardLabel)
      if model.isStretch {
        Text(L10n.Chords.Analyzer.stretchWarning)
          .capoText(.px11).foregroundStyle(CapoTheme.warning)
      }
      HStack(spacing: 12) {
        stepButton("minus", label: L10n.Chords.Analyzer.lowerFret, delta: -1)
          .disabled(model.baseFret <= ChordAnalyzerModel.baseFretRange.lowerBound)
        Text("\(L10n.Chords.Analyzer.fretPosition) \(model.baseFret)")
          .capoText(.xs).monospacedDigit().foregroundStyle(CapoTheme.mutedForeground)
          .frame(minWidth: 110)
        stepButton("plus", label: L10n.Chords.Analyzer.higherFret, delta: 1)
          .disabled(model.baseFret >= ChordAnalyzerModel.baseFretRange.upperBound)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func stepButton(_ symbol: String, label: String, delta: Int) -> some View {
    Button { model.step(delta) } label: {
      Image(systemName: symbol).font(.system(size: 14, weight: .bold))
        .frame(width: 44, height: 44)
        .overlay(Circle().strokeBorder(CapoTheme.border).frame(width: 30, height: 30))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(CapoTheme.foreground)
    .accessibilityLabel(label)
  }

  private var board: some View {
    GeometryReader { proxy in
      let scale = proxy.size.width / Layout.width
      ZStack {
        Canvas { context, size in
          draw(&context, scale: size.width / Layout.width)
        }
        .accessibilityHidden(true)
        // One 44pt-or-larger hit area per marker and cell.
        Color.clear.contentShape(Rectangle())
          .gesture(
            SpatialTapGesture().onEnded { value in
              handleTap(CGPoint(x: value.location.x / scale, y: value.location.y / scale))
            })
      }
    }
  }

  private func handleTap(_ p: CGPoint) {
    for string in 0..<6 {
      let y = Layout.y(string)
      guard abs(p.y - y) <= Layout.stringGap / 2 else { continue }
      if abs(p.x - (Layout.padL - 18)) <= 14 {
        model.tapMarker(string: string)
        return
      }
      if p.x >= Layout.padL, p.x < Layout.divX(Layout.fretCount) {
        let fret = Int((p.x - Layout.padL) / Layout.fretGap) + 1
        model.tapCell(string: string, fret: fret)
      }
      return
    }
  }

  private func draw(_ context: inout GraphicsContext, scale: CGFloat) {
    context.scaleBy(x: scale, y: scale)
    let ink = CapoTheme.foreground
    let isNut = model.baseFret == 1
    let height = 5 * Layout.stringGap

    for i in 0..<Layout.fretCount {
      context.draw(
        Text("\(model.baseFret + i)").font(.system(size: 9)).foregroundStyle(ink.opacity(0.4)),
        at: CGPoint(x: Layout.midX(i + 1), y: Layout.padT - 14))
    }
    context.fill(
      Path(
        roundedRect: CGRect(
          x: Layout.padL - (isNut ? 4 : 1.5), y: Layout.padT, width: isNut ? 5 : 2, height: height),
        cornerRadius: 1),
      with: .color(ink.opacity(isNut ? 0.7 : 0.2)))
    for fret in 1...Layout.fretCount {
      var line = Path()
      line.move(to: CGPoint(x: Layout.divX(fret), y: Layout.padT))
      line.addLine(to: CGPoint(x: Layout.divX(fret), y: Layout.padT + height))
      context.stroke(line, with: .color(ink.opacity(0.15)), lineWidth: 0.75)
    }
    for string in 0..<6 {
      var line = Path()
      line.move(to: CGPoint(x: Layout.padL, y: Layout.y(string)))
      line.addLine(to: CGPoint(x: Layout.width - Layout.padR, y: Layout.y(string)))
      context.stroke(line, with: .color(ink.opacity(0.3)), lineWidth: 1.8 - CGFloat(string) * 0.2)
    }
    for marker in Layout.markers {
      let rel = marker - model.baseFret + 1
      guard rel >= 1, rel <= Layout.fretCount else { continue }
      let y = Layout.padT + height + Layout.padB * 0.55
      let x = Layout.midX(rel)
      let dots = marker == 12 ? [x - 4, x + 4] : [x]
      for dx in dots {
        let r: CGFloat = marker == 12 ? 2 : 2.5
        context.fill(
          Path(ellipseIn: CGRect(x: dx - r, y: y - r, width: r * 2, height: r * 2)),
          with: .color(ink.opacity(0.2)))
      }
    }
    for (string, label) in Layout.labels.enumerated() {
      context.draw(
        Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(ink.opacity(0.45)),
        at: CGPoint(x: 8, y: Layout.y(string)))
    }
    // X / O markers
    for string in 0..<6 {
      let cx = Layout.padL - 18
      let cy = Layout.y(string)
      let value = model.frets[string]
      if value == -1 {
        context.fill(
          Path(ellipseIn: CGRect(x: cx - 8, y: cy - 8, width: 16, height: 16)),
          with: .color(ink.opacity(0.8)))
        var cross = Path()
        cross.move(to: CGPoint(x: cx - 4, y: cy - 4)); cross.addLine(to: CGPoint(x: cx + 4, y: cy + 4))
        cross.move(to: CGPoint(x: cx + 4, y: cy - 4)); cross.addLine(to: CGPoint(x: cx - 4, y: cy + 4))
        context.stroke(
          cross, with: .color(CapoTheme.background),
          style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
      } else if value == 0 {
        context.stroke(
          Path(ellipseIn: CGRect(x: cx - 7, y: cy - 7, width: 14, height: 14)),
          with: .color(ink.opacity(0.5)), lineWidth: 1.5)
      } else {
        var cross = Path()
        cross.move(to: CGPoint(x: cx - 4, y: cy - 4)); cross.addLine(to: CGPoint(x: cx + 4, y: cy + 4))
        cross.move(to: CGPoint(x: cx + 4, y: cy - 4)); cross.addLine(to: CGPoint(x: cx - 4, y: cy + 4))
        context.stroke(
          cross, with: .color(ink.opacity(0.2)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
      }
    }
    for string in 0..<6 {
      let fret = model.frets[string]
      guard fret >= 1, fret <= Layout.fretCount else { continue }
      let c = CGPoint(x: Layout.midX(fret), y: Layout.y(string))
      context.fill(
        Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)),
        with: .color(ink.opacity(0.85)))
    }
  }
}
