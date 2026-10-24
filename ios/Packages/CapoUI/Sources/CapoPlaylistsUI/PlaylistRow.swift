import CapoDesign
import CapoIcons
import SwiftUI

/// Web `PlaylistItem`: 40 px tile with `Music3`, bold name with lock / globe icons and an
/// "Archived" chip, meta line (date, song count) and a 36 px archive button.
struct PlaylistRow: View {
  let summary: PlaylistSummary
  var isSelected = false
  /// Shows the trailing archive / unarchive button.
  var onToggleArchive: (() -> Void)?
  @Environment(\.capoUIScale) private var scale

  private var playlist: Playlist { summary.playlist }
  private var isArchived: Bool { playlist.archivedAt != nil }

  var body: some View {
    HStack(spacing: 12) {
      tile
      VStack(alignment: .leading, spacing: 4) {
        titleLine
        metaLine
      }
      Spacer(minLength: 8)
      if summary.isPinned { pinBadge }
      if let onToggleArchive { archiveButton(onToggleArchive) }
    }
    .padding(12)
    .frame(minHeight: 64)
    .background(background)
    .overlay(ring)
    .shadow(color: .black.opacity(isSelected ? 0.10 : 0.05), radius: isSelected ? 4 : 1.5, y: 1)
    .opacity(isArchived ? 0.5 : 1)
    .contentShape(Rectangle())
    .accessibilityElement(children: .contain)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: CapoRadius.xl * scale, style: .continuous)
  }

  private var background: some View {
    ZStack {
      shape.fill(CapoTheme.card)
      if isSelected { shape.fill(CapoTheme.accentPlaylists.opacity(0.10)) }
    }
  }

  private var ring: some View {
    shape.strokeBorder(
      isSelected ? CapoTheme.accentPlaylists.opacity(0.40) : CapoTheme.border,
      lineWidth: isSelected ? 2 : 1)
  }

  private var tile: some View {
    CapoIcon(.music3, size: 20)
      .foregroundStyle(CapoTheme.accentPlaylists)
      .frame(width: 40, height: 40)
      .background(
        CapoTheme.accentPlaylists.opacity(0.12),
        in: RoundedRectangle(cornerRadius: CapoRadius.xl * scale, style: .continuous))
  }

  private var titleLine: some View {
    HStack(spacing: 6) {
      Text(playlist.name)
        .capoText(.sm, weight: .bold)
        .foregroundStyle(CapoTheme.foreground)
        .lineLimit(1)
      if playlist.isPublic {
        CapoIcon(.globe, size: 12).foregroundStyle(CapoTheme.mutedForeground)
          .accessibilityLabel(
            playlist.allowGuestEditing
              ? L10n.PlaylistItem.publicGuestEditing : L10n.PlaylistItem.publicViewOnly)
        if playlist.allowGuestEditing {
          CapoIcon(.users, size: 12).foregroundStyle(CapoTheme.mutedForeground)
            .accessibilityHidden(true)
        }
      } else {
        CapoIcon(.lock, size: 12).foregroundStyle(CapoTheme.mutedForeground)
          .accessibilityLabel(L10n.PlaylistItem.privatePlaylist)
      }
      if isArchived { PlaylistChip(text: L10n.Playlists.archivedBadge, icon: .archive) }
    }
  }

  private var metaLine: some View {
    HStack(spacing: 10) {
      if let date = PlaylistDate.display(playlist.date) {
        HStack(spacing: 4) {
          CapoIcon(.calendar, size: 12)
          Text(date)
        }
      }
      HStack(spacing: 4) {
        CapoIcon(.music3, size: 12)
        Text("\(summary.songCount)").monospacedDigit()
      }
      .accessibilityLabel(PlaylistStrings.songCount(summary.songCount))
    }
    .capoText(.xs)
    .foregroundStyle(CapoTheme.mutedForeground)
    .lineLimit(1)
  }

  /// iOS-only: the setlist is kept for offline use (no web counterpart, hence SF Symbols).
  @ViewBuilder private var pinBadge: some View {
    if summary.isFullyAvailableOffline {
      CapoIcon(.checkCircle2, size: 14).foregroundStyle(CapoTheme.success)
        .accessibilityLabel(PlaylistStrings.offlineReady)
    } else {
      Image(systemName: "pin.fill").font(.system(size: 11))
        .foregroundStyle(CapoTheme.mutedForeground)
        .accessibilityLabel(PlaylistStrings.pinned)
    }
  }

  private func archiveButton(_ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      CapoIcon(isArchived ? .archiveRestore : .archive, size: 16)
        .foregroundStyle(CapoTheme.mutedForeground)
        .frame(width: 36, height: 36)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(isArchived ? L10n.Playlists.unarchive : L10n.Playlists.archive)
  }
}
