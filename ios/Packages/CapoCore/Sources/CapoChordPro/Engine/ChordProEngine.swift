// Swift port of features/lyrics-editor/utils/song-pipeline.ts (buildSectionMap + buildSegments).

public enum ChordProEngine {
  /// Renders ChordPro lyrics into segments, byte-compatible with the web pipeline.
  ///
  /// When the web pipeline throws (unparseable ChordPro, invalid `{key}`, ...), rendered-song.tsx
  /// shows the raw lyrics instead; this returns a single normal segment of raw text lines.
  public static func render(_ lyrics: String, options: ChordProRenderOptions) -> RenderedSong {
    let units = lyrics.units
    let processor = ContentProcessor(
      transpose: options.transpose, capo: options.capo, sectionLabels: options.sectionLabels)
    do {
      let sectionMap = SegmentBuilder.buildSectionMap(units)
      let segments = try SegmentBuilder.buildSegments(
        units, sectionMap: sectionMap, processor: processor)
      return RenderedSong(segments: segments)
    } catch {
      let lines = lyrics.split(separator: "\n", omittingEmptySubsequences: false)
        .map { BodyLine.text(String($0)) }
      return RenderedSong(segments: [.normal(SongBody(lines: lines))])
    }
  }
}
