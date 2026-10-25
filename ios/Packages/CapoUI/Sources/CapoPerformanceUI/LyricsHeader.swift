import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

/// Web lyrics header (`lyrics-view.tsx` 354-523): three rows on `bg-card` with a bottom border.
/// Row 1 back + title, row 2 artist, key and BPM badges with the actions, row 3 tags and the
/// active-setting chips. iOS adds the full-screen button.
struct LyricsHeader: View {
  let song: Song
  @Bindable var model: SongPerformanceModel
  let navigation: PerformanceNavigation
  let canEdit: Bool
  let compact: Bool
  let showsBack: Bool
  let onBack: () -> Void
  var onShowList: (() -> Void)?
  let onEdit: () -> Void
  let onFullscreen: () -> Void
  @State private var showSettings = false
  @Environment(\.capoUIScale) private var scale

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      titleRow
      detailRow.padding(.top, 2)
      if hasThirdRow { chipRow.padding(.top, 2).padding(.bottom, 4) }
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, hasThirdRow ? 0 : 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CapoTheme.card.ignoresSafeArea(edges: .top))
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
  }

  private var hasThirdRow: Bool { !model.tags.isEmpty || !model.chips.isEmpty }

  // MARK: Row 1

  private var titleRow: some View {
    HStack(spacing: 6) {
      if showsBack { backButton }
      Text(song.title)
        .capoText(.base, weight: .semibold)
        .foregroundStyle(CapoTheme.foreground)
        .lineLimit(1)
        .accessibilityAddTraits(.isHeader)
      if let position = navigation.positionLabel {
        Text(position).capoText(.xs).monospacedDigit().foregroundStyle(CapoTheme.mutedForeground)
      }
      Spacer(minLength: 0)
      if let onShowList, let label = navigation.queue?.buttonLabel {
        SongQueueButton(label: label, action: onShowList)
      }
    }
    .frame(minHeight: 32 * scale)
  }

  /// Arrow plus the name of the screen it returns to, tinted primary, then a hairline divider.
  @ViewBuilder private var backButton: some View {
    if let label = navigation.backLabel, !compact {
      Button(action: onBack) {
        HStack(spacing: 4) {
          CapoIcon(.arrowLeft, size: 16)
          Text(label).capoText(.sm, weight: .medium).lineLimit(1)
        }
        .foregroundStyle(CapoTheme.primary)
        .padding(.horizontal, 8)
        .frame(minHeight: 36 * scale)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(StageStrings.back)
      Rectangle().fill(CapoTheme.border).frame(width: 1, height: 18).padding(.horizontal, 2)
    } else {
      LyricsHeaderButton(icon: .arrowLeft, label: StageStrings.back, size: 32, action: onBack)
    }
  }

  // MARK: Row 2

  private var detailRow: some View {
    HStack(spacing: 4) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          if let artist = song.artist, !artist.isEmpty {
            Text(artist).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(1)
          }
          if let key = model.displayKey { HeaderBadge(text: key, style: .secondary, mono: true) }
          if let shapes = model.capoShapeKey {
            HeaderBadge(text: "\(StageStrings.play) \(shapes)", style: .outline)
          }
          if let bpm = song.bpm, bpm > 0 { bpmBadge(bpm) }
        }
        .padding(.leading, 4)
      }
      .scrollBounceBehavior(.basedOnSize)
      .frame(maxWidth: .infinity, alignment: .leading)
      actions
    }
  }

  private func bpmBadge(_ bpm: Int) -> some View {
    let icon: CapoIconName =
      switch DisplaySettingsLogic.Tempo(bpm: bpm) {
      case .slow: .turtle
      case .medium: .rabbit
      case .fast: .zap
      }
    return HeaderBadge(text: "\(bpm) \(L10n.Songs.bpm)", style: .outline, icon: icon)
  }

  private var actions: some View {
    HStack(spacing: 2) {
      if canEdit {
        LyricsHeaderButton(icon: .pencil, label: L10n.Songs.editLyrics, action: onEdit)
      }
      if let text = shareText {
        ShareLink(item: text) {
          CapoIcon(.share2, size: 16)
            .foregroundStyle(CapoTheme.foreground)
            .frame(width: 36 * scale, height: 36 * scale)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(L10n.Songs.shareLyrics)
      }
      LyricsHeaderButton(
        icon: nil, systemImage: "arrow.up.left.and.arrow.down.right",
        label: StageStrings.enterFullscreen, action: onFullscreen)
      settingsButton
      menu
    }
  }

  private var shareText: String? {
    guard let lyrics = song.lyrics, !lyrics.isEmpty else { return nil }
    return lyrics
  }

  private var settingsButton: some View {
    LyricsHeaderButton(
      icon: .settings2, label: L10n.Songs.Lyrics.settings, action: { showSettings = true }
    )
    .overlay(alignment: .topTrailing) {
      if model.isDisplayModified { PingDot().offset(x: -6, y: 6) }
    }
    .popover(isPresented: $showSettings, arrowEdge: .top) {
      DisplaySettingsPopover(model: model)
        .presentationCompactAdaptation(.popover)
    }
  }

  private var menu: some View {
    Menu {
      Button(L10n.Songs.reset, systemImage: "arrow.counterclockwise") { model.reset() }
    } label: {
      CapoIcon(.moreVertical, size: 16)
        .foregroundStyle(CapoTheme.foreground)
        .frame(width: 36 * scale, height: 36 * scale)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(StageStrings.more)
  }

  // MARK: Row 3

  private var chipRow: some View {
    FlowRow(spacing: 6) {
      ForEach(model.tags) { tag in TagPill(tag: tag) }
      ForEach(model.chips) { chip in
        SettingChip(chip: chip) { model.reset(chip.kind) }
      }
    }
    .padding(.leading, 4)
  }
}

// MARK: - Pieces

/// 36 px ghost icon button of the web header.
struct LyricsHeaderButton: View {
  let icon: CapoIconName?
  var systemImage: String?
  let label: String
  var size: CGFloat = 36
  let action: () -> Void
  @Environment(\.capoUIScale) private var scale

  init(
    icon: CapoIconName?, systemImage: String? = nil, label: String, size: CGFloat = 36,
    action: @escaping () -> Void
  ) {
    self.icon = icon
    self.systemImage = systemImage
    self.label = label
    self.size = size
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      Group {
        if let icon { CapoIcon(icon, size: 16) } else if let systemImage {
          Image(systemName: systemImage).font(.system(size: 14, weight: .semibold))
        }
      }
      .foregroundStyle(CapoTheme.foreground)
      .frame(width: size * scale, height: size * scale)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
  }
}

struct HeaderBadge: View {
  enum Style { case secondary, outline }
  let text: String
  let style: Style
  var mono = false
  var icon: CapoIconName?

  var body: some View {
    HStack(spacing: 6) {
      if let icon { CapoIcon(icon, size: 12) }
      Text(text).font(mono ? CapoFont.mono(12, weight: .medium) : CapoFont.ui(12, weight: .medium))
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(.horizontal, 8)
    .frame(height: 22)
    .background(style == .secondary ? CapoTheme.secondary : Color.clear, in: Capsule())
    .overlay(Capsule().strokeBorder(style == .outline ? CapoTheme.border : .clear, lineWidth: 1))
    .fixedSize()
  }
}

/// Read-only tag chip: `#name` on a 18% tint (the web's TagBadge).
struct TagPill: View {
  let tag: SongTag

  var body: some View {
    let color = HexColor.tagColor(tag.color)
    HStack(spacing: 2) {
      Text("#").opacity(0.6)
      Text(tag.name).lineLimit(1)
    }
    .font(CapoFont.ui(11, weight: .medium))
    .foregroundStyle(color)
    .padding(.horizontal, 8)
    .frame(height: 22)
    .background(color.opacity(0.18), in: Capsule())
    .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
    .accessibilityElement(children: .combine)
  }
}

/// Active-setting chip: icon, "Transpose +2", x. Tapping resets that setting.
struct SettingChip: View {
  let chip: DisplaySettingsLogic.Chip
  let onReset: () -> Void

  var body: some View {
    Button(action: onReset) {
      HStack(spacing: 4) {
        icon
        Text(text).font(CapoFont.ui(11, weight: .medium))
        CapoIcon(.x, size: 10)
      }
      .foregroundStyle(CapoTheme.accentSongs)
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
      .background(CapoTheme.accentSongs.opacity(0.10), in: Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(L10n.Songs.reset) \(text)")
  }

  @ViewBuilder private var icon: some View {
    switch chip.kind {
    case .transpose: CapoIcon(.music2, size: 12)
    case .capo: CapoIcon(.guitar, size: 12)
    case .fontSize: Text("Aa").font(CapoFont.ui(11, weight: .bold))
    }
  }

  private var text: String {
    switch chip.kind {
    case .transpose: "\(L10n.Songs.transpose) \(chip.value)"
    case .capo: "\(L10n.Songs.capo) \(chip.value)"
    case .fontSize: "\(L10n.Songs.Lyrics.fontSize) \(chip.value)"
    }
  }
}

/// 8 px primary dot that pings while the display settings are modified.
struct PingDot: View {
  @State private var ping = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      Circle().fill(CapoTheme.primary.opacity(0.6))
        .scaleEffect(ping ? 2.2 : 1)
        .opacity(ping ? 0 : 0.8)
      Circle().fill(CapoTheme.primary)
    }
    .frame(width: 8, height: 8)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) { ping = true }
    }
  }
}

/// Wrapping row of fixed-size chips.
struct FlowRow: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    arrange(width: proposal.width ?? .infinity, subviews: subviews).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = arrange(width: bounds.width, subviews: subviews)
    for (index, origin) in result.origins.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
    }
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
    var origins: [CGPoint] = []
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var usedWidth: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > 0, x + size.width > width {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      origins.append(CGPoint(x: x, y: y))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      usedWidth = max(usedWidth, x - spacing)
    }
    return (CGSize(width: usedWidth, height: y + rowHeight), origins)
  }
}

// MARK: - Display settings popover

/// "Display Settings" popover: font size, transpose, capo, column layout and visibility, each with
/// its own Reset (`lyrics-view.tsx` 536-726).
struct DisplaySettingsPopover: View {
  @Bindable var model: SongPerformanceModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text(L10n.Songs.Lyrics.displaySettings)
          .capoText(.base, weight: .medium)
          .accessibilityAddTraits(.isHeader)
        Text(L10n.Songs.Lyrics.displaySettingsDescription)
          .capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
      }
      divider
      fontSize
      divider
      transpose
      divider
      capo
      divider
      layout
      divider
      visibility
    }
    .padding(16)
    .frame(width: 372)
    .background(CapoTheme.popover)
  }

  private var divider: some View { Rectangle().fill(CapoTheme.border).frame(height: 1) }

  private func group<Content: View>(
    _ title: String, @ViewBuilder icon: () -> some View, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        icon().foregroundStyle(CapoTheme.foreground)
        Text(title).capoText(.sm, weight: .medium)
      }
      content()
    }
  }

  private func stepper(
    value: String, unit: String? = nil, valueIcon: some View, canDecrement: Bool,
    canIncrement: Bool, isDefault: Bool, decrement: @escaping () -> Void,
    increment: @escaping () -> Void, reset: @escaping () -> Void, label: String
  ) -> some View {
    HStack(spacing: 8) {
      Button(action: decrement) { CapoIcon(.minus, size: 16) }
        .buttonStyle(CapoSecondaryButtonStyle(size: .small))
        .disabled(!canDecrement)
        .accessibilityLabel("\(StageStrings.decrease) \(label)")
      HStack(spacing: 8) {
        valueIcon.foregroundStyle(CapoTheme.mutedForeground)
        Text(value).capoText(.sm, weight: .medium).monospacedDigit().lineLimit(1)
        if let unit { Text(unit).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground) }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .frame(minWidth: 80)
      .background(CapoTheme.secondary, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(label)
      .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
      Button(action: increment) { CapoIcon(.plus, size: 16) }
        .buttonStyle(CapoSecondaryButtonStyle(size: .small))
        .disabled(!canIncrement)
        .accessibilityLabel("\(StageStrings.increase) \(label)")
      Button(L10n.Songs.reset, action: reset)
        .capoText(.xs, weight: .medium)
        .foregroundStyle(CapoTheme.foreground)
        .padding(.horizontal, 12)
        .frame(minHeight: CapoMetrics.minHitTarget)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .opacity(isDefault ? 0.5 : 1)
        .disabled(isDefault)
    }
    .sensoryFeedback(.impact(weight: .light), trigger: value)
  }

  private var fontSize: some View {
    group(
      L10n.Songs.Lyrics.fontSize,
      icon: { Text("Aa").font(CapoFont.ui(14, weight: .bold)) }
    ) {
      stepper(
        value: DisplaySettingsLogic.fontLabel(model.settings.fontSize),
        valueIcon: Text("Aa").font(CapoFont.ui(12, weight: .bold)),
        canDecrement: model.settings.canFontDown, canIncrement: model.settings.canFontUp,
        isDefault: model.settings.fontSize == model.defaults.fontSize,
        decrement: { model.change { $0.fontDown() } },
        increment: { model.change { $0.fontUp() } },
        reset: { model.reset(.fontSize) }, label: L10n.Songs.Lyrics.fontSize)
    }
  }

  private var transpose: some View {
    group(L10n.Songs.transpose, icon: { CapoIcon(.music2, size: 16) }) {
      stepper(
        value: DisplaySettingsLogic.signed(model.settings.transpose), unit: L10n.Songs.semitones,
        valueIcon: CapoIcon(.music2, size: 14),
        canDecrement: model.settings.canTransposeDown, canIncrement: model.settings.canTransposeUp,
        isDefault: model.settings.transpose == model.defaults.transpose,
        decrement: { model.change { $0.transposeDown() } },
        increment: { model.change { $0.transposeUp() } },
        reset: { model.reset(.transpose) }, label: L10n.Songs.transpose)
    }
  }

  private var capo: some View {
    group(L10n.Songs.capo, icon: { CapoIcon(.guitar, size: 16) }) {
      stepper(
        value: model.settings.capo == 0
          ? L10n.Songs.none : "\(L10n.Songs.fret) \(model.settings.capo)",
        valueIcon: CapoIcon(.guitar, size: 14),
        canDecrement: model.settings.canCapoDown, canIncrement: model.settings.canCapoUp,
        isDefault: model.settings.capo == model.defaults.capo,
        decrement: { model.change { $0.capoDown() } },
        increment: { model.change { $0.capoUp() } },
        reset: { model.reset(.capo) }, label: L10n.Songs.capo)
    }
  }

  private var layout: some View {
    group(L10n.Songs.Lyrics.columnLayout, icon: { CapoIcon(.columns2, size: 16) }) {
      HStack(spacing: 8) {
        choice(L10n.Songs.Lyrics.oneColumn, selected: model.columns == 1) {
          Task { await model.setColumns(1) }
        }
        choice(L10n.Songs.Lyrics.twoColumns, selected: model.columns == 2) {
          Task { await model.setColumns(2) }
        }
      }
    }
  }

  private var visibility: some View {
    group(L10n.Songs.Lyrics.visibility, icon: { CapoIcon(.eye, size: 16) }) {
      HStack(spacing: 8) {
        choice(
          L10n.Songs.Lyrics.showChordsLabel, selected: model.showChords, icon: .guitar
        ) { model.setChords(!model.showChords) }
        choice(
          L10n.Songs.Lyrics.showLyricsLabel, selected: model.showLyrics, glyph: "Aa"
        ) { model.setLyrics(!model.showLyrics) }
      }
    }
  }

  @ViewBuilder
  private func choice(
    _ title: String, selected: Bool, icon: CapoIconName? = nil, glyph: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    let label = HStack(spacing: 8) {
      if let icon { CapoIcon(icon, size: 16) }
      if let glyph { Text(glyph).font(CapoFont.ui(13, weight: .bold)) }
      Text(title)
    }
    .frame(maxWidth: .infinity)
    if selected {
      Button(action: action) { label }
        .buttonStyle(CapoPrimaryButtonStyle(size: .small))
        .accessibilityAddTraits(.isSelected)
    } else {
      Button(action: action) { label }.buttonStyle(CapoSecondaryButtonStyle(size: .small))
    }
  }
}
