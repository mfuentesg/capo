import CapoDesign
import CapoIcons
import SwiftUI

/// Chords destination until the glossary lands in a later wave.
struct ChordsPlaceholderView: View {
  var body: some View {
    ShellEmptyState(
      icon: SidebarItem.chords.icon, title: L10n.Ios.Shell.chordsSoonTitle,
      message: L10n.Ios.Shell.chordsSoonMessage)
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
  static var accent: Color { CapoTheme.accentSongs }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      GeometryReader { proxy in
        CapoIcon(SidebarItem.songs.icon, size: min(proxy.size.width, proxy.size.height) * 0.45, strokeWidth: 1.5)
          .foregroundStyle(CapoTheme.foreground.opacity(0.04))
          .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
      }
      .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 8) {
        Capsule().fill(Self.accent).frame(width: 32, height: 2).padding(.bottom, 8)
        Text(L10n.Songs.selectSong).capoText(.lg, weight: .bold)
          .foregroundStyle(CapoTheme.foreground)
        Text(L10n.Songs.selectSongDescription).capoText(.sm)
          .foregroundStyle(CapoTheme.subtext).frame(maxWidth: 320, alignment: .leading)
      }
      .padding(40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CapoTheme.card)
    .accessibilityElement(children: .combine)
  }
}

/// The web `Empty` block with a lucide icon in a 40 px tile.
struct ShellEmptyState: View {
  @Environment(\.capoUIScale) private var scale
  let icon: CapoIconName
  let title: String
  let message: String?

  var body: some View {
    let tile = RoundedRectangle(cornerRadius: CapoRadius.base * scale, style: .continuous)
    VStack(spacing: 16) {
      CapoIcon(icon, size: 24 * scale)
        .foregroundStyle(CapoTheme.foreground)
        .frame(width: 40 * scale, height: 40 * scale)
        .background(CapoTheme.muted, in: tile)
      VStack(spacing: 4) {
        Text(title).capoText(.lg, weight: .medium, tracking: -0.025)
        if let message { Text(message).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground) }
      }
      .multilineTextAlignment(.center)
    }
    .padding(24)
  }
}
