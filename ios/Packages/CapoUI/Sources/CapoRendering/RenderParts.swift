import CapoDesign
import SwiftUI

/// Value threaded down the view tree (explicit, to avoid environment-key isolation issues).
struct RenderContext {
  var style: SongRenderStyle
  /// Accent of the enclosing section; nil outside sections.
  var accent: Color?
  var onChordTap: ((String) -> Void)?

  var pointSize: CGFloat { CapoFont.baseLyricsPointSize * style.fontScale }
  var chordColor: Color { accent ?? RenderPalette.chord }
  func inSection(_ accent: Color) -> RenderContext {
    var copy = self
    copy.accent = accent
    return copy
  }
}

enum RenderPalette {
  static let chord = OKLCH.dynamic(light: OKLCH(0.495, 0.265, 295), dark: OKLCH(0.749, 0.16, 298))
  static let comment = OKLCH.dynamic(light: OKLCH(0.55, 0.12, 195), dark: OKLCH(0.68, 0.12, 195))
  static let note = OKLCH.dynamic(light: OKLCH(0.58, 0.13, 65), dark: OKLCH(0.78, 0.12, 65))
}

// MARK: - Lines

struct LinesView: View {
  let lines: [BodyLine]
  let context: RenderContext

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
        LineView(line: line, context: context)
      }
    }
  }
}

struct LineView: View {
  let line: BodyLine
  let context: RenderContext

  var body: some View {
    switch line {
    case .chordLyrics(let pairs):
      if context.style.showChords || context.style.showLyrics {
        ChordLyricsLineView(pairs: pairs, context: context)
          .padding(.vertical, 1)
      }
    case .inline(let parts):
      InlineLineView(parts: parts, context: context)
        .padding(.vertical, 1)
    case .text(let text):
      Text(text.isEmpty ? "\u{200B}" : text)
        .font(CapoFont.lyrics(scale: context.style.fontScale))
        .fixedSize(horizontal: false, vertical: true)
    case .comment(let text):
      CardView(
        label: context.style.commentLabel, color: RenderPalette.comment, context: context,
        bodyText: text, content: nil)
    case .label(let text):
      Text(text.uppercased())
        .font(.system(size: context.pointSize * 0.68, weight: .bold))
        .tracking(context.pointSize * 0.68 * 0.12)
        .foregroundStyle(context.accent ?? RenderPalette.comment)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(
          (context.accent ?? RenderPalette.comment).opacity(0.12),
          in: RoundedRectangle(cornerRadius: 6)
        )
        .padding(.vertical, 6)
    case .performanceNote(let text):
      Text("(\u{00A0}\(text)\u{00A0})")
        .font(.system(size: context.pointSize * 0.82).italic())
        .foregroundStyle(RenderPalette.note)
        .opacity(0.88)
    case .sectionLabel(_, let label):
      Text(label.uppercased())
        .font(.system(size: context.pointSize, weight: .bold))
        .tracking(context.pointSize * 0.08)
        .foregroundStyle(.secondary)
    case .volta(let label, let body):
      CardView(
        label: label, color: context.accent ?? .secondary, context: context, bodyText: nil,
        content: AnyView(LinesView(lines: body.lines, context: context)))
    case .box(let label, let body):
      CardView(
        label: label, color: context.accent ?? RenderPalette.comment, context: context,
        bodyText: nil, content: AnyView(LinesView(lines: body.lines, context: context)))
    }
  }
}

/// Mirrors `.lyrics-comment`, `.volta-block` and `.lyrics-box`: bordered tinted card with an
/// optional uppercase header and either a text body or nested lines.
struct CardView: View {
  let label: String
  let color: Color
  let context: RenderContext
  let bodyText: String?
  let content: AnyView?

  var body: some View {
    let size = context.pointSize
    VStack(alignment: .leading, spacing: 0) {
      if !label.isEmpty {
        Text(label.uppercased())
          .font(.system(size: size * 0.68, weight: .bold))
          .tracking(size * 0.68 * 0.12)
          .foregroundStyle(color)
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(color.opacity(0.12))
          .overlay(alignment: .bottom) { Rectangle().fill(color.opacity(0.22)).frame(height: 1) }
      }
      if let bodyText {
        Text(bodyText)
          .font(.system(size: size * 0.85))
          .foregroundStyle(color)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 10)
          .padding(.top, 5)
          .padding(.bottom, 7)
      }
      if let content {
        content
          .padding(.horizontal, 10)
          .padding(.top, 5)
          .padding(.bottom, 7)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(color.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(color.opacity(0.28), lineWidth: 1))
    .padding(.vertical, 6)
  }
}

// MARK: - Chord / lyric lines

struct ChordLyricsLineView: View {
  let pairs: [ChordLyricPair]
  let context: RenderContext

  var body: some View {
    let lineHasChords = context.style.showChords && pairs.contains { !$0.chord.isEmpty }
    ChordLyricsLineLayout(rowSpacing: 2) {
      ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
        PairColumn(pair: pair, context: context, reserveChordRow: lineHasChords)
      }
    }
  }
}

struct PairColumn: View {
  let pair: ChordLyricPair
  let context: RenderContext
  let reserveChordRow: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if reserveChordRow {
        if pair.chord.isEmpty {
          Text("\u{200B}").font(CapoFont.chord(scale: context.style.fontScale))
        } else {
          chordBadge
            // 0.5em gap after the chord so neighbouring badges never touch.
            .padding(.trailing, context.pointSize * 0.5)
        }
      }
      if context.style.showLyrics {
        Text(pair.lyrics.isEmpty ? "\u{200B}" : pair.lyrics)
          .font(CapoFont.lyrics(scale: context.style.fontScale))
          .fixedSize()
      }
    }
  }

  private var chordBadge: some View {
    Text(pair.chord)
      .font(CapoFont.chord(scale: context.style.fontScale))
      .foregroundStyle(context.chordColor)
      .fixedSize()
      .padding(.horizontal, 3)
      .background(context.chordColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
      .padding(.horizontal, 1)
      .contentShape(Rectangle())
      .onTapGesture { context.onChordTap?(pair.chord) }
      .accessibilityLabel(pair.chord)
  }
}

struct InlineLineView: View {
  let parts: [InlinePart]
  let context: RenderContext

  var body: some View {
    Text(attributed)
      .font(CapoFont.lyrics(scale: context.style.fontScale))
      .tint(context.chordColor)
      .fixedSize(horizontal: false, vertical: true)
      .environment(
        \.openURL,
        OpenURLAction { url in
          guard url.scheme == "capochord", let tap = context.onChordTap else { return .discarded }
          tap(url.host(percentEncoded: false) ?? "")
          return .handled
        })
  }

  private var attributed: AttributedString {
    var result = AttributedString()
    for part in parts {
      switch part {
      case .text(let text):
        if context.style.showLyrics { result += AttributedString(text) }
      case .chord(let chord):
        guard context.style.showChords else { continue }
        var run = AttributedString(chord)
        run.foregroundColor = context.chordColor
        run.font = CapoFont.chord(scale: context.style.fontScale)
        if context.onChordTap != nil {
          var components = URLComponents()
          components.scheme = "capochord"
          components.host = chord
          run.link = components.url
        }
        result += run
      }
    }
    return result
  }
}

// MARK: - Segments

struct SegmentView: View {
  let segment: LyricsSegment
  let context: RenderContext
  let isCollapsed: Bool
  let onToggle: (() -> Void)?

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    switch segment {
    case .normal(let body):
      LinesView(lines: body.lines, context: context)
    case .section(let name, let sectionType, let body, let count, let flags, _):
      if sectionType == "comment" {
        CardView(
          label: context.style.commentLabel, color: RenderPalette.comment, context: context,
          bodyText: name, content: nil)
      } else if sectionType == "comment-label" {
        LineView(line: .label(name), context: context)
      } else {
        block(
          title: Self.title(name, count), sectionType: sectionType, icon: nil, flags: flags,
          body: body)
      }
    case .repeatRef(let name, let displayLabel, let count, let body, let found, let type, let flags):
      referenceBlock(
        title: Self.title(displayLabel ?? name, count), found: found, sectionType: type,
        symbol: "repeat", flags: flags, body: body, accentType: found ? type : "repeat")
    case .extend(let name, let displayLabel, let count, let body, let found, let type, let flags):
      referenceBlock(
        title: Self.title(displayLabel ?? name, count), found: found, sectionType: type,
        symbol: "square.3.layers.3d", flags: flags, body: body, accentType: found ? type : "repeat")
    }
  }

  static func title(_ name: String, _ count: Int) -> String {
    count > 1 ? "\(name) × \(count)" : name
  }

  @ViewBuilder
  private func referenceBlock(
    title: String, found: Bool, sectionType: String, symbol: String, flags: [SectionFlag],
    body: SongBody, accentType: String
  ) -> some View {
    if found {
      block(title: title, sectionType: sectionType, icon: symbol, flags: flags, body: body)
    } else {
      let notFound = String(
        localized: "chords.notFound", defaultValue: "not found", bundle: .capoDesign)  // TODO(i18n)
      SectionHeaderView(
        title: "\(title) (\(notFound))", accent: SectionAccent.color(for: accentType),
        icon: nil, flags: [], pointSize: context.pointSize, isCollapsed: false, onToggle: nil
      )
      .opacity(0.5)
    }
  }

  private func block(
    title: String, sectionType: String, icon: String?, flags: [SectionFlag], body: SongBody
  ) -> some View {
    let accent = SectionAccent.color(for: sectionType)
    return VStack(alignment: .leading, spacing: 0) {
      SectionHeaderView(
        title: title, accent: accent, icon: icon, flags: flags, pointSize: context.pointSize,
        isCollapsed: isCollapsed, onToggle: onToggle)
      if !isCollapsed {
        LinesView(lines: body.lines, context: context.inSection(accent))
          .padding(.leading, 16)
          .padding(.trailing, 16)
          .padding(.top, 8)
          .padding(.bottom, 10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(accent.opacity(colorScheme == .dark ? 0.12 : 0.06))
          .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 10, topTrailingRadius: 10))
          .overlay(alignment: .leading) { Rectangle().fill(accent).frame(width: 2) }
      }
    }
  }
}

struct SectionHeaderView: View {
  let title: String
  let accent: Color
  let icon: String?
  let flags: [SectionFlag]
  let pointSize: CGFloat
  let isCollapsed: Bool
  let onToggle: (() -> Void)?

  var body: some View {
    if let onToggle {
      Button(action: onToggle) { row }
        .buttonStyle(.plain)
        .accessibilityValue(isCollapsed ? "collapsed" : "expanded")
    } else {
      row
    }
  }

  private var row: some View {
    HStack(spacing: 10) {
      if let icon {
        Image(systemName: icon).font(.system(size: 11)).foregroundStyle(accent)
      } else {
        Circle().fill(accent).frame(width: 6, height: 6)
          .padding(2)
          .background(accent.opacity(0.25), in: Circle())
      }
      Text(title.uppercased())
        .font(.system(size: max(12, pointSize * 0.75), weight: .bold))
        .tracking(max(12, pointSize * 0.75) * 0.18)
        .foregroundStyle(accent)
        .fixedSize(horizontal: false, vertical: true)
      ForEach(flags.filter { $0 != .inline && $0 != .label }, id: \.self) { FlagBadge($0) }
      Spacer(minLength: 0)
      if onToggle != nil {
        Image(systemName: "chevron.down")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .rotationEffect(.degrees(isCollapsed ? -90 : 0))
          .animation(.easeInOut(duration: 0.15), value: isCollapsed)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
    .contentShape(Rectangle())
  }
}
