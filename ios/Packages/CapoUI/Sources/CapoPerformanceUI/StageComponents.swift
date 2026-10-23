import CapoCore
import CapoDesign
import SwiftUI

/// Shared fullscreen flag, so a setlist can hide its own chrome together with the song's.
@MainActor @Observable
public final class StageChrome {
  public var isFullscreen = false
  public init() {}
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
  let systemImage: String
  let label: String
  let isEnabled: Bool
  let trigger: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(CapoFont.ui(20, weight: .heavy))
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
      systemImage: "minus", label: label, isEnabled: canDecrement, trigger: trigger,
      action: decrement)
  }

  private var plus: some View {
    StepButton(
      systemImage: "plus", label: label, isEnabled: canIncrement, trigger: trigger,
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
      Image(systemName: isPlaying ? "pause.fill" : "play.fill")
        .font(CapoFont.ui(size * 0.42, weight: .bold))
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
    HStack(spacing: 22) {
      transposeStepper
      capoStepper
      textSizeSlider.frame(width: 150)
      layoutToggles
      Spacer(minLength: 0)
      autoScrollReadout
      StagePlayButton(isPlaying: model.isAutoScrolling, size: 72) {
        model.isAutoScrolling.toggle()
      }
      if navigation.onPrevious != nil { previousButton }
      if navigation.onNext != nil { nextButton }
    }
    .padding(.horizontal, 20)
    .frame(height: 96)
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
      Image(systemName: model.columns == 2 ? "rectangle.split.2x1" : "rectangle")
        .font(CapoFont.ui(20, weight: .semibold))
        .foregroundStyle(CapoTheme.primary)
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
      speedButton("tortoise", L10n.Songs.Lyrics.AutoScroll.decreaseSpeed) { model.scrollSlower() }
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
      speedButton("hare", L10n.Songs.Lyrics.AutoScroll.increaseSpeed) { model.scrollFaster() }
        .disabled(model.scrollSpeed >= AutoScrollSpeed.maximum)
    }
  }

  private func speedButton(_ symbol: String, _ label: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Image(systemName: symbol)
        .font(CapoFont.ui(16, weight: .semibold))
        .foregroundStyle(CapoTheme.text)
        .frame(width: 44, height: 44)
        .background(CapoTheme.surfaceStrong, in: Circle())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: model.scrollSpeed)
    .accessibilityLabel(label)
  }

  private var previousButton: some View {
    Button {
      navigation.onPrevious?()
    } label: {
      Image(systemName: "chevron.left")
        .font(CapoFont.ui(20, weight: .bold))
        .foregroundStyle(CapoTheme.text)
        .frame(width: 56, height: 72)
        .background(
          CapoTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.Ios.Performance.previousSong)
  }

  private var nextButton: some View {
    Button {
      navigation.onNext?()
    } label: {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 1) {
          StageCaption(StageStrings.next)
          if let title = navigation.nextTitle {
            Text(title).font(CapoFont.ui(16, weight: .semibold)).lineLimit(1)
          }
        }
        Image(systemName: "chevron.right").font(CapoFont.ui(18, weight: .bold))
      }
      .foregroundStyle(CapoTheme.text)
      .padding(.horizontal, 18)
      .frame(height: 72)
      .frame(maxWidth: 220)
      .background(CapoTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      navigation.nextTitle.map(StageStrings.nextSong) ?? L10n.Ios.Performance.nextSong)
  }

  // MARK: Phone

  private var phone: some View {
    VStack(spacing: 10) {
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
            Image(systemName: model.isAutoScrolling ? "pause.fill" : "play.fill")
              .font(CapoFont.ui(20, weight: .bold))
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
        speedButton("tortoise", L10n.Songs.Lyrics.AutoScroll.decreaseSpeed) { model.scrollSlower() }
          .disabled(model.scrollSpeed <= AutoScrollSpeed.minimum)
        Text(StageAutoScrollLabel.speed(model.scrollSpeed))
          .font(CapoFont.ui(17, weight: .bold).monospacedDigit())
          .frame(minWidth: 70)
        speedButton("hare", L10n.Songs.Lyrics.AutoScroll.increaseSpeed) { model.scrollFaster() }
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
        Image(systemName: "chevron.up")
          .font(CapoFont.ui(18, weight: .heavy))
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
      Image(systemName: "chevron.down")
        .font(CapoFont.ui(14, weight: .heavy))
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

// MARK: - Header and full screen overlays

struct StageHeader: View {
  let song: Song
  @Bindable var model: SongPerformanceModel
  let navigation: PerformanceNavigation
  let canEdit: Bool
  let compact: Bool
  let showsBack: Bool
  let onBack: () -> Void
  let onEdit: () -> Void
  let onFullscreen: () -> Void

  var body: some View {
    HStack(spacing: compact ? 8 : 16) {
      if showsBack {
        StageIconButton(
          systemImage: "chevron.left", label: StageStrings.back, size: compact ? 48 : 52,
          radius: compact ? 14 : 16, action: onBack)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(song.title)
          .font(CapoFont.ui(compact ? 20 : 26, weight: .bold))
          .lineLimit(1)
          .accessibilityAddTraits(.isHeader)
        Text(subtitle)
          .font(CapoFont.ui(compact ? 13 : 15))
          .foregroundStyle(CapoTheme.subtext)
          .lineLimit(1)
      }
      if !compact, let info { keyChip(info) }
      Spacer(minLength: 0)
      if !compact, canEdit {
        StageIconButton(
          systemImage: "pencil", label: L10n.Common.edit, action: onEdit)
      }
      StageIconButton(
        systemImage: "arrow.up.left.and.arrow.down.right", label: StageStrings.enterFullscreen,
        filled: true, size: compact ? 48 : 52, radius: compact ? 14 : 16, action: onFullscreen)
      menu
    }
    .padding(.horizontal, compact ? 12 : 24)
    .padding(.vertical, compact ? 10 : 16)
    .background(CapoTheme.sidebar.ignoresSafeArea(edges: .top))
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.surface).frame(height: 1) }
  }

  private var menu: some View {
    Menu {
      if compact, canEdit {
        Button(L10n.Common.edit, systemImage: "pencil", action: onEdit)
      }
      Button(L10n.Songs.reset, systemImage: "arrow.counterclockwise") { model.reset() }
    } label: {
      Image(systemName: "ellipsis")
        .font(CapoFont.ui(compact ? 18 : 22, weight: .bold))
        .foregroundStyle(CapoTheme.text)
        .frame(width: compact ? 48 : 52, height: compact ? 48 : 52)
        .background(
          CapoTheme.surface, in: RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
    }
    .accessibilityLabel(StageStrings.more)
  }

  private var info: StageKeyInfo? {
    StageKeyInfo(key: song.key, transpose: model.settings.transpose, capo: model.settings.capo)
  }

  private var subtitle: String {
    if compact, let info {
      let base = "\(StageStrings.soundsIn) \(info.soundsIn)"
      return info.playShapesIn.map { "\(base) · \(StageStrings.playShapesIn.lowercased()) \($0)" }
        ?? base
    }
    var parts: [String] = []
    if let artist = song.artist, !artist.isEmpty { parts.append(artist) }
    if let label = navigation.positionLabel { parts.append(label) }
    if !compact, let bpm = song.bpm, bpm > 0 { parts.append("\(bpm) \(L10n.Songs.bpm)") }
    return parts.joined(separator: " · ")
  }

  private func keyChip(_ info: StageKeyInfo) -> some View {
    HStack(spacing: 10) {
      chipLabel(StageStrings.soundsIn, info.soundsIn, color: CapoTheme.primary)
      if let shapes = info.playShapesIn {
        Rectangle().fill(CapoTheme.surfaceStrong).frame(width: 1, height: 22)
        chipLabel(StageStrings.playShapesIn, shapes, color: CapoTheme.text)
      }
    }
    .padding(.horizontal, 16)
    .frame(height: 52)
    .background(CapoTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(StageStrings.soundsIn) \(info.soundsIn)"
        + (info.playShapesIn.map { ", \(StageStrings.playShapesIn) \($0)" } ?? ""))
  }

  private func chipLabel(_ caption: String, _ value: String, color: Color) -> some View {
    HStack(spacing: 10) {
      StageCaption(caption, size: 13)
      Text(value).font(CapoFont.ui(22, weight: .bold)).foregroundStyle(color)
    }
  }
}

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
        Image(systemName: "chevron.left").font(CapoFont.ui(18, weight: .heavy))
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
