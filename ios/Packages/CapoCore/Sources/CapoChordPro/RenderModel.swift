// Public render model (frozen shape, PLAN §5.5). WP1 owns the file; internal helpers may be added.

public enum SectionFlag: String, CaseIterable, Sendable, Codable {
  case attention, skip, forte, piano, vamp, tag, `break`, inline, label
}

public struct ChordProRenderOptions: Hashable, Sendable {
  public var transpose: Int
  public var capo: Int
  public var sectionLabels: [String: String]  // chorus, verse, bridge, tab, grid, intro, outro, pre_chorus
  public var commentLabel: String

  public init(transpose: Int, capo: Int, sectionLabels: [String: String], commentLabel: String) {
    self.transpose = transpose
    self.capo = capo
    self.sectionLabels = sectionLabels
    self.commentLabel = commentLabel
  }
}

public struct ChordLyricPair: Hashable, Sendable {
  public var chord: String  // "" = none
  public var lyrics: String

  public init(chord: String, lyrics: String) {
    self.chord = chord
    self.lyrics = lyrics
  }
}

public enum InlinePart: Hashable, Sendable {
  case text(String), chord(String)
}

public indirect enum BodyLine: Hashable, Sendable {
  case chordLyrics([ChordLyricPair])  // web: clp-pair (min-width = max(chord.count, lyrics.count) ch)
  case inline([InlinePart])  // already whitespace-collapsed & trimmed
  case text(String)  // plain line, may be "" (directive lines, blanks)
  case comment(String), label(String), performanceNote(String)
  case sectionLabel(type: String, label: String)
  case volta(label: String, body: SongBody)  // label "" = none
  case box(label: String, body: SongBody)
}

/// Legacy HTML = lines joined by "\n".
public struct SongBody: Hashable, Sendable {
  public var lines: [BodyLine]

  public init(lines: [BodyLine]) {
    self.lines = lines
  }
}

public enum LyricsSegment: Hashable, Sendable {
  case normal(SongBody)
  case section(
    name: String, sectionType: String, body: SongBody, count: Int, flags: [SectionFlag],
    inline: Bool)
  case repeatRef(
    name: String, displayLabel: String?, count: Int, body: SongBody, found: Bool,
    sectionType: String, flags: [SectionFlag])
  case extend(
    name: String, displayLabel: String?, count: Int, body: SongBody, found: Bool,
    sectionType: String, flags: [SectionFlag])
}

public struct RenderedSong: Hashable, Sendable {
  public var segments: [LyricsSegment]

  public init(segments: [LyricsSegment]) {
    self.segments = segments
  }

  /// Mirrors rendered-song.tsx: any repeat, section or extend segment.
  public var hasComplexSegments: Bool {
    segments.contains { segment in
      if case .normal = segment { return false }
      return true
    }
  }
}
