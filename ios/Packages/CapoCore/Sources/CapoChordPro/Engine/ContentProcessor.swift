// processChordProContent, splitAndProcessVolta and splitAndProcessBox from song-pipeline.ts.
//
// The web joins HTML strings with "\n" and trims them; here the same operations run on
// `SongBody` lines so that `LegacyHTMLSerializer` reproduces the exact string.

struct ContentProcessor {
  let transpose: Int
  let capo: Int
  let sectionLabels: [String: String]

  private static let commentToken = "SECTIONLBL".units
  private static let noteToken = "PERFORMNOTE".units
  private static let sectionToken = "SECTSTART".units
  private static let keyTagName = "key".units

  // MARK: Box and volta splitting

  func box(_ text: Units, inline: Bool) throws -> SongBody {
    var parts: [SongBody] = []
    var lastIndex = 0
    while let open = Directives.boxOpen.firstMatch(text, from: lastIndex) {
      if open.start > lastIndex {
        parts.append(try volta(Array(text[lastIndex..<open.start]), inline: inline).trimmingEnd())
      }
      let label = open.capture.map { JS.trim(text, $0) } ?? []
      let content: Units
      if let close = Directives.boxClose.firstMatch(text, from: open.end) {
        content = Array(text[open.end..<close.start])
        lastIndex = close.end
      } else {
        content = Array(text[open.end...])
        lastIndex = text.count
      }
      let parsed = SectionValue(label.isEmpty ? "x".units : label)
      let boxLabel = label.isEmpty ? "" : String(units: parsed.name)
      if parsed.flags.contains(.label) {
        parts.append(SongBody(lines: [.label(boxLabel)]))
      } else {
        let inner = try volta(JS.trim(content), inline: inline)
        parts.append(SongBody(lines: [.box(label: boxLabel, body: inner)]))
      }
    }
    if lastIndex < text.count {
      let tail = Array(text[lastIndex...])
      let body = try volta(lastIndex > 0 ? JS.trimStart(tail) : tail, inline: inline)
      if !body.isEmptyHTML { parts.append(body) }
    }
    return SongBody(joining: parts)
  }

  func volta(_ text: Units, inline: Bool) throws -> SongBody {
    var parts: [SongBody] = []
    var lastIndex = 0
    var hasVolta = false
    var searchFrom = 0
    while let start = Directives.voltaStart.firstMatch(text, from: searchFrom) {
      guard let end = Directives.voltaEnd.firstMatch(text, from: start.end) else {
        searchFrom = start.start + 1  // no closing tag: the regex retries at the next position
        continue
      }
      hasVolta = true
      if start.start > lastIndex {
        parts.append(
          try process(Array(text[lastIndex..<start.start]), inline: inline).trimmingEnd())
      }
      let label = start.capture.map { String(units: JS.trim(text, $0)) } ?? ""
      let inner = try process(JS.trim(text, start.end..<end.start), inline: inline)
      parts.append(SongBody(lines: [.volta(label: label, body: inner)]))
      lastIndex = end.end
      searchFrom = end.end
    }
    if lastIndex < text.count {
      let tail = Array(text[lastIndex...])
      let body = try process(hasVolta ? JS.trimStart(tail) : tail, inline: inline)
      if !body.isEmptyHTML { parts.append(body) }
    }
    return SongBody(joining: parts)
  }

  // MARK: processChordProContent

  func process(_ text: Units, inline: Bool) throws -> SongBody {
    var commentLabels: [Units] = []
    var noteTexts: [Units] = []
    var sectionStarts: [(type: String, label: String)] = []

    var processed = Directives.commentToken.replaceAll(text) { m in
      commentLabels.append(JS.trim(text, m.capture!))
      return ContentProcessor.commentToken + String(commentLabels.count - 1).units
    }
    let afterComments = processed
    processed = Directives.noteToken.replaceAll(afterComments) { m in
      noteTexts.append(JS.trim(afterComments, m.capture!))
      return ContentProcessor.noteToken + String(noteTexts.count - 1).units
    }
    let afterNotes = processed
    processed = Directives.sectionStart.replaceAll(afterNotes) { m in
      let directive = String(units: Directives.sectionStart.literals[m.literal])
      let type = Directives.sectionTypes[directive] ?? "section"
      let label: String
      if let capture = m.capture {
        label = String(units: JS.trim(afterNotes, capture))
      } else {
        label = sectionLabels[type] ?? type
      }
      sectionStarts.append((type, label))
      return ContentProcessor.sectionToken + String(sectionStarts.count - 1).units
    }
    processed = Directives.sectionEnd.replaceAll(processed) { _ in [] }

    var lines = try ChordProParser.parse(processed)
    if transpose != 0 { try ContentProcessor.transposeSong(&lines, by: transpose) }
    if capo > 0 { try ContentProcessor.transposeSong(&lines, by: -capo) }

    var body: [BodyLine] = []
    body.reserveCapacity(lines.count)
    for line in lines {
      var lineLyrics = Units()
      for case .pair(_, let lyrics) in line { lineLyrics.append(contentsOf: lyrics) }

      if let index = ContentProcessor.token(ContentProcessor.commentToken, in: lineLyrics) {
        guard let index, index < commentLabels.count, !commentLabels[index].isEmpty else {
          body.append(.text(""))
          continue
        }
        let value = SectionValue(commentLabels[index])
        let text = String(units: value.name)
        body.append(value.flags.contains(.label) ? .label(text) : .comment(text))
        continue
      }
      if let index = ContentProcessor.token(ContentProcessor.noteToken, in: lineLyrics) {
        if let index, index < noteTexts.count, !noteTexts[index].isEmpty {
          body.append(.performanceNote(String(units: noteTexts[index])))
        } else {
          body.append(.text(""))
        }
        continue
      }
      if let index = ContentProcessor.token(ContentProcessor.sectionToken, in: lineLyrics) {
        // `const { type, label } = sectionStarts[i]` throws on a missing entry.
        guard let index, index < sectionStarts.count else { throw ChordProFailure() }
        let start = sectionStarts[index]
        body.append(.sectionLabel(type: start.type, label: start.label))
        continue
      }
      body.append(ContentProcessor.renderLine(line, inline: inline))
    }
    return SongBody(lines: body)
  }

  /// `lineLyrics.match(/TOKEN(\d+)/)`: `.some(nil)` when the digits do not fit an index.
  private static func token(_ token: Units, in s: Units) -> Int?? {
    guard s.count > token.count else { return nil }
    var i = 0
    while i + token.count < s.count {
      if s[i] == token[0], JS.matches(s, at: i, token), JS.isDigit(s[i + token.count]) {
        var end = i + token.count
        while end < s.count, JS.isDigit(s[end]) { end += 1 }
        return .some(JS.parseDigits(s, (i + token.count)..<end))
      }
      i += 1
    }
    return nil
  }

  private static func renderLine(_ line: SongLine, inline: Bool) -> BodyLine {
    var hasChords = false
    var hasContentItems = false
    var lyricsLine = Units()
    var parts: [RawPart] = []
    var pairs: [ChordLyricPair] = []
    for item in line {
      switch item {
      case .pair(let chord, let lyrics):
        guard !chord.isEmpty || !lyrics.isEmpty else { continue }
        if !chord.isEmpty { hasChords = true }
        if !inline {
          pairs.append(ChordLyricPair(chord: String(units: chord), lyrics: String(units: lyrics)))
        }
        lyricsLine.append(contentsOf: lyrics)
        if !lyrics.isEmpty { parts.append(.text(lyrics)) }
        if !chord.isEmpty {
          parts.append(.chord(chord))
          parts.append(.text([JS.space]))
        }
      case .comment(let content):
        guard !content.isEmpty else { continue }
        lyricsLine.append(contentsOf: content)
        parts.append(.text(content))
        hasContentItems = true
      case .tag, .other:
        continue
      }
    }
    if (hasContentItems && hasChords) || inline { return .inline(collapse(parts)) }
    if hasChords { return .chordLyrics(pairs) }
    return .text(String(units: lyricsLine))
  }

  private enum RawPart {
    case text(Units)
    case chord(Units)
  }

  /// `inlineParts.join("").replace(/\s{2,}/g, " ").trim()`, kept as parts. Chord markup starts
  /// with `<` and ends with `>`, so whitespace runs never cross a chord span.
  private static func collapse(_ raw: [RawPart]) -> [InlinePart] {
    var merged: [RawPart] = []
    for part in raw {
      if case .text(let t) = part, case .text(let previous)? = merged.last {
        merged[merged.count - 1] = .text(previous + t)
      } else {
        merged.append(part)
      }
    }
    var result: [InlinePart] = []
    for (index, part) in merged.enumerated() {
      switch part {
      case .chord(let c):
        result.append(.chord(String(units: JS.collapseWhitespaceRuns(c))))
      case .text(let t):
        var text = JS.collapseWhitespaceRuns(t)
        if index == 0 { text = JS.trimStart(text) }
        if index == merged.count - 1 { text = JS.trimEnd(text) }
        if !text.isEmpty { result.append(.text(String(units: text))) }
      }
    }
    return result
  }

  // MARK: Song.transpose

  /// `Song.transpose(delta, { normalizeChordSuffix: false })`: once a `{key}` tag is seen, later
  /// chords are normalized to the transposed key.
  static func transposeSong(_ lines: inout [SongLine], by delta: Int) throws {
    var transposedKey: Key?
    // Songs repeat a handful of chords; results only depend on the chord text and the key in
    // effect, so cache them until the next `{key}` tag. Failures are not cached (they throw).
    var cache: [Units: Units?] = [:]
    for l in lines.indices {
      for i in lines[l].indices {
        switch lines[l][i] {
        case .tag(let name, let value) where name == keyTagName:
          let key = try Key.parseOrFail(String(units: value)).transpose(delta)
          transposedKey = key
          cache.removeAll(keepingCapacity: true)
          lines[l][i] = .tag(name: name, value: try key.toString().units)
        case .pair(let chords, let lyrics):
          if chords.isEmpty { continue }
          let result: Units?
          if let cached = cache[chords] {
            result = cached
          } else {
            result = try transposeChord(chords, by: delta, key: transposedKey)
            cache[chords] = result
          }
          if let result { lines[l][i] = .pair(chords: result, lyrics: lyrics) }
        default:
          continue
        }
      }
    }
  }

  /// `ChordLyricsPair.transpose(delta, key)`; nil leaves the pair unchanged.
  private static func transposeChord(_ chords: Units, by delta: Int, key: Key?) throws -> Units? {
    guard let chord = Chord.parse(units: chords) else { return nil }
    var changed = try chord.transpose(delta)
    if let key { changed = try changed.normalize(key: key, normalizeSuffix: false) }
    let string = try changed.toString()
    return string.isEmpty ? nil : string.units
  }
}

extension SongBody {
  /// `parts.join("\n")`: an empty part still contributes its separator.
  init(joining parts: [SongBody]) {
    var lines: [BodyLine] = []
    for part in parts {
      if part.lines.isEmpty { lines.append(.text("")) } else { lines.append(contentsOf: part.lines) }
    }
    self.init(lines: lines)
  }

  /// The serialized HTML is "".
  var isEmptyHTML: Bool {
    lines.isEmpty || (lines.count == 1 && lines[0].isEmptyHTML)
  }

  /// `html.trimEnd()`: drops trailing blank lines and trailing whitespace of the last text line.
  func trimmingEnd() -> SongBody {
    var lines = self.lines
    while let last = lines.last {
      if case .text(let text) = last {
        let trimmed = JS.trimEnd(text.units)
        if trimmed.isEmpty {
          lines.removeLast()
          continue
        }
        lines[lines.count - 1] = .text(String(units: trimmed))
      } else if last.isEmptyHTML {
        lines.removeLast()
        continue
      }
      break
    }
    return SongBody(lines: lines)
  }
}

extension BodyLine {
  var isEmptyHTML: Bool {
    switch self {
    case .text(let t): return t.isEmpty
    case .inline(let parts): return parts.isEmpty
    default: return false
    }
  }
}
