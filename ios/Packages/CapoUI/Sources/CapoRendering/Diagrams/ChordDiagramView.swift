import CapoDesign
import SwiftUI

/// Fretboard drawing for one fingering.
public struct FretboardView: View {
  let position: ChordPosition
  let layout: FretboardLayout

  public init(position: ChordPosition) {
    self.position = position
    layout = FretboardLayout(position: position)
  }

  public var body: some View {
    Canvas { context, size in
      let marker: CGFloat = 18
      let left: CGFloat = layout.fretLabel == nil ? 8 : 28
      let board = CGRect(
        x: left, y: marker + 6, width: size.width - left - 8, height: size.height - marker - 12)
      let ink = Color.primary
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
      context.stroke(lines, with: .color(ink.opacity(0.45)), lineWidth: 1)
      if layout.baseFret == 1 {
        context.fill(
          Path(CGRect(x: board.minX, y: board.minY - 2, width: board.width, height: 4)),
          with: .color(ink))
      }
      let radius = min(board.width / CGFloat(max(layout.stringCount - 1, 1)) * 0.36, 11)
      for barre in layout.barres {
        let y = board.minY + layout.rowY(barre.row, height: board.height)
        let x1 = board.minX + layout.stringX(barre.fromString, width: board.width)
        let x2 = board.minX + layout.stringX(barre.toString, width: board.width)
        let rect = CGRect(x: x1 - radius, y: y - radius, width: x2 - x1 + radius * 2, height: radius * 2)
        context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(ink))
      }
      for dot in layout.dots {
        let x = board.minX + layout.stringX(dot.string, width: board.width)
        let y = board.minY + layout.rowY(dot.row, height: board.height)
        context.fill(
          Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
          with: .color(ink))
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
          Text("\(label)").font(.caption.monospacedDigit()).foregroundStyle(.secondary),
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
    VStack(spacing: 12) {
      Text(chordName).font(.title2.weight(.semibold))
      Picker(ChordDiagramStrings.instrument, selection: $instrument) {
        Text(ChordDiagramStrings.guitar).tag(ChordInstrument.guitar)
        Text(ChordDiagramStrings.ukulele).tag(ChordInstrument.ukulele)
      }
      .pickerStyle(.segmented)
      if positions.isEmpty {
        Text(L10n.Chords.notFound).foregroundStyle(.secondary).padding(.vertical, 24)
      } else {
        let current = positions[min(index, positions.count - 1)]
        FretboardView(position: current)
          .frame(maxWidth: 200)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(
            "\(chordName), "
              + FretboardLayout.spokenFrets(
                of: current, muted: ChordDiagramStrings.muted, open: ChordDiagramStrings.open)
          )
        HStack {
          Button(ChordDiagramStrings.previous, systemImage: "chevron.left") { step(-1, count: positions.count) }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .disabled(positions.count < 2)
          Text(ChordDiagramStrings.position(min(index, positions.count - 1) + 1, of: positions.count))
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
          Button(ChordDiagramStrings.next, systemImage: "chevron.right") { step(1, count: positions.count) }
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .disabled(positions.count < 2)
        }
      }
    }
    .padding(20)
    .onChange(of: instrument) { index = 0 }
    .onChange(of: chordName) { index = 0 }
  }

  private func step(_ delta: Int, count: Int) {
    index = (index + delta + count) % count
  }
}

enum ChordDiagramStrings {
  // TODO(i18n): harvested by B1 into the string catalogs.
  static var instrument: String {
    String(localized: "ios.chordDiagram.instrument", defaultValue: "Instrument", bundle: .module)
  }
  static var guitar: String {
    String(localized: "ios.chordDiagram.guitar", defaultValue: "Guitar", bundle: .module)
  }
  static var ukulele: String {
    String(localized: "ios.chordDiagram.ukulele", defaultValue: "Ukulele", bundle: .module)
  }
  static var muted: String {
    String(localized: "ios.chordDiagram.muted", defaultValue: "muted", bundle: .module)
  }
  static var open: String {
    String(localized: "ios.chordDiagram.open", defaultValue: "open", bundle: .module)
  }
  static var previous: String {
    String(localized: "ios.chordDiagram.previous", defaultValue: "Previous position", bundle: .module)
  }
  static var next: String {
    String(localized: "ios.chordDiagram.next", defaultValue: "Next position", bundle: .module)
  }
  static func position(_ n: Int, of total: Int) -> String {
    let format = String(
      localized: "ios.chordDiagram.position", defaultValue: "Position %lld of %lld", bundle: .module)
    return String(format: format, n, total)
  }
}
