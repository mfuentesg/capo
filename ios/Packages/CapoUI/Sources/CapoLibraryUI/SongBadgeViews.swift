import CapoDesign
import CapoIcons
import SwiftUI

/// Key badge: Geist Mono on the songs tint.
struct KeyBadge: View {
  let key: String

  var body: some View {
    MetaBadge(
      icon: .music2, text: key, foreground: CapoTheme.accentSongs,
      background: CapoTheme.accentSongs.opacity(0.10),
      border: CapoTheme.accentSongs.opacity(0.30), mono: true)
  }
}

/// Tempo badge: tier icon plus "96 BPM", coloured by tier (muted / green / rose).
struct BPMBadge: View {
  let bpm: Int

  static func icon(_ bpm: Int) -> CapoIconName {
    switch SongBadgeLogic.iconTier(bpm: bpm) {
    case .turtle: .turtle
    case .rabbit: .rabbit
    case .zap: .zap
    }
  }

  /// Foreground, fill and border of the tier.
  static func tone(_ bpm: Int) -> (Color, Color, Color) {
    switch SongBadgeLogic.colorTier(bpm: bpm) {
    case .slow: (CapoTheme.mutedForeground, CapoTheme.muted, CapoTheme.border)
    case .steady: (CapoTheme.accentActivity, CapoTheme.accentActivity.opacity(0.10), CapoTheme.accentActivity.opacity(0.30))
    case .fast: (SongTone.rose(), SongTone.rose().opacity(0.10), SongTone.rose().opacity(0.30))
    }
  }

  var body: some View {
    let tone = Self.tone(bpm)
    MetaBadge(
      icon: Self.icon(bpm), text: LibraryStrings.bpm(bpm), foreground: tone.0, background: tone.1,
      border: tone.2)
  }
}

/// "3× · 5d" once the song has appeared in a playlist; amber when played within the repetition window.
struct PlayedBadge: View {
  let item: SongListItem

  /// Text and recency of the played value; nil when the song was never played.
  static func value(_ item: SongListItem) -> (text: String, recent: Bool)? {
    guard item.playCount > 0, let date = SongBadgeLogic.parseDate(item.lastPlayed) else { return nil }
    return (
      "\(item.playCount)× · \(SongBadgeLogic.compactRelative(date))",
      SongBadgeLogic.isRecentlyPlayed(lastPlayed: date)
    )
  }

  var body: some View {
    if let value = Self.value(item) {
      let amber = SongTone.amber()
      MetaBadge(
        icon: .repeat, text: value.text,
        foreground: value.recent ? amber : CapoTheme.mutedForeground,
        background: value.recent ? amber.opacity(0.10) : CapoTheme.muted,
        border: value.recent ? amber.opacity(0.30) : CapoTheme.border)
    }
  }
}

/// Ownership chip of the "All" view: coloured pill with the team icon (or a dot) and its name.
struct OwnerChipView: View {
  let chip: OwnershipChip

  var body: some View {
    HStack(spacing: 4) {
      if let icon = chip.icon {
        CapoIcon.named(icon, size: 12)
      } else {
        Circle().frame(width: 6, height: 6)
      }
      Text(chip.label).lineLimit(1)
    }
    .capoText(.px10, weight: .medium)
    .foregroundStyle(chip.color)
    .padding(.horizontal, 8).padding(.vertical, 2)
    .background(chip.color.opacity(0.15), in: Capsule())
    .frame(maxWidth: 140, alignment: .leading)
  }
}
