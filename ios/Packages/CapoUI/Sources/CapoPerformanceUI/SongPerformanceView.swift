import CapoCore
import CapoDesign
import CapoRendering
import SwiftUI
import UIKit

public struct PerformanceNavigation {
  public var positionLabel: String?
  public var onNext: (@MainActor () -> Void)?
  public var onPrevious: (@MainActor () -> Void)?

  public init(
    positionLabel: String? = nil, onNext: (@MainActor () -> Void)? = nil,
    onPrevious: (@MainActor () -> Void)? = nil
  ) {
    self.positionLabel = positionLabel
    self.onNext = onNext
    self.onPrevious = onPrevious
  }

  public static let standalone = PerformanceNavigation()
}

/// One song on stage: rendered ChordPro, transpose/capo/font/columns, auto-scroll, pedal keys.
public struct SongPerformanceView: View {
  let songID: SongID
  let navigation: PerformanceNavigation
  @Environment(\.userServices) private var services

  public init(songID: SongID, navigation: PerformanceNavigation = .standalone) {
    self.songID = songID
    self.navigation = navigation
  }

  public var body: some View {
    SongPerformanceScreen(songID: songID, services: services, navigation: navigation)
      .id(songID)
  }
}

struct SongPerformanceScreen: View {
  let services: UserServices
  let navigation: PerformanceNavigation
  @State private var model: SongPerformanceModel
  @State private var scrollProxy = PerformanceScrollProxy()
  @State private var diagramChord: DiagramChord?
  @Environment(\.currentTeamRole) private var role
  @Environment(\.capoActions) private var actions

  init(songID: SongID, services: UserServices, navigation: PerformanceNavigation) {
    self.services = services
    self.navigation = navigation
    _model = State(
      initialValue: SongPerformanceModel(
        songID: songID, settingsRepository: services.settings,
        sectionLabels: SongPerformanceModel.localizedSectionLabels,
        commentLabel: L10n.SongSections.comment))
  }

  var body: some View {
    VStack(spacing: 0) {
      if let song = model.song {
        PerformanceHeader(
          song: song, model: model, navigation: navigation,
          canEdit: role?.canEditContent ?? true,
          onEdit: { actions.openEditor(.edit(song.id)) })
        Divider()
        content(song)
      } else if model.isLoaded {
        EmptyStateView(title: L10n.Chords.notFound, message: nil, systemImage: "music.note")
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .task(id: model.songID) {
      for await song in services.songs.song(id: model.songID) { model.apply(song: song) }
    }
    .task(id: model.songID) {
      for await settings in services.settings.songSettings(songID: model.songID) {
        model.apply(userSettings: settings)
      }
    }
    .task {
      for await preferences in services.settings.preferences() { model.apply(preferences: preferences) }
    }
    .sheet(item: $diagramChord) { chord in
      ChordDiagramView(chordName: chord.name)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      model.isAutoScrolling = false
      Task { await model.flushPendingSave() }
    }
  }

  @ViewBuilder
  private func content(_ song: Song) -> some View {
    if (song.lyrics ?? "").isEmpty {
      EmptyStateView(title: L10n.Songs.noLyrics, message: nil, systemImage: "music.note.list")
    } else {
      PerformanceScrollView(
        proxy: scrollProxy,
        isAutoScrolling: model.isAutoScrolling,
        speed: model.scrollSpeed,
        onAction: handle,
        onAutoScrollStopped: { model.isAutoScrolling = false },
        onContentMeasured: { model.contentMeasured(scrollableHeight: $0) }
      ) {
        ChordProContentView(
          rendered: model.rendered, style: style,
          onChordTap: { diagramChord = DiagramChord(name: $0) }
        )
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var style: SongRenderStyle {
    var style = SongRenderStyle()
    style.fontScale = model.settings.fontSize
    style.columns = model.columns
    style.showChords = model.showChords
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

/// Title, key info and the control bar.
private struct PerformanceHeader: View {
  let song: Song
  @Bindable var model: SongPerformanceModel
  let navigation: PerformanceNavigation
  let canEdit: Bool
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(song.title).font(.title2.weight(.semibold)).lineLimit(1)
          if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
        }
        Spacer()
        if let label = navigation.positionLabel {
          Text(label).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        if canEdit {
          Button(L10n.Common.edit, systemImage: "pencil", action: onEdit).labelStyle(.iconOnly)
        }
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          Stepper(
            label: L10n.Songs.transpose, value: transposeLabel,
            canDecrement: model.settings.canTransposeDown, canIncrement: model.settings.canTransposeUp,
            decrement: { model.change { $0.transposeDown() } },
            increment: { model.change { $0.transposeUp() } })
          Stepper(
            label: L10n.Songs.capo, value: capoLabel,
            canDecrement: model.settings.canCapoDown, canIncrement: model.settings.canCapoUp,
            decrement: { model.change { $0.capoDown() } },
            increment: { model.change { $0.capoUp() } })
          Stepper(
            label: L10n.Songs.Lyrics.fontSize,
            value: "\(Int((model.settings.fontSize * 100).rounded()))%",
            canDecrement: model.settings.canFontDown, canIncrement: model.settings.canFontUp,
            decrement: { model.change { $0.fontDown() } },
            increment: { model.change { $0.fontUp() } })
          Button(L10n.Songs.reset) { model.reset() }
          Divider().frame(height: 24)
          Picker(L10n.Songs.Lyrics.columnLayout, selection: columnsBinding) {
            Text(L10n.Songs.Lyrics.oneColumn).tag(1)
            Text(L10n.Songs.Lyrics.twoColumns).tag(2)
          }
          .pickerStyle(.segmented)
          .fixedSize()
          Toggle(L10n.Songs.Lyrics.showChordsLabel, isOn: $model.showChords).fixedSize()
          Divider().frame(height: 24)
          autoScrollControls
          if navigation.onPrevious != nil || navigation.onNext != nil { songNavigation }
        }
        .padding(.vertical, 2)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  private var subtitle: String? {
    var parts: [String] = []
    if let artist = song.artist, !artist.isEmpty { parts.append(artist) }
    if let key = model.displayKey { parts.append("\(L10n.Songs.key) \(key)") }
    if let shape = model.capoShapeKey {
      parts.append("\(L10n.Songs.playIn): \(shape) (\(L10n.Songs.capo) \(model.settings.capo))")
    }
    if let bpm = song.bpm, bpm > 0 { parts.append("\(bpm) \(L10n.Songs.bpm)") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  private var transposeLabel: String {
    model.settings.transpose > 0 ? "+\(model.settings.transpose)" : "\(model.settings.transpose)"
  }

  private var capoLabel: String {
    model.settings.capo == 0 ? L10n.Songs.noCapo : "\(L10n.Songs.fret) \(model.settings.capo)"
  }

  private var columnsBinding: Binding<Int> {
    Binding(get: { model.columns }, set: { value in Task { await model.setColumns(value) } })
  }

  private var autoScrollControls: some View {
    HStack(spacing: 8) {
      Button {
        model.isAutoScrolling.toggle()
      } label: {
        Label(
          model.isAutoScrolling ? L10n.Songs.Lyrics.AutoScroll.stop : L10n.Songs.Lyrics.AutoScroll.start,
          systemImage: model.isAutoScrolling ? "pause.fill" : "play.fill")
      }
      Button(L10n.Songs.Lyrics.AutoScroll.decreaseSpeed, systemImage: "tortoise") { model.scrollSlower() }
        .labelStyle(.iconOnly)
        .disabled(model.scrollSpeed <= AutoScrollSpeed.minimum)
      Text("\(model.scrollSpeed)")
        .font(.subheadline.monospacedDigit())
        .frame(minWidth: 32)
        .accessibilityLabel("\(L10n.Songs.Lyrics.AutoScroll.speed) \(model.scrollSpeed)")
      Button(L10n.Songs.Lyrics.AutoScroll.increaseSpeed, systemImage: "hare") { model.scrollFaster() }
        .labelStyle(.iconOnly)
        .disabled(model.scrollSpeed >= AutoScrollSpeed.maximum)
    }
  }

  private var songNavigation: some View {
    HStack(spacing: 8) {
      Button(L10n.Ios.Performance.previousSong, systemImage: "chevron.left") { navigation.onPrevious?() }
        .labelStyle(.iconOnly)
        .disabled(navigation.onPrevious == nil)
      Button(L10n.Ios.Performance.nextSong, systemImage: "chevron.right") { navigation.onNext?() }
        .labelStyle(.iconOnly)
        .disabled(navigation.onNext == nil)
    }
  }
}

/// Compact "− value +" control.
private struct Stepper: View {
  let label: String
  let value: String
  let canDecrement: Bool
  let canIncrement: Bool
  let decrement: () -> Void
  let increment: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Text(label).font(.caption).foregroundStyle(.secondary)
      Button(action: decrement) { Image(systemName: "minus") }
        .disabled(!canDecrement)
        .accessibilityLabel("\(label) −")
      Text(value).font(.subheadline.monospacedDigit()).frame(minWidth: 44)
      Button(action: increment) { Image(systemName: "plus") }
        .disabled(!canIncrement)
        .accessibilityLabel("\(label) +")
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
  }
}
