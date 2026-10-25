import CapoCore
import CapoDesign
import CapoIcons
import Observation
import SwiftUI

/// Shared fullscreen flag, so a setlist can hide its own chrome together with the song's.
@MainActor @Observable
public final class StageChrome {
  public var isFullscreen = false
  public init() {
    #if DEBUG
      // Screenshot/validation hook: launch with `-CapoStageFullscreen YES`.
      isFullscreen = UserDefaults.standard.bool(forKey: "CapoStageFullscreen")
    #endif
  }
}

/// App-wide full-screen flag: the shell hides its sidebar and list while a song is full screen.
@Observable
@MainActor
public final class AppFullscreen {
  public static let shared = AppFullscreen()
  public var isActive = false
  private init() {}
}

// MARK: - Small controls

/// Rounded square icon button (header, dock handle).
struct StageIconButton: View {
  let systemImage: String
  let label: String
  var filled = false
  var size: CGFloat = 52
  var radius: CGFloat = 16
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(CapoFont.ui(size * 0.42, weight: .bold))
        .foregroundStyle(filled ? CapoTheme.onPrimary : CapoTheme.text)
        .frame(width: size, height: size)
        .background(
          filled ? CapoTheme.primary : CapoTheme.surface,
          in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

/// Section label used above dock controls.
private struct StageCaption: View {
  let text: String
  var size: CGFloat = 12
  init(_ text: String, size: CGFloat = 12) {
    self.text = text
    self.size = size
  }

  var body: some View {
    Text(text.uppercased())
      .font(CapoFont.ui(size, weight: .semibold))
      .tracking(size * 0.08)
      .foregroundStyle(CapoTheme.subtext)
      .lineLimit(1)
  }
}

/// 52pt "-" / "+" button with a light haptic on every step.
private struct StepButton: View {
  let icon: CapoIconName
  let label: String
  let isEnabled: Bool
  let trigger: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      CapoIcon(icon, size: 22, strokeWidth: 2.4)
        .foregroundStyle(CapoTheme.text)
        .frame(width: 52, height: 52)
        .background(CapoTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .opacity(isEnabled ? 1 : 0.35)
    .disabled(!isEnabled)
    .sensoryFeedback(.impact(weight: .light), trigger: trigger)
    .accessibilityHidden(true)
  }
}

/// Transpose / capo control: one adjustable element for VoiceOver.
struct StageStepper: View {
  let label: String
  let value: String
  let valueColor: Color
  let canDecrement: Bool
  let canIncrement: Bool
  let trigger: Int
  let compact: Bool
  let decrement: () -> Void
  let increment: () -> Void

  var body: some View {
    Group {
      if compact { boxed } else { stacked }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(value)
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: if canIncrement { increment() }
      case .decrement: if canDecrement { decrement() }
      @unknown default: break
      }
    }
  }

  private var minus: some View {
    StepButton(
      icon: .minus, label: label, isEnabled: canDecrement, trigger: trigger,
      action: decrement)
  }

  private var plus: some View {
    StepButton(
      icon: .plus, label: label, isEnabled: canIncrement, trigger: trigger,
      action: increment)
  }

  /// Regular width: caption above, buttons around a 26pt value.
  private var stacked: some View {
    VStack(spacing: 4) {
      StageCaption(label)
      HStack(spacing: 4) {
        minus
        Text(value)
          .font(CapoFont.ui(26, weight: .bold).monospacedDigit())
          .foregroundStyle(valueColor)
          .frame(minWidth: 58)
        plus
      }
    }
  }

  /// Phone: a 64pt inset box with the caption over the value.
  private var boxed: some View {
    HStack(spacing: 0) {
      minus
      Spacer(minLength: 0)
      VStack(spacing: 1) {
        StageCaption(label, size: 10)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(value)
          .font(CapoFont.ui(24, weight: .bold).monospacedDigit())
          .foregroundStyle(valueColor)
      }
      Spacer(minLength: 0)
      plus
    }
    .padding(.horizontal, 6)
    .frame(height: 64)
    .frame(maxWidth: .infinity)
    .background(CapoTheme.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}

/// Round peach play / pause button.
struct StagePlayButton: View {
  let isPlaying: Bool
  let size: CGFloat
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      CapoIcon(isPlaying ? .pause : .play, size: size * 0.4)
        .foregroundStyle(CapoTheme.onPrimary)
        .frame(width: size, height: size)
        .background(CapoTheme.primary, in: Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: isPlaying)
    .accessibilityLabel(
      isPlaying ? L10n.Songs.Lyrics.AutoScroll.stop : L10n.Songs.Lyrics.AutoScroll.start)
  }
}

/// Dock chrome: surface fill, hairline border, soft shadow.
private struct StagePanel: ViewModifier {
  let radius: CGFloat
  func body(content: Content) -> some View {
    content
      .background(CapoTheme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .strokeBorder(CapoTheme.border, lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
  }
}

extension View {
  fileprivate func stagePanel(radius: CGFloat) -> some View { modifier(StagePanel(radius: radius)) }
}

// MARK: - Progress rail

struct StageProgressRail: View {
  let metrics: StageScrollMetrics
  var width: CGFloat = 6

  var body: some View {
    GeometryReader { proxy in
      let height = proxy.size.height
      let thumb = max(height * metrics.thumbFraction, 16)
      ZStack(alignment: .top) {
        Capsule().fill(CapoTheme.surface)
        Capsule().fill(CapoTheme.primary)
          .frame(height: thumb)
          .offset(y: (height - thumb) * metrics.progress)
      }
    }
    .frame(width: width)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

// MARK: - Dock

/// Full control dock: steppers, text size, layout, auto-scroll, next song.
struct StageDock: View {
  @Bindable var model: SongPerformanceModel
  let navigation: PerformanceNavigation
  let compact: Bool
  @State private var showDisplayOptions = false

  var body: some View {
    Group {
      if compact { phone } else { pad }
    }
    .stagePanel(radius: 28)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(StageStrings.controlsToolbar)
  }

  // MARK: Steppers

  private var transposeStepper: some View {
    StageStepper(
      label: L10n.Songs.transpose, value: StageAutoScrollLabel.signed(model.settings.transpose),
      valueColor: model.settings.transpose == 0 ? CapoTheme.text : CapoTheme.primary,
      canDecrement: model.settings.canTransposeDown, canIncrement: model.settings.canTransposeUp,
      trigger: model.settings.transpose, compact: compact,
      decrement: { model.change { $0.transposeDown() } },
      increment: { model.change { $0.transposeUp() } })
  }

  private var capoStepper: some View {
    StageStepper(
      label: L10n.Songs.capo, value: "\(model.settings.capo)", valueColor: CapoTheme.text,
      canDecrement: model.settings.canCapoDown, canIncrement: model.settings.canCapoUp,
      trigger: model.settings.capo, compact: compact,
      decrement: { model.change { $0.capoDown() } },
      increment: { model.change { $0.capoUp() } })
  }

  // MARK: iPad

  private var pad: some View {
    ViewThatFits(in: .horizontal) {
      padRow(showsTitles: true, showsSlider: true)
      padRow(showsTitles: false, showsSlider: true)
      padRow(showsTitles: false, showsSlider: false)
    }
  }

  /// Previous / Next sit at the leading edge (the left thumb), play and the readout trail.
  private func padRow(showsTitles: Bool, showsSlider: Bool) -> some View {
    HStack(spacing: 22) {
      if hasSetNav { setNav(showsTitles: showsTitles) }
      transposeStepper
      capoStepper
      if showsSlider { textSizeSlider.frame(width: 150) }
      layoutToggles
      Spacer(minLength: 0)
      autoScrollReadout
      StagePlayButton(isPlaying: model.isAutoScrolling, size: 72) {
        model.isAutoScrolling.toggle()
      }
    }
    .padding(.horizontal, 20)
    .frame(height: 96)
  }

  private var hasSetNav: Bool { navigation.onPrevious != nil || navigation.onNext != nil }

  private func setNav(showsTitles: Bool) -> some View {
    SongSetNav(
      previousTitle: navigation.previousTitle, nextTitle: navigation.nextTitle,
      positionLabel: navigation.positionLabel, showsTitles: showsTitles,
      onPrevious: navigation.onPrevious, onNext: navigation.onNext)
  }

  private var textSizeSlider: some View {
    VStack(alignment: .leading, spacing: 6) {
      StageCaption(StageStrings.textSize)
      HStack(spacing: 8) {
        Text("Aa").font(CapoFont.ui(14)).foregroundStyle(CapoTheme.subtext)
        Slider(
          value: fontBinding, in: EffectiveSongSettings.fontSizeRange,
          step: EffectiveSongSettings.fontSizeStep
        )
        .tint(CapoTheme.primary)
        .accessibilityLabel(L10n.Songs.Lyrics.fontSize)
        Text("Aa").font(CapoFont.ui(22, weight: .semibold))
      }
    }
  }

  private var fontBinding: Binding<Double> {
    Binding(
      get: { model.settings.fontSize },
      set: { value in model.change { $0.fontSize = value } })
  }

  private var layoutToggles: some View {
    VStack(spacing: 4) {
      StageCaption(StageStrings.layout)
      HStack(spacing: 4) {
        chordsToggle(width: 52)
        columnsToggle(width: 52)
      }
      .padding(4)
      .background(CapoTheme.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private func chordsToggle(width: CGFloat) -> some View {
    Button {
      model.showChords.toggle()
    } label: {
      Text("C")
        .font(CapoFont.ui(18, weight: .bold))
        .foregroundStyle(model.showChords ? CapoTheme.chord : CapoTheme.subtext)
        .frame(width: width, height: 44)
        .background(
          model.showChords ? CapoTheme.surfaceStrong : Color.clear,
          in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: model.showChords)
    .accessibilityLabel(StageStrings.chordsToggle)
    .accessibilityAddTraits(model.showChords ? .isSelected : [])
  }

  private func columnsToggle(width: CGFloat) -> some View {
    Button {
      Task { await model.setColumns(model.columns == 2 ? 1 : 2) }
    } label: {
      CapoIcon(.columns2, size: 22)
        .foregroundStyle(model.columns == 2 ? CapoTheme.primary : CapoTheme.subtext)
        .frame(width: width, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: model.columns)
    .accessibilityLabel(StageStrings.columnsToggle)
    .accessibilityAddTraits(model.columns == 2 ? .isSelected : [])
  }

  private var autoScrollReadout: some View {
    HStack(spacing: 6) {
      speedButton(.turtle, L10n.Songs.Lyrics.AutoScroll.decreaseSpeed) { model.scrollSlower() }
        .disabled(model.scrollSpeed <= AutoScrollSpeed.minimum)
      VStack(alignment: .trailing, spacing: 1) {
        StageCaption(StageStrings.autoScroll)
        Text(StageAutoScrollLabel.speed(model.scrollSpeed))
          .font(CapoFont.ui(20, weight: .bold).monospacedDigit())
        if let bpm = StageAutoScrollLabel.tempoSource(bpm: model.song?.bpm) {
          Text(StageStrings.fromBPM(bpm)).font(CapoFont.ui(12)).foregroundStyle(CapoTheme.subtext)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(L10n.Songs.Lyrics.AutoScroll.speed)
      .accessibilityValue(StageAutoScrollLabel.speed(model.scrollSpeed))
      speedButton(.rabbit, L10n.Songs.Lyrics.AutoScroll.increaseSpeed) { model.scrollFaster() }
        .disabled(model.scrollSpeed >= AutoScrollSpeed.maximum)
    }
  }

  private func speedButton(_ icon: CapoIconName, _ label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      CapoIcon(icon, size: 18)
        .foregroundStyle(CapoTheme.text)
        .frame(width: 44, height: 44)
        .background(CapoTheme.surfaceStrong, in: Circle())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: model.scrollSpeed)
    .accessibilityLabel(label)
  }

  // MARK: Phone

  private var phone: some View {
    VStack(spacing: 10) {
      if hasSetNav && !navigation.isEmbedded {
        HStack(spacing: 0) {
          setNav(showsTitles: false)
          Spacer(minLength: 0)
        }
      }
      HStack(spacing: 8) {
        transposeStepper
        capoStepper
      }
      HStack(spacing: 8) {
        phoneSquare(label: StageStrings.textSize) {
          Text("Aa").font(CapoFont.ui(20, weight: .bold)).foregroundStyle(CapoTheme.text)
        } action: {
          showDisplayOptions = true
        }
        .popover(isPresented: $showDisplayOptions) { displayOptions }
        phoneSquare(label: StageStrings.chordsToggle) {
          Text("C").font(CapoFont.ui(22, weight: .bold))
            .foregroundStyle(model.showChords ? CapoTheme.chord : CapoTheme.subtext)
        } action: {
          model.showChords.toggle()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.showChords)
        Button {
          model.isAutoScrolling.toggle()
        } label: {
          HStack(spacing: 8) {
            CapoIcon(model.isAutoScrolling ? .pause : .play, size: 20, strokeWidth: 2.4)
            Text("\(StageStrings.scroll) · \(StageAutoScrollLabel.speed(model.scrollSpeed))")
              .font(CapoFont.ui(17, weight: .bold).monospacedDigit())
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .foregroundStyle(CapoTheme.onPrimary)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(CapoTheme.primary, in: Capsule())
          .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: model.isAutoScrolling)
        .accessibilityLabel(
          model.isAutoScrolling
            ? L10n.Songs.Lyrics.AutoScroll.stop : L10n.Songs.Lyrics.AutoScroll.start)
        .accessibilityValue(StageAutoScrollLabel.speed(model.scrollSpeed))
      }
    }
    .padding(12)
  }

  private func phoneSquare<Content: View>(
    label: String, @ViewBuilder content: () -> Content, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      content()
        .frame(width: 56, height: 56)
        .background(CapoTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }

  /// Phone popover: text size plus scroll speed, which have no room in the dock itself.
  private var displayOptions: some View {
    VStack(alignment: .leading, spacing: 18) {
      textSizeSlider
      HStack {
        StageCaption(L10n.Songs.Lyrics.AutoScroll.speed)
        Spacer()
        speedButton(.turtle, L10n.Songs.Lyrics.AutoScroll.decreaseSpeed) { model.scrollSlower() }
          .disabled(model.scrollSpeed <= AutoScrollSpeed.minimum)
        Text(StageAutoScrollLabel.speed(model.scrollSpeed))
          .font(CapoFont.ui(17, weight: .bold).monospacedDigit())
          .frame(minWidth: 70)
        speedButton(.rabbit, L10n.Songs.Lyrics.AutoScroll.increaseSpeed) { model.scrollFaster() }
          .disabled(model.scrollSpeed >= AutoScrollSpeed.maximum)
      }
    }
    .padding(20)
    .frame(width: 300)
    .background(CapoTheme.surface)
    .presentationCompactAdaptation(.popover)
  }
}

/// The collapsed dock: key shift, scroll speed, play / pause and an expand chevron.
struct StageCollapsedDock: View {
  @Bindable var model: SongPerformanceModel
  let onExpand: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      HStack(spacing: 6) {
        StageCaption(StageStrings.key)
        Text(StageAutoScrollLabel.signed(model.settings.transpose))
          .font(CapoFont.ui(24, weight: .bold).monospacedDigit())
          .foregroundStyle(model.settings.transpose == 0 ? CapoTheme.text : CapoTheme.primary)
      }
      Rectangle().fill(CapoTheme.border).frame(width: 1, height: 30)
      VStack(alignment: .leading, spacing: 0) {
        StageCaption(StageStrings.scroll)
        Text(StageAutoScrollLabel.speed(model.scrollSpeed))
          .font(CapoFont.ui(17, weight: .bold).monospacedDigit())
      }
      StagePlayButton(isPlaying: model.isAutoScrolling, size: 56) {
        model.isAutoScrolling.toggle()
      }
      Button(action: onExpand) {
        CapoIcon(.chevronUp, size: 20, strokeWidth: 2.4)
          .foregroundStyle(CapoTheme.text)
          .frame(width: 52, height: 52)
          .background(CapoTheme.surfaceStrong, in: Circle())
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(StageStrings.showControls)
    }
    .padding(.leading, 22)
    .padding(.trailing, 12)
    .frame(height: 76)
    .stagePanel(radius: 38)
    .contentShape(Rectangle())
    .onTapGesture(perform: onExpand)
    .gesture(
      DragGesture(minimumDistance: 12).onEnded { value in
        if StageFullscreen.isExpandSwipe(translation: value.translation) { onExpand() }
      }
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel(StageStrings.controlsToolbar)
  }
}

/// Small pill above the dock that collapses it.
struct StageDockHandle: View {
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      CapoIcon(.chevronDown, size: 16, strokeWidth: 2.4)
        .foregroundStyle(CapoTheme.subtext)
        .frame(width: 56, height: 28)
        .background(CapoTheme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(CapoTheme.border, lineWidth: 1))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(StageStrings.collapseControls)
  }
}

// MARK: - Full screen overlays

/// Centered title pill of the full-screen stage.
struct StageTitlePill: View {
  let title: String
  let info: StageKeyInfo?
  let capo: Int
  let positionLabel: String?

  var body: some View {
    HStack(spacing: 14) {
      Text(title).font(CapoFont.ui(18, weight: .bold)).lineLimit(1)
      if let info {
        divider
        HStack(spacing: 4) {
          Text(StageStrings.soundsIn)
          Text(info.soundsIn).fontWeight(.bold).foregroundStyle(CapoTheme.primary)
          if capo > 0 { Text("· \(StageStrings.capoShort(capo))") }
        }
        .font(CapoFont.ui(15))
        .foregroundStyle(CapoTheme.subtext)
      }
      if let positionLabel {
        divider
        Text(positionLabel).font(CapoFont.ui(15).monospacedDigit()).foregroundStyle(CapoTheme.subtext)
      }
    }
    .foregroundStyle(CapoTheme.text)
    .padding(.horizontal, 22)
    .frame(height: 52)
    .background(CapoTheme.surface.opacity(0.92), in: Capsule())
    .overlay(Capsule().strokeBorder(CapoTheme.border, lineWidth: 1))
    .fixedSize()
  }

  private var divider: some View {
    Rectangle().fill(CapoTheme.surfaceStrong).frame(width: 1, height: 20)
  }
}

/// Right-edge "next song" tab of the full-screen stage.
struct StageNextTab: View {
  let title: String?
  let onNext: () -> Void

  var body: some View {
    Button(action: onNext) {
      VStack(spacing: 10) {
        CapoIcon(.chevronLeft, size: 20, strokeWidth: 2.6)
        if let title {
          Text(title)
            .font(CapoFont.ui(14, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .rotationEffect(.degrees(90))
            .frame(width: 18, height: min(CGFloat(title.count) * 8, 110))
        }
      }
      .foregroundStyle(CapoTheme.text)
      .frame(width: 46, height: 180)
      .background(
        CapoTheme.surface.opacity(0.92),
        in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22)
      )
      .overlay(
        UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22)
          .strokeBorder(CapoTheme.border, lineWidth: 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title.map(StageStrings.nextSong) ?? L10n.Ios.Performance.nextSong)
  }
}

/// Phone setlist: title, artist and the key to play, inside the scrolling page.
struct SetlistSongHeading: View {
  let song: Song
  @Bindable var model: SongPerformanceModel

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(song.title)
          .font(CapoFont.ui(28, weight: .bold))
          .accessibilityAddTraits(.isHeader)
        if let subtitle {
          Text(subtitle).font(CapoFont.ui(15)).foregroundStyle(CapoTheme.subtext)
        }
      }
      Spacer(minLength: 0)
      if let info {
        VStack(spacing: 0) {
          Text(StageStrings.play.uppercased())
            .font(CapoFont.ui(10, weight: .bold)).tracking(0.8)
            .foregroundStyle(CapoTheme.subtext)
          Text(info.playShapesIn ?? info.soundsIn)
            .font(CapoFont.ui(26, weight: .bold))
            .foregroundStyle(CapoTheme.primary)
          if model.settings.capo > 0 {
            Text(StageStrings.capoShort(model.settings.capo))
              .font(CapoFont.ui(11)).foregroundStyle(CapoTheme.subtext)
          }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(minWidth: 64)
        .background(CapoTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
          "\(StageStrings.play) \(info.playShapesIn ?? info.soundsIn)"
            + (model.settings.capo > 0 ? ", \(StageStrings.capoShort(model.settings.capo))" : ""))
      }
    }
  }

  private var info: StageKeyInfo? {
    StageKeyInfo(key: song.key, transpose: model.settings.transpose, capo: model.settings.capo)
  }

  private var subtitle: String? {
    var parts: [String] = []
    if let artist = song.artist, !artist.isEmpty { parts.append(artist) }
    if let bpm = song.bpm, bpm > 0 { parts.append("\(bpm) \(L10n.Songs.bpm)") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}
