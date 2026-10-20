import CapoDesign
import CapoPerformanceUI
import SwiftUI

/// Horizontal paging through a setlist of `SongPerformanceView`s. Only the current page and its
/// neighbours are live so long sets stay light; next/previous also come from pedals via
/// `PerformanceNavigation`.
public struct SetlistPerformanceView: View {
  let playlistID: PlaylistID
  let startIndex: Int
  let onClose: () -> Void

  @Environment(\.userServices) private var services
  @State private var songs: [SongListItem] = []
  @State private var loaded = false
  @State private var index = 0
  @State private var didSeedIndex = false

  public init(playlistID: PlaylistID, startIndex: Int = 0, onClose: @escaping () -> Void) {
    self.playlistID = playlistID
    self.startIndex = startIndex
    self.onClose = onClose
  }

  public var body: some View {
    ZStack(alignment: .top) {
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
      HStack {
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill").font(.title2)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel(PlaylistStrings.close)
        Spacer()
      }
      .padding(.horizontal, 8)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { nextPeek }
    .task(id: playlistID) {
      for await detail in services.playlists.playlist(id: playlistID) {
        songs = detail?.songs ?? []
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
      positionLabel: SetlistMath.positionLabel(index: i, count: songs.count))
    if let target = SetlistMath.next(i, count: songs.count) {
      nav.onNext = { go(to: target) }
    }
    if let target = SetlistMath.previous(i) {
      nav.onPrevious = { go(to: target) }
    }
    return nav
  }

  private func go(to target: Int) {
    withAnimation { index = SetlistMath.clamp(target, count: songs.count) }
  }

  @ViewBuilder private var nextPeek: some View {
    if let next = SetlistMath.next(index, count: songs.count), songs.indices.contains(next) {
      Button { go(to: next) } label: {
        HStack {
          Text(PlaylistStrings.nextSong(songs[next].title)).lineLimit(1)
          Spacer()
          Image(systemName: "chevron.right")
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(.bar)
      }
      .buttonStyle(.plain)
    }
  }
}
