import CapoDesign
import SwiftUI

/// Fretboard drawing for one fingering.
public struct FretboardView: View {
  let position: ChordPosition
  let layout: FretboardLayout
  let accent: Color?

  /// `accent` colours the finger dots and barres (the stage uses the chord mauve).
  public init(position: ChordPosition, accent: Color? = nil) {
    self.position = position
    layout = FretboardLayout(position: position)
    self.accent = accent
  }

  public var body: some View {
    Canvas { context, size in
      let marker: CGFloat = 18
      let left: CGFloat = layout.fretLabel == nil ? 8 : 28
      let board = CGRect(
        x: left, y: marker + 6, width: size.width - left - 8, height: size.height - marker - 12)
      let ink = CapoTheme.text
      var lines = Path()
      for string in 0..<layout.stringCount {
        let x = board.minX + layout.stringX(string, width: board.width)
        lines.move(to: CGPoint(x: x, y: board.minY))
        lines.addLine(to: CGPoint(x: x, y: board.maxY))
      }
      for fret in 0...FretboardLayout.visibleFrets {
        let y = board.minY + board.height * CGFloat(fret) / CGFloat(FretboardLayout.visibleFrets)
        lines.move(to: CGPoint(x: board.minX, y: y))
        lines.addLine(to: CGPoint(x: board.maxX, y: y))
      }
      context.stroke(lines, with: .color(CapoTheme.subtext.opacity(0.7)), lineWidth: 1)
      if layout.baseFret == 1 {
        context.fill(
          Path(CGRect(x: board.minX, y: board.minY - 2, width: board.width, height: 4)),
          with: .color(ink))
      }
      let fingers = accent ?? ink
      let radius = min(board.width / CGFloat(max(layout.stringCount - 1, 1)) * 0.36, 11)
      for barre in layout.barres {
        let y = board.minY + layout.rowY(barre.row, height: board.height)
        let x1 = board.minX + layout.stringX(barre.fromString, width: board.width)
        let x2 = board.minX + layout.stringX(barre.toString, width: board.width)
        let rect = CGRect(x: x1 - radius, y: y - radius, width: x2 - x1 + radius * 2, height: radius * 2)
        context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(fingers))
      }
      for dot in layout.dots {
        let x = board.minX + layout.stringX(dot.string, width: board.width)
        let y = board.minY + layout.rowY(dot.row, height: board.height)
        context.fill(
          Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
          with: .color(fingers))
      }
      for string in layout.openStrings {
        let x = board.minX + layout.stringX(string, width: board.width)
        context.stroke(
          Path(ellipseIn: CGRect(x: x - 5, y: board.minY - 17, width: 10, height: 10)),
          with: .color(ink), lineWidth: 1.5)
      }
      for string in layout.mutedStrings {
        let x = board.minX + layout.stringX(string, width: board.width)
        var cross = Path()
        cross.move(to: CGPoint(x: x - 4, y: board.minY - 16))
        cross.addLine(to: CGPoint(x: x + 4, y: board.minY - 8))
        cross.move(to: CGPoint(x: x + 4, y: board.minY - 16))
        cross.addLine(to: CGPoint(x: x - 4, y: board.minY - 8))
        context.stroke(cross, with: .color(ink), lineWidth: 1.5)
      }
      if let label = layout.fretLabel {
        context.draw(
          Text("\(label)").font(CapoFont.style(.caption).monospacedDigit()).foregroundStyle(CapoTheme.subtext),
          at: CGPoint(x: board.minX - 14, y: board.minY + layout.rowY(0, height: board.height)))
      }
    }
    .aspectRatio(0.8, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// A chord's fingerings with an instrument switch and paging between positions.
public struct ChordDiagramView: View {
  let chordName: String
  let database: ChordDatabase
  @State private var instrument: ChordInstrument
  @State private var index = 0

  public init(
    chordName: String, instrument: ChordInstrument = .guitar, database: ChordDatabase = .shared
  ) {
    self.chordName = chordName
    self.database = database
    _instrument = State(initialValue: instrument)
  }

  private var positions: [ChordPosition] { database.positions(for: chordName, instrument: instrument) }

  public var body: some View {
    let positions = positions
    VStack(spacing: 14) {
      HStack {
        Text(chordName)
          .font(CapoFont.ui(28, weight: .bold))
          .foregroundStyle(CapoTheme.chord)
        Spacer()
        instrumentSwitch
      }
      if positions.isEmpty {
        Text(L10n.Chords.notFound).foregroundStyle(CapoTheme.subtext).padding(.vertical, 24)
      } else {
        let current = positions[min(index, positions.count - 1)]
        FretboardView(position: current, accent: CapoTheme.chord)
          .frame(maxWidth: 200)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(
            "\(chordName), "
              + FretboardLayout.spokenFrets(
                of: current, muted: ChordDiagramStrings.muted, open: ChordDiagramStrings.open)
          )
        HStack {
          pagerButton("chevron.left", ChordDiagramStrings.previous, count: positions.count) {
            step(-1, count: positions.count)
          }
          Spacer()
          Text(ChordDiagramStrings.position(min(index, positions.count - 1) + 1, of: positions.count))
            .font(CapoFont.ui(14, weight: .semibold).monospacedDigit())
            .foregroundStyle(CapoTheme.subtext)
          Spacer()
          pagerButton("chevron.right", ChordDiagramStrings.next, count: positions.count) {
            step(1, count: positions.count)
          }
        }
      }
    }
    .padding(20)
    .onChange(of: instrument) { index = 0 }
    .onChange(of: chordName) { index = 0 }
  }

  /// Guitar / Ukulele pill switch on the dark inset.
  private var instrumentSwitch: some View {
    HStack(spacing: 0) {
      ForEach([ChordInstrument.guitar, .ukulele], id: \.self) { option in
        Button {
          instrument = option
        } label: {
          Text(option == .guitar ? ChordDiagramStrings.guitar : ChordDiagramStrings.ukulele)
            .font(CapoFont.ui(14, weight: .semibold))
            .foregroundStyle(instrument == option ? CapoTheme.text : CapoTheme.subtext)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
              instrument == option ? CapoTheme.surfaceStrong : Color.clear,
              in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(instrument == option ? .isSelected : [])
      }
    }
    .padding(3)
    .background(CapoTheme.background, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(ChordDiagramStrings.instrument)
  }

  private func pagerButton(
    _ symbol: String, _ label: String, count: Int, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(CapoFont.ui(16, weight: .bold))
        .foregroundStyle(CapoTheme.text)
        .frame(width: 56, height: 44)
        .background(CapoTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(count < 2 ? 0.35 : 1)
    .disabled(count < 2)
    .accessibilityLabel(label)
  }

  private func step(_ delta: Int, count: Int) {
    index = (index + delta + count) % count
  }
}

enum ChordDiagramStrings {
  static var instrument: String {
    L10n.Ios.ChordDiagram.instrument
  }
  static var guitar: String {
    L10n.Ios.ChordDiagram.guitar
  }
  static var ukulele: String {
    L10n.Ios.ChordDiagram.ukulele
  }
  static var muted: String {
    L10n.Ios.ChordDiagram.muted
  }
  static var open: String {
    L10n.Ios.ChordDiagram.`open`
  }
  static var previous: String {
    L10n.Ios.ChordDiagram.previous
  }
  static var next: String {
    L10n.Ios.ChordDiagram.next
  }
  static func position(_ n: Int, of total: Int) -> String {
    L10n.Ios.ChordDiagram.position(n: String(n), total: String(total))
  }
}
