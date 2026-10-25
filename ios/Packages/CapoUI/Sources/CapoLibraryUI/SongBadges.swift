import CapoDesign
import CapoIcons
import SwiftUI

/// Pure decisions behind the song-row badges (web `song-item.tsx`, `lib/badge-colors.ts`,
/// `features/songs/utils/bucket-colors.ts`, `playlists/utils/song-frequency.ts`).
nonisolated enum SongBadgeLogic {
  /// Badge icon tier: turtle below 90, rabbit up to 120, zap above (`song-item.tsx`).
  enum IconTier: Equatable { case turtle, rabbit, zap }
  /// Badge colour tier: muted below 90, green up to 130, rose above (`getBpmColorClasses`).
  enum ColorTier: Equatable { case slow, steady, fast }

  static func iconTier(bpm: Int) -> IconTier {
    bpm < 90 ? .turtle : (bpm <= 120 ? .rabbit : .zap)
  }

  static func colorTier(bpm: Int) -> ColorTier {
    bpm < 90 ? .slow : (bpm <= 130 ? .steady : .fast)
  }

  /// Songs repeated within this many days are flagged amber (`SONG_REPETITION_WINDOW_DAYS`).
  static let repetitionWindowDays = 14

  static func isRecentlyPlayed(lastPlayed: Date?, now: Date = .now) -> Bool {
    guard let lastPlayed else { return false }
    let days = now.timeIntervalSince(lastPlayed) / 86_400
    return days >= 0 && days <= Double(repetitionWindowDays)
  }

  /// `formatCompactRelativeTime`: "now", "5m", "3h", "2d", "3w", "4mo", "2y".
  static func compactRelative(_ date: Date, now: Date = .now) -> String {
    let seconds = max(0, now.timeIntervalSince(date))
    let minutes = Int(seconds / 60)
    if minutes < 1 { return "now" }
    if minutes < 60 { return "\(minutes)m" }
    let hours = minutes / 60
    if hours < 24 { return "\(hours)h" }
    let days = hours / 24
    if days < 7 { return "\(days)d" }
    if days < 30 { return "\(days / 7)w" }
    if days < 365 { return "\(days / 30)mo" }
    return "\(days / 365)y"
  }

  /// Parses `yyyy-MM-dd` or a full timestamp.
  static func parseDate(_ raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    return ServerTimestamp(raw.count == 10 ? raw + "T00:00:00Z" : raw).date
  }

  /// Slot of a team in the web's bucket palette: accent-songs, accent-playlists, chart-1...5.
  static let bucketPaletteCount = 7

  static func bucketSlot(teamID: TeamID, teams: [TeamID]) -> Int {
    max(0, teams.firstIndex(of: teamID) ?? 0) % bucketPaletteCount
  }
}

/// Dynamic colours for badge tones the palette tokens do not carry.
enum SongTone {
  static func rose() -> Color { pair("#e11d48", "#fb7185") }
  static func amber() -> Color { pair("#d97706", "#fbbf24") }

  /// `--chart-1...5` of the default web palette, rendered values.
  static func chart(_ index: Int) -> Color {
    let light = ["#fe640b", "#8839ef", "#1e66f5", "#40a02b", "#d20f39"]
    let dark = ["#fab387", "#cba6f7", "#89b4fa", "#a6e3a1", "#f38ba8"]
    return pair(light[index % 5], dark[index % 5])
  }

  /// Ownership chip colour: personal = activity accent; teams cycle through the bucket palette.
  static func bucket(_ ownership: SongOwnership, teams: [TeamID]) -> Color {
    switch ownership {
    case .personal: return CapoTheme.accentActivity
    case .team(let id):
      switch SongBadgeLogic.bucketSlot(teamID: id, teams: teams) {
      case 0: return CapoTheme.accentSongs
      case 1: return CapoTheme.accentPlaylists
      case let slot: return chart(slot - 2)
      }
    }
  }

  private static func pair(_ light: String, _ dark: String) -> Color {
    let l = UIColor(Color(hex: light) ?? .gray)
    let d = UIColor(Color(hex: dark) ?? .gray)
    return Color(uiColor: UIColor { @Sendable t in t.userInterfaceStyle == .dark ? d : l })
  }
}

/// Who owns a song, for the "All" view chip.
nonisolated enum SongOwnership: Equatable {
  case personal
  case team(TeamID)
}

/// shadcn `Badge`: rounded-md, 1 px border, `px-2 py-0.5 text-xs font-medium`, icon 12.
struct MetaBadge: View {
  let icon: CapoIconName
  let text: String
  let foreground: Color
  let background: Color
  let border: Color
  var mono = false

  @Environment(\.capoUIScale) private var scale

  var body: some View {
    HStack(spacing: 6) {
      CapoIcon(icon, size: 12)
      Text(text).font(mono ? CapoFont.mono(12 * scale, weight: .medium) : CapoFont.web(.xs, weight: .medium, scale: scale))
    }
    .foregroundStyle(foreground)
    .padding(.horizontal, 8).padding(.vertical, 2)
    .background(background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(border, lineWidth: 1))
    .fixedSize()
  }
}
