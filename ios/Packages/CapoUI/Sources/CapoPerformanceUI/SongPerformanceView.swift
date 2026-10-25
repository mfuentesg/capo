import CapoCore
import CapoDesign
import CapoRendering
import SwiftUI
import UIKit

public struct PerformanceNavigation {
  public var positionLabel: String?
  public var onNext: (@MainActor () -> Void)?
  public var onPrevious: (@MainActor () -> Void)?
  /// Title of the following song, for the dock's NEXT button and the full-screen edge tab.
  public var nextTitle: String?
  /// True inside a setlist, which provides its own close button, header and (on phones) a
  /// bottom bar of `dockBottomInset` points.
  public var isEmbedded: Bool
  public var dockBottomInset: Double
  /// Shared full-screen flag; a standalone screen makes its own.
  public var chrome: StageChrome?
  /// Title of the preceding song, for the Previous half of the set nav.
  public var previousTitle: String?
  /// Label of the back button in the pushed page header (the screen it returns to).
  public var backLabel: String?
  /// Songs of the current context, listed by the header's slide-over.
  public var queue: SongQueue?
  /// Called with the song picked in the slide-over.
  public var onSelectSong: ((SongID) -> Void)?

  public init(
    positionLabel: String? = nil, onNext: (@MainActor () -> Void)? = nil,
    onPrevious: (@MainActor () -> Void)? = nil, nextTitle: String? = nil,
    isEmbedded: Bool = false, dockBottomInset: Double = 0, chrome: StageChrome? = nil,
    previousTitle: String? = nil, backLabel: String? = nil, queue: SongQueue? = nil,
    onSelectSong: ((SongID) -> Void)? = nil
  ) {
    self.positionLabel = positionLabel
    self.onNext = onNext
    self.onPrevious = onPrevious
    self.nextTitle = nextTitle
    self.isEmbedded = isEmbedded
    self.dockBottomInset = dockBottomInset
    self.chrome = chrome
    self.previousTitle = previousTitle
    self.backLabel = backLabel
    self.queue = queue
    self.onSelectSong = onSelectSong
  }

  /// Wires Previous / Next / position to the neighbours of a song in its queue. Nothing happens
  /// without `onSelectSong`, since there is no way to open the other song.
  @MainActor func applying(
    neighbors: SongNeighbors?, onSelectSong select: ((SongID) -> Void)?
  ) -> PerformanceNavigation {
    var nav = self
    nav.onSelectSong = select
    guard let neighbors, let select else { return nav }
    nav.positionLabel = neighbors.positionLabel
    nav.previousTitle = neighbors.previous?.title
    nav.nextTitle = neighbors.next?.title
    if let previous = neighbors.previous {
      let id = previous.id
      nav.onPrevious = { select(id) }
    }
    if let next = neighbors.next {
      let id = next.id
      nav.onNext = { select(id) }
    }
    return nav
  }

  public static let standalone = PerformanceNavigation()
}

/// One song on stage: rendered ChordPro, transpose/capo/font/columns, auto-scroll, pedal keys.
public struct SongPerformanceView: View {
  let songID: SongID
  let navigation: PerformanceNavigation
  let queue: SongQueue?
  let neighbors: SongNeighbors?
  let onSelectSong: ((SongID) -> Void)?
  @Environment(\.userServices) private var services

  /// A full-width pushed page. With a `queue` (or explicit `neighbors`) and `onSelectSong`, the
  /// page shows Previous / Next in the bottom-left thumb zone and, for a queue, a header button
  /// that slides the song list in from the leading edge.
  public init(
    songID: SongID, navigation: PerformanceNavigation = .standalone, queue: SongQueue? = nil,
    neighbors: SongNeighbors? = nil, backLabel: String? = nil,
    onSelectSong: ((SongID) -> Void)? = nil
  ) {
    self.songID = songID
    var nav = navigation
    if let backLabel { nav.backLabel = backLabel }
    self.navigation = nav
    self.queue = queue
    self.neighbors = neighbors
    self.onSelectSong = onSelectSong
  }

  public var body: some View {
    SongPerformanceScreen(songID: songID, services: services, navigation: resolvedNavigation)
      .id(songID)
  }

  private var resolvedNavigation: PerformanceNavigation {
    guard !navigation.isEmbedded else { return navigation }
    var nav = navigation.applying(
      neighbors: neighbors ?? queue.flatMap { SongNeighbors(queue: $0, current: songID) },
      onSelectSong: onSelectSong)
    nav.queue = queue
    return nav
  }
}

struct SongPerformanceScreen: View {
  let services: UserServices
  let navigation: PerformanceNavigation
  @State private var model: SongPerformanceModel
  @State private var scrollProxy = PerformanceScrollProxy()
  @State private var diagramChord: DiagramChord?
  @State private var ownChrome = StageChrome()
  @State private var metrics = StageScrollMetrics()
  @State private var titlePill = TitlePillVisibility()
  @State private var titlePillVisible = false
  @State private var transientDockExpanded = false
  @State private var showQueue = false
  @AppStorage(StageDockPreference.defaultsKey) private var dockExpanded = true
  @AppStorage(FloatingControlsPreference.enabledKey) private var floatingControls = false
  @State private var floatingOpen = {
    #if DEBUG
      UserDefaults.standard.bool(forKey: "CapoFloatingOpen")  // screenshot hook
    #else
      false
    #endif
  }()
  @Environment(\.teamRoles) private var teamRoles
  @Environment(\.capoActions) private var actions
  @Environment(\.horizontalSizeClass) private var sizeClass
  @Environment(\.isPresented) private var isPresented
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(songID: SongID, services: UserServices, navigation: PerformanceNavigation) {
    self.services = services
    self.navigation = navigation
    _model = State(
      initialValue: SongPerformanceModel(
        songID: songID, settingsRepository: services.settings,
        sectionLabels: SongPerformanceModel.localizedSectionLabels,
        commentLabel: L10n.SongSections.comment))
  }

  private var chrome: StageChrome { navigation.chrome ?? ownChrome }
  private var isFullscreen: Bool { chrome.isFullscreen }
  /// Width of this pane; a narrow detail column (portrait iPad, collapsed split) gets the phone layout.
  @State private var paneWidth: CGFloat = 1000
  private var compact: Bool { sizeClass == .compact || paneWidth < 720 }
  /// A phone setlist and full screen both start from the pill; the persisted choice is for the
  /// plain stage.
  private var usesTransientDock: Bool { isFullscreen || (navigation.isEmbedded && compact) }
  private var showsInlineHeading: Bool { navigation.isEmbedded && compact && !isFullscreen }
  private var showsFullDock: Bool {
    StageFullscreen.showsFullDock(
      persisted: dockExpanded, transient: transientDockExpanded, usesTransient: usesTransientDock)
  }

  var body: some View {
    ZStack {
      CapoTheme.background.ignoresSafeArea()
      if let song = model.song {
        stage(song)
      } else if model.isLoaded {
        EmptyStateView(title: L10n.Chords.notFound, message: nil, icon: .music)
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      shortcutHost
      queueOverlay
    }
    .toolbar(.hidden, for: .navigationBar)
    .background {
      GeometryReader { proxy in
        Color.clear
          .onAppear { paneWidth = proxy.size.width }
          .onChange(of: proxy.size.width) { _, width in paneWidth = width }
      }
    }
    .onChange(of: isFullscreen) { _, value in AppFullscreen.shared.isActive = value }
    .onAppear { AppFullscreen.shared.isActive = isFullscreen }
    .onDisappear { AppFullscreen.shared.isActive = false }
    .statusBarHidden(isFullscreen)
    .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
    .task(id: model.songID) {
      for await song in services.songs.song(id: model.songID) { model.apply(song: song) }
    }
    .task(id: model.songID) {
      for await settings in services.settings.songSettings(songID: model.songID) {
        model.apply(userSettings: settings)
      }
    }
    .task(id: model.songID) {
      for await tags in services.songs.tags(forSong: model.songID) { model.apply(tags: tags) }
    }
    .task {
      for await preferences in services.settings.preferences() { model.apply(preferences: preferences) }
    }
    .task(id: titlePill.shownAt) {
      guard titlePill.shownAt != nil else { return }
      try? await Task.sleep(for: .seconds(TitlePillVisibility.duration))
      guard !Task.isCancelled else { return }
      animate { titlePillVisible = false }
    }
    .sheet(item: $diagramChord) { chord in
      ChordDiagramView(
        chordName: chord.name, hand: model.chordHand,
        onHandChange: { hand in Task { await model.setChordHand(hand) } }
      )
      .presentationDetents([.fraction(0.85), .large])
      .presentationDragIndicator(.visible)
      .presentationBackground(CapoTheme.background)
    }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onChange(of: published) { _, snapshot in CurrentPerformance.shared.snapshot = snapshot }
    .onAppear { CurrentPerformance.shared.snapshot = published }
    .onDisappear {
      CurrentPerformance.shared.snapshot = nil
      UIApplication.shared.isIdleTimerDisabled = false
      model.isAutoScrolling = false
      Task { await model.flushPendingSave() }
    }
  }

  // MARK: Layout

  private func stage(_ song: Song) -> some View {
    VStack(spacing: 0) {
      if !isFullscreen && !showsInlineHeading {
        LyricsHeader(
          song: song, model: model, navigation: navigation,
          canEdit: teamRoles.canEdit(teamID: song.teamID), compact: compact,
          showsBack: !navigation.isEmbedded && isPresented, onBack: { dismiss() },
          onShowList: queueEnabled ? { showQueue = true } : nil,
          onEdit: { actions.openEditor(.edit(song.id)) }, onFullscreen: toggleFullscreen)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
      content(song)
        .overlay(alignment: .trailing) { rail }
        .overlay(alignment: .bottom) { if !floatingControls { dockArea } }
        .overlay { if floatingControls { floatingArea } }
        .overlay { if isFullscreen { fullscreenOverlay(song) } }
        .background { controlsModeShortcut }
    }
  }

  @ViewBuilder
  private func content(_ song: Song) -> some View {
    if (song.lyrics ?? "").isEmpty {
      EmptyStateView(title: L10n.Songs.noLyrics, message: nil, icon: .listMusic)
    } else {
      PerformanceScrollView(
        proxy: scrollProxy,
        isAutoScrolling: model.isAutoScrolling,
        speed: model.scrollSpeed,
        onAction: handle,
        onAutoScrollStopped: { model.isAutoScrolling = false },
        onContentMeasured: { model.contentMeasured(scrollableHeight: $0) },
        onMetrics: { metrics = $0 },
        onTap: { if isFullscreen { showTitlePill() } },
        onDoubleTap: toggleFullscreen
      ) {
        VStack(alignment: .leading, spacing: 18) {
          if showsInlineHeading { SetlistSongHeading(song: song, model: model) }
          ChordProContentView(
            rendered: model.rendered, style: style,
            onChordTap: { diagramChord = DiagramChord(name: $0) })
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, isFullscreen ? 44 : 24)
        .padding(.bottom, dockReserve)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .ignoresSafeArea(.container, edges: isFullscreen ? [.top, .bottom] : .bottom)
    }
  }

  private var horizontalPadding: CGFloat { isFullscreen ? 64 : (compact ? 18 : 40) }

  /// Space under the last line so the floating dock never hides it.
  private var dockReserve: CGFloat {
    let inset = CGFloat(navigation.dockBottomInset)
    if floatingControls { return 80 + inset }
    if showsFullDock { return (compact ? 220 : 170) + inset }
    return 130 + inset
  }

  private var rail: some View {
    StageProgressRail(metrics: metrics, width: compact ? 4 : 6)
      .padding(.trailing, compact ? 5 : 12)
      .padding(.vertical, isFullscreen ? 90 : 24)
      .padding(.bottom, isFullscreen ? 100 : CGFloat(navigation.dockBottomInset))
      .opacity(metrics.isScrollable ? 1 : 0)
  }

  private var dockArea: some View {
    VStack(spacing: 8) {
      if showsFullDock {
        ZStack {
          StageDockHandle { setDock(expanded: false) }
          HStack {
            Spacer()
            Button {
              floatingOpen = false
              floatingControls = true
            } label: {
              Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(CapoTheme.subtext)
                .frame(width: 44, height: 44)
                .background(CapoTheme.surface, in: Circle())
                .overlay(Circle().strokeBorder(CapoTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(StageStrings.floatControls)
          }
        }
        StageDock(model: model, navigation: navigation, compact: compact)
      } else {
        StageCollapsedDock(model: model) { setDock(expanded: true) }
      }
    }
    .padding(.horizontal, compact ? 10 : 40)
    .padding(.bottom, 22 + CGFloat(navigation.dockBottomInset))
    .frame(maxWidth: .infinity)
  }

  /// ⌘⇧D switches between the docked bar and the floating button (hardware keyboard).
  private var controlsModeShortcut: some View {
    Button(floatingControls ? StageStrings.dockControls : StageStrings.floatControls) {
      floatingOpen = false
      floatingControls.toggle()
    }
    .keyboardShortcut("d", modifiers: [.command, .shift])
    .opacity(0)
    .frame(width: 0, height: 0)
    .accessibilityHidden(true)
  }

  /// The controls as one draggable button; its panel is the same dock, plus a way back to the bar.
  private var floatingArea: some View {
    FloatingControls(
      isOpen: $floatingOpen, isPlaying: model.isAutoScrolling,
      topInset: isFullscreen ? 56 : 0, bottomInset: isFullscreen ? 34 : 0
    ) {
      VStack(spacing: 8) {
        StageDock(model: model, navigation: navigation, compact: compact)
        Button {
          floatingOpen = false
          floatingControls = false
        } label: {
          Label(StageStrings.dockControls, systemImage: "dock.rectangle")
            .font(CapoFont.ui(14, weight: .semibold))
            .foregroundStyle(CapoTheme.text)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(CapoTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(CapoTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func fullscreenOverlay(_ song: Song) -> some View {
    ZStack(alignment: .topLeading) {
      Color.clear
      StageIconButton(
        systemImage: "arrow.down.right.and.arrow.up.left", label: StageStrings.exitFullscreen,
        size: 52, radius: 26, action: toggleFullscreen
      )
      .opacity(0.92)
      .padding(20)
      .keyboardShortcut(.escape, modifiers: [])
      if titlePillVisible {
        StageTitlePill(
          title: song.title,
          info: StageKeyInfo(
            key: song.key, transpose: model.settings.transpose, capo: model.settings.capo),
          capo: model.settings.capo, positionLabel: navigation.positionLabel
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .transition(.opacity)
      }
      if navigation.onNext != nil {
        StageNextTab(title: navigation.nextTitle) { navigation.onNext?() }
          .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
              if value.translation.width < -40 { navigation.onNext?() }
            }
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
      }
    }
    .allowsHitTesting(true)
  }

  private var queueEnabled: Bool {
    !navigation.isEmbedded && navigation.queue != nil && navigation.onSelectSong != nil
  }

  @ViewBuilder private var queueOverlay: some View {
    if queueEnabled, !isFullscreen, let queue = navigation.queue, let select = navigation.onSelectSong {
      SongQueueOverlay(isPresented: $showQueue, queue: queue, current: model.songID, onSelect: select)
    }
  }

  /// ⌃⌘F, as on macOS apps; the visible buttons carry the labels.
  private var shortcutHost: some View {
    Button(action: toggleFullscreen) { Color.clear }
      .keyboardShortcut("f", modifiers: [.control, .command])
      .frame(width: 0, height: 0)
      .opacity(0)
      .accessibilityHidden(true)
  }

  // MARK: Actions

  private func toggleFullscreen() {
    let entering = !isFullscreen
    animate { chrome.isFullscreen = entering }
    if entering {
      transientDockExpanded = false
      showTitlePill()
    }
  }

  private func showTitlePill() {
    titlePill.show()
    animate { titlePillVisible = true }
  }

  private func setDock(expanded: Bool) {
    animate {
      if usesTransientDock { transientDockExpanded = expanded } else { dockExpanded = expanded }
    }
  }

  private func animate(_ change: () -> Void) {
    if reduceMotion { change() } else { withAnimation(.easeInOut(duration: 0.22), change) }
  }

  private var published: CurrentPerformance.Snapshot? {
    guard let song = model.song else { return nil }
    return CurrentPerformance.Snapshot(
      title: song.title, subtitle: song.artist, rendered: model.rendered,
      fontScale: model.settings.fontSize, showChords: model.showChords)
  }

  private var style: SongRenderStyle {
    var style = SongRenderStyle()
    let base = StageFullscreen.fontScale(base: model.settings.fontSize, isFullscreen: isFullscreen)
    // Two columns stay on a narrow pane; the text shrinks until they fit.
    let fit = ColumnFit.scale(
      contentWidth: paneWidth - 2 * horizontalPadding,
      columns: paneWidth >= ColumnFit.narrowestTwoColumnPane ? model.columns : 1, fontScale: base)
    style.fontScale = base * fit
    style.columns = model.columns
    style.minTwoColumnWidth = ColumnFit.minTwoColumnWidth(pane: paneWidth)
    style.showChords = model.showChords
    style.showLyrics = model.showLyrics
    style.commentLabel = L10n.SongSections.comment
    return style
  }

  private func handle(_ action: PerformanceAction) {
    switch action {
    case .pageDown:
      // At the bottom, the page-turn pedal moves on to the next song.
      if !scrollProxy.pageDown() { navigation.onNext?() }
    case .pageUp: scrollProxy.pageUp()
    case .nextSong: navigation.onNext?()
    case .previousSong: navigation.onPrevious?()
    case .toggleAutoScroll: model.isAutoScrolling.toggle()
    case .scrollSlower: model.scrollSlower()
    case .scrollFaster: model.scrollFaster()
    case .increaseFont: model.change { $0.fontUp() }
    case .decreaseFont: model.change { $0.fontDown() }
    }
  }
}

private struct DiagramChord: Identifiable {
  let name: String
  var id: String { name }
}
