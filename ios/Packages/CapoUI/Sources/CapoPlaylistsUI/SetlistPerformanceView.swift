import CapoDesign
import CapoPerformanceUI
import SwiftUI
import UIKit

/// Horizontal paging through a setlist of `SongPerformanceView`s. Only the current page and its
/// neighbours are live so long sets stay light; next/previous also come from pedals via
/// `PerformanceNavigation`.
public struct SetlistPerformanceView: View {
  let playlistID: PlaylistID
  let startIndex: Int
  let onClose: () -> Void

  @Environment(\.userServices) private var services
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var songs: [SongListItem] = []
  @State private var loaded = false
  @State private var index = 0
  @State private var didSeedIndex = false
  @State private var name = ""
  @State private var chrome = StageChrome()

  public init(playlistID: PlaylistID, startIndex: Int = 0, onClose: @escaping () -> Void) {
    self.playlistID = playlistID
    self.startIndex = startIndex
    self.onClose = onClose
  }

  private var compact: Bool { sizeClass == .compact }
  private var isFullscreen: Bool { chrome.isFullscreen }
  /// Phones get the big prev / next bar; iPad has them in the song dock.
  private var showsBottomBar: Bool { compact && !isFullscreen && !songs.isEmpty }

  public var body: some View {
    ZStack {
      CapoTheme.background.ignoresSafeArea()
      VStack(spacing: 0) {
        if !isFullscreen { header }
        ZStack {
          if songs.isEmpty {
            if loaded {
              EmptyStateView(
                title: PlaylistStrings.emptySongsTitle, message: nil, systemImage: "music.note.list")
            } else {
              ProgressView()
            }
          } else {
            pager
          }
        }
        .overlay(alignment: .trailing) { if compact && !isFullscreen { peekingCard } }
      }
      if showsBottomBar { bottomBar.frame(maxHeight: .infinity, alignment: .bottom) }
    }
    .task(id: playlistID) {
      for await detail in services.playlists.playlist(id: playlistID) {
        songs = detail?.songs ?? []
        name = detail?.playlist.name ?? name
        loaded = true
        if !didSeedIndex {
          index = SetlistMath.clamp(startIndex, count: songs.count)
          didSeedIndex = true
        } else {
          index = SetlistMath.clamp(index, count: songs.count)
        }
      }
    }
  }

  // MARK: Header

  private var header: some View {
    VStack(spacing: 12) {
      HStack(spacing: 8) {
        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(CapoFont.ui(20, weight: .bold))
            .foregroundStyle(CapoTheme.text)
            .frame(width: 48, height: 48)
            .background(CapoTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PlaylistStrings.close)
        VStack(alignment: .leading, spacing: 1) {
          Text(name).font(CapoFont.ui(18, weight: .bold)).lineLimit(1)
          Label(SetlistStrings.savedOnDevice(device), systemImage: "arrow.down.to.line")
            .font(CapoFont.ui(13, weight: .semibold))
            .foregroundStyle(CapoTheme.success)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        if !songs.isEmpty { positionPill }
        if !compact {
          Button {
            withAnimation(.easeInOut(duration: 0.22)) { chrome.isFullscreen = true }
          } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
              .font(CapoFont.ui(20, weight: .bold))
              .foregroundStyle(CapoTheme.onPrimary)
              .frame(width: 48, height: 48)
              .background(CapoTheme.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(SetlistStrings.enterFullscreen)
        }
      }
      if !songs.isEmpty { progressSegments }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(CapoTheme.sidebar.ignoresSafeArea(edges: .top))
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.surface).frame(height: 1) }
  }

  private var device: String {
    UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
  }

  private var positionPill: some View {
    HStack(spacing: 3) {
      Text("\(index + 1)").foregroundStyle(CapoTheme.text)
      Text("/").font(CapoFont.ui(17, weight: .medium)).foregroundStyle(CapoTheme.subtext)
      Text("\(songs.count)").foregroundStyle(CapoTheme.text)
    }
    .font(CapoFont.ui(17, weight: .bold).monospacedDigit())
    .padding(.horizontal, 14)
    .frame(height: 40)
    .background(CapoTheme.surface, in: Capsule())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(SetlistMath.positionLabel(index: index, count: songs.count))
  }

  private var progressSegments: some View {
    HStack(spacing: 4) {
      ForEach(Array(SetlistProgress.segments(index: index, count: songs.count).enumerated()), id: \.offset) {
        _, segment in
        Capsule()
          .fill(color(for: segment))
          .frame(height: 5)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(SetlistMath.positionLabel(index: index, count: songs.count))
  }

  private func color(for segment: SetlistProgress.Segment) -> Color {
    switch segment {
    case .done: CapoTheme.primary
    case .current: CapoTheme.text
    case .upcoming: CapoTheme.surfaceStrong
    }
  }

  // MARK: Pager

  private var pager: some View {
    let window = SetlistMath.liveWindow(current: index, count: songs.count)
    return TabView(selection: $index) {
      ForEach(Array(songs.enumerated()), id: \.element.id) { i, song in
        Group {
          if window.contains(i) {
            SongPerformanceView(songID: song.id, navigation: navigation(for: i))
          } else {
            Color.clear
          }
        }
        .tag(i)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .ignoresSafeArea(.container, edges: .bottom)
  }

  private func navigation(for i: Int) -> PerformanceNavigation {
    var nav = PerformanceNavigation(
      positionLabel: SetlistMath.positionLabel(index: i, count: songs.count),
      isEmbedded: true, dockBottomInset: compact ? Self.bottomBarHeight : 0, chrome: chrome)
    if let target = SetlistMath.next(i, count: songs.count) {
      nav.onNext = { go(to: target) }
      nav.nextTitle = songs[target].title
    }
    if let target = SetlistMath.previous(i) {
      nav.onPrevious = { go(to: target) }
    }
    return nav
  }

  private func go(to target: Int) {
    withAnimation { index = SetlistMath.clamp(target, count: songs.count) }
  }

  // MARK: Next song

  /// Approximate height of `bottomBar`, so the song's dock sits above it.
  private static let bottomBarHeight: Double = 118

  /// The next song's edge, sticking out at the trailing side while paging.
  @ViewBuilder private var peekingCard: some View {
    if let next = SetlistMath.next(index, count: songs.count), songs.indices.contains(next) {
      let song = songs[next]
      Button { go(to: next) } label: {
        VStack(alignment: .leading, spacing: 6) {
          Text(SetlistStrings.next.uppercased())
            .font(CapoFont.ui(11, weight: .bold)).tracking(0.9)
            .foregroundStyle(CapoTheme.subtext)
          Text(song.title).font(CapoFont.ui(17, weight: .bold)).lineLimit(3)
            .multilineTextAlignment(.leading)
          if let detail = SetlistProgress.peekDetail(
            key: song.key, bpm: song.bpm, bpmLabel: SetlistStrings.bpm)
          {
            Text(detail).font(CapoFont.ui(13)).foregroundStyle(CapoTheme.subtext)
          }
        }
        .foregroundStyle(CapoTheme.text)
        .frame(width: 120, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(width: 150, height: 300, alignment: .topLeading)
        .background(CapoTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(CapoTheme.border, lineWidth: 1))
      }
      .buttonStyle(.plain)
      .offset(x: 128)
      .accessibilityHidden(true)
      .allowsHitTesting(false)
    }
  }

  /// Phone: previous / next as big thumb targets under the song.
  private var bottomBar: some View {
    VStack(spacing: 10) {
      Label(SetlistStrings.changeHint, systemImage: "dot.radiowaves.left.and.right")
        .font(CapoFont.ui(13))
        .foregroundStyle(CapoTheme.subtext)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      HStack(spacing: 8) {
        Button {
          if let target = SetlistMath.previous(index) { go(to: target) }
        } label: {
          Image(systemName: "chevron.left")
            .font(CapoFont.ui(24, weight: .bold))
            .foregroundStyle(CapoTheme.text)
            .frame(width: 84, height: 64)
            .background(CapoTheme.surfaceStrong, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(SetlistMath.previous(index) == nil)
        .opacity(SetlistMath.previous(index) == nil ? 0.4 : 1)
        .sensoryFeedback(.impact(weight: .light), trigger: index)
        .accessibilityLabel(previousLabel)
        nextButton
      }
    }
    .padding(12)
    .background(CapoTheme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(CapoTheme.border, lineWidth: 1))
    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    .padding(.horizontal, 10)
    .padding(.bottom, 12)
  }

  private var previousLabel: String {
    SetlistMath.previous(index).map { SetlistStrings.previousSong(songs[$0].title) }
      ?? SetlistStrings.previous
  }

  private var nextButton: some View {
    let next = SetlistMath.next(index, count: songs.count)
    return Button {
      if let next { go(to: next) } else { onClose() }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text((next == nil ? SetlistStrings.end : SetlistStrings.next).uppercased())
            .font(CapoFont.ui(11, weight: .bold)).tracking(0.9).opacity(0.75)
          Text(next.map { songs[$0].title } ?? SetlistStrings.finish)
            .font(CapoFont.ui(18, weight: .bold)).lineLimit(1)
        }
        Spacer(minLength: 8)
        Image(systemName: next == nil ? "checkmark" : "chevron.right")
          .font(CapoFont.ui(24, weight: .bold))
      }
      .foregroundStyle(CapoTheme.onPrimary)
      .padding(.horizontal, 20)
      .frame(maxWidth: .infinity)
      .frame(height: 64)
      .background(CapoTheme.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact(weight: .light), trigger: index)
    .accessibilityLabel(next.map { PlaylistStrings.nextSong(songs[$0].title) } ?? SetlistStrings.finish)
  }
}

/// Copy specific to the setlist run; wrappers over the generated `L10n.Ios.Setlist`.
enum SetlistStrings {
  static func savedOnDevice(_ device: String) -> String {
    L10n.Ios.Setlist.savedOnDevice(device: device)
  }
  static var next: String { L10n.Ios.Setlist.nextLabel }
  static var end: String { L10n.Ios.Setlist.end }
  static var finish: String { L10n.Ios.Setlist.finish }
  static var previous: String { L10n.Ios.Setlist.previous }
  static func previousSong(_ title: String) -> String { L10n.Ios.Setlist.previousSong(title: title) }
  static var bpm: String { L10n.Ios.Setlist.bpm }
  static var changeHint: String { L10n.Ios.Setlist.changeHint }
  static var enterFullscreen: String { L10n.Ios.Setlist.enterFullscreen }
}
