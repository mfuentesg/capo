import CapoDesign
import SwiftUI

/// Chords destination until the glossary lands in a later wave.
struct ChordsPlaceholderView: View {
  var body: some View {
    EmptyStateView(
      title: L10n.Ios.Shell.chordsSoonTitle, message: L10n.Ios.Shell.chordsSoonMessage,
      systemImage: SidebarItem.chords.symbol
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CapoTheme.background)
    .navigationTitle(L10n.Nav.chords)
    .navigationBarTitleDisplayMode(.inline)
  }
}

/// Songs detail pane with nothing selected: faint music watermark, accent bar, title and hint
/// (web `songs-client.tsx` empty detail).
struct SongsDetailPlaceholder: View {
  /// Web `--accent-songs`; the tokens wave replaces this with the real section accent.
  static var accent: Color { CapoTheme.primary }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      GeometryReader { proxy in
        Image(systemName: SidebarItem.songs.symbol)
          .resizable().scaledToFit()
          .foregroundStyle(CapoTheme.text.opacity(0.04))
          .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 0.45)
          .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
      }
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 8) {
        Capsule().fill(Self.accent).frame(width: 32, height: 2).padding(.bottom, 8)
        Text(L10n.Songs.selectSong).font(CapoFont.style(.title3, weight: .bold))
          .foregroundStyle(CapoTheme.text)
        Text(L10n.Songs.selectSongDescription).font(CapoFont.style(.subheadline))
          .foregroundStyle(CapoTheme.subtext).frame(maxWidth: 320, alignment: .leading)
      }
      .padding(40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CapoTheme.card)
    .accessibilityElement(children: .combine)
  }
}
