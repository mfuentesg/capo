import CapoCore
import CapoDesign
import SwiftUI

private let zinc950 = Color(.sRGB, red: 9 / 255, green: 9 / 255, blue: 11 / 255)

/// Fretboard drawing for one fingering (port of `chord-position-diagram.tsx`, 242 x 186 units).
public struct FretboardView: View {
  let position: ChordPosition
  let geometry: ChordDiagramGeometry
  @Environment(\.colorScheme) private var scheme

  /// `mirror` is true for the left-hand setting (low string on the left), the web default.
  public init(position: ChordPosition, mirror: Bool = true) {
    self.position = position
    geometry = ChordDiagramGeometry(position: position, mirror: mirror)
  }

  public var body: some View {
    let ink = CapoTheme.foreground
    let onInk = scheme == .dark ? zinc950 : Color.white
    let halo = scheme == .dark ? zinc950 : Color.white
    let geometry = geometry
    Canvas { context, size in
      let scale = size.width / ChordDiagramGeometry.width
      context.scaleBy(x: scale, y: scale)

      context.fill(
        Path(roundedRect: geometry.nutRect, cornerRadius: 1),
        with: .color(ink.opacity(geometry.isNut ? 0.75 : 0.25)))
      for y in geometry.fretLineYs {
        var line = Path()
        line.move(to: CGPoint(x: geometry.nutRect.minX, y: y))
        line.addLine(to: CGPoint(x: geometry.nutRect.maxX, y: y))
        context.stroke(line, with: .color(ink.opacity(0.15)), lineWidth: 0.75)
      }
      for x in geometry.stringXs {
        var line = Path()
        line.move(to: CGPoint(x: x, y: geometry.top))
        line.addLine(to: CGPoint(x: x, y: geometry.bottom))
        context.stroke(line, with: .color(ink.opacity(0.25)), lineWidth: 0.75)
      }

      func fingerText(_ number: Int, at center: CGPoint) {
        guard number > 0 else { return }
        let text = context.resolve(
          Text("\(number)").font(.system(size: 11, weight: .bold)).foregroundStyle(onInk))
        context.draw(text, at: CGPoint(x: center.x, y: center.y + 0.5), anchor: .center)
      }

      for barre in geometry.barres {
        context.fill(Path(roundedRect: barre.rect, cornerRadius: 10), with: .color(ink.opacity(0.85)))
        fingerText(barre.finger, at: barre.center)
      }
      if let label = geometry.baseFretLabel {
        // 3 unit halo in the card colour, drawn under the glyph.
        let halo = context.resolve(
          Text("\(label.value)").font(.system(size: 14, weight: .bold)).foregroundStyle(halo))
        let glyph = context.resolve(
          Text("\(label.value)").font(.system(size: 14, weight: .bold)).foregroundStyle(ink))
        let center = CGPoint(x: label.center.x, y: label.center.y - 5)
        for step in 0..<8 {
          let angle = Double(step) * .pi / 4
          context.draw(
            halo, at: CGPoint(x: center.x + 1.5 * cos(angle), y: center.y + 1.5 * sin(angle)), anchor: .center)
        }
        context.draw(glyph, at: center, anchor: .center)
      }
      for dot in geometry.dots {
        let r = ChordDiagramGeometry.dotRadius
        context.fill(
          Path(ellipseIn: CGRect(x: dot.center.x - r, y: dot.center.y - r, width: r * 2, height: r * 2)),
          with: .color(ink.opacity(0.85)))
        fingerText(dot.finger, at: dot.center)
      }
      for marker in geometry.markers {
        let c = marker.center
        if marker.isMuted {
          var cross = Path()
          cross.move(to: CGPoint(x: c.x - 6, y: c.y - 6))
          cross.addLine(to: CGPoint(x: c.x + 6, y: c.y + 6))
          cross.move(to: CGPoint(x: c.x + 6, y: c.y - 6))
          cross.addLine(to: CGPoint(x: c.x - 6, y: c.y + 6))
          context.stroke(
            cross, with: .color(ink.opacity(0.65)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        } else {
          context.stroke(
            Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)),
            with: .color(ink.opacity(0.6)), lineWidth: 1.5)
        }
      }
    }
    .aspectRatio(ChordDiagramGeometry.width / ChordDiagramGeometry.height, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// The chord dialog: title, Verified/Generated subtitle, diagram card, dots pager, Previous/Next footer.
public struct ChordDiagramView: View {
  let chordName: String
  let result: ChordDiagramResult
  let onHandChange: ((ChordHand) -> Void)?
  @State private var hand: ChordHand
  @State private var index = 0
  @State private var forward = true
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.horizontalSizeClass) private var sizeClass

  /// `hand` is the stored preference; `onHandChange` persists a flip made with the LH/RH toggle.
  public init(
    chordName: String, hand: ChordHand = .default, onHandChange: ((ChordHand) -> Void)? = nil,
    database: ChordDatabase = .shared
  ) {
    self.chordName = chordName
    self.onHandChange = onHandChange
    result = database.resolve(chordName)
    _hand = State(initialValue: hand)
  }

  private var positions: [ChordPosition] { result.positions }
  private var current: Int { min(index, max(positions.count - 1, 0)) }
  private var roomy: Bool { sizeClass == .regular }

  public var body: some View {
    VStack(spacing: 0) {
      if positions.isEmpty {
        empty
      } else {
        content
        if positions.count > 1 { footer }
      }
    }
    .onChange(of: chordName) { index = 0 }
  }

  // MARK: Content

  private var content: some View {
    VStack(spacing: 20) {
      header
      let position = positions[current]
      ZStack {
        FretboardView(position: position, mirror: hand == .left)
          .id(current)
          .transition(
            reduceMotion
              ? .opacity
              : .asymmetric(
                insertion: .offset(x: forward ? 48 : -48).combined(with: .opacity), removal: .opacity))
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, roomy ? 32 : 16)
      .padding(.vertical, roomy ? 32 : 20)
      .background(
        scheme == .dark ? zinc950 : Color.white,
        in: RoundedRectangle(cornerRadius: roomy ? 24 : 16, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: roomy ? 24 : 16, style: .continuous)
          .strokeBorder(CapoTheme.border.opacity(0.5), lineWidth: 1)
      )
      .shadow(color: .black.opacity(scheme == .dark ? 0.3 : 0.1), radius: 25, x: 0, y: 20)
      .clipShape(RoundedRectangle(cornerRadius: roomy ? 24 : 16, style: .continuous))
      .gesture(swipe)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "\(chordName), "
          + ChordDiagramGeometry.spokenFrets(
            of: position, muted: ChordDiagramStrings.muted, open: ChordDiagramStrings.open)
      )
      if positions.count > 1 { pager }
    }
    .padding(.horizontal, 20)
    .padding(.top, 28)
    .padding(.bottom, 12)
    .frame(maxHeight: .infinity)
  }

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        Text(chordName)
          .font(CapoFont.ui(36, weight: .bold))
          .foregroundStyle(CapoTheme.foreground)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        Text(result.isGenerated ? ChordDiagramStrings.generated : ChordDiagramStrings.verified)
          .font(CapoFont.ui(12, weight: .medium))
          .tracking(1.8)
          .textCase(.uppercase)
          .foregroundStyle(CapoTheme.mutedForeground)
      }
      Spacer()
      handToggle
    }
  }

  /// LH / RH: flips the diagram and persists the preference.
  private var handToggle: some View {
    HStack(spacing: 0) {
      ForEach(ChordHand.allCases, id: \.self) { option in
        Button {
          guard hand != option else { return }
          hand = option
          onHandChange?(option)
        } label: {
          Text(option == .left ? ChordDiagramStrings.leftShort : ChordDiagramStrings.rightShort)
            .font(CapoFont.ui(13, weight: .semibold))
            .foregroundStyle(hand == option ? CapoTheme.primaryForeground : CapoTheme.mutedForeground)
            .frame(minWidth: 44, minHeight: 44)
            .background(
              hand == option ? CapoTheme.primary : Color.clear,
              in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option == .left ? L10n.Settings.leftHand : L10n.Settings.rightHand)
        .accessibilityAddTraits(hand == option ? .isSelected : [])
      }
    }
    .padding(2)
    .background(CapoTheme.muted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L10n.Settings.chordHand)
  }

  private var pager: some View {
    Group {
      if positions.count <= 12 {
        HStack(spacing: 6) {
          ForEach(positions.indices, id: \.self) { i in
            Button {
              go(to: i)
            } label: {
              Capsule()
                .fill(i == current ? CapoTheme.primary : CapoTheme.mutedForeground.opacity(0.3))
                .frame(width: i == current ? 24 : 6, height: 6)
                .frame(minWidth: 16, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ChordDiagramStrings.goTo(i + 1))
          }
        }
      } else {
        Text(ChordDiagramStrings.position(current + 1, of: positions.count))
          .font(CapoFont.ui(14, weight: .semibold).monospacedDigit())
          .foregroundStyle(CapoTheme.mutedForeground)
          .frame(minHeight: 44)
      }
    }
    .padding(.top, 4)
  }

  private var footer: some View {
    HStack(spacing: 0) {
      footerButton(
        title: L10n.Common.previous, symbol: "chevron.left", leading: true,
        label: ChordDiagramStrings.previous, tint: CapoTheme.foreground
      ) { step(-1) }
      Rectangle().fill(CapoTheme.border).frame(width: 1)
      footerButton(
        title: L10n.Common.next, symbol: "chevron.right", leading: false,
        label: ChordDiagramStrings.next, tint: CapoTheme.primary
      ) { step(1) }
    }
    .frame(height: 48)
    .background(CapoTheme.muted.opacity(0.3))
    .overlay(alignment: .top) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
  }

  private func footerButton(
    title: String, symbol: String, leading: Bool, label: String, tint: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if leading { Image(systemName: symbol).font(.system(size: 14, weight: .semibold)) }
        Text(title).font(CapoFont.ui(14, weight: .semibold))
        if !leading { Image(systemName: symbol).font(.system(size: 14, weight: .semibold)) }
      }
      .foregroundStyle(tint)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  /// No-diagram state: title, muted circle with an info glyph, and the message.
  private var empty: some View {
    VStack(spacing: 16) {
      Text(chordName)
        .font(CapoFont.ui(20, weight: .semibold))
        .foregroundStyle(CapoTheme.foreground)
      Circle()
        .fill(CapoTheme.muted)
        .frame(width: 48, height: 48)
        .overlay {
          Image(systemName: "info.circle")
            .font(.system(size: 24))
            .foregroundStyle(CapoTheme.mutedForeground)
        }
        .accessibilityHidden(true)
      Text(L10n.Chords.noDiagram)
        .font(CapoFont.ui(14))
        .foregroundStyle(CapoTheme.mutedForeground)
        .multilineTextAlignment(.center)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Paging

  private var swipe: some Gesture {
    DragGesture(minimumDistance: 20).onEnded { value in
      guard positions.count > 1, abs(value.translation.width) > 40 else { return }
      step(value.translation.width > 0 ? -1 : 1)
    }
  }

  private func step(_ delta: Int) {
    go(to: (current + delta + positions.count) % positions.count, forward: delta > 0)
  }

  private func go(to next: Int, forward isForward: Bool? = nil) {
    guard next != current else { return }
    forward = isForward ?? (next > current)
    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { index = next }
  }
}

enum ChordDiagramStrings {
  static var muted: String { L10n.Ios.ChordDiagram.muted }
  static var open: String { L10n.Ios.ChordDiagram.`open` }
  static var previous: String { L10n.Ios.ChordDiagram.previous }
  static var next: String { L10n.Ios.ChordDiagram.next }
  static var generated: String { L10n.Ios.ChordDiagram.generated }
  static var verified: String { L10n.Ios.ChordDiagram.verified }
  static var leftShort: String { L10n.Ios.ChordDiagram.leftHandShort }
  static var rightShort: String { L10n.Ios.ChordDiagram.rightHandShort }
  static func goTo(_ n: Int) -> String { L10n.Ios.ChordDiagram.goToPosition(n: String(n)) }
  static func position(_ n: Int, of total: Int) -> String {
    L10n.Ios.ChordDiagram.position(n: String(n), total: String(total))
  }
}
