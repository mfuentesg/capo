// WP0 stub so consumers compile before the real engine lands. WP1 replaces this file.

public enum ChordProEngine {
  /// Naive: every line becomes `.text`.
  public static func render(_ lyrics: String, options: ChordProRenderOptions) -> RenderedSong {
    let lines = lyrics.split(separator: "\n", omittingEmptySubsequences: false)
      .map { BodyLine.text(String($0)) }
    return RenderedSong(segments: [.normal(SongBody(lines: lines))])
  }
}

public enum LegacyHTMLSerializer {
  public static func html(_ body: SongBody, commentLabel: String) -> String {
    body.lines.map { line in
      if case .text(let text) = line { return text }
      return ""
    }.joined(separator: "\n")
  }
}

public enum ChordTransposer {
  public static func transpose(_ chord: String, by delta: Int) -> String { chord }
  public static func normalize(_ chord: String, toKey key: String) -> String { chord }
}

public enum MusicTheory {
  public static func transposeKey(_ key: String, semitones: Int) -> String { key }
  public static func capoKey(_ key: String, capo: Int) -> String { key }
  public static func effectiveKey(_ key: String, transpose: Int, capo: Int) -> String { key }
}
