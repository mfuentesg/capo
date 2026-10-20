// buildSectionMap and buildSegments from song-pipeline.ts.

struct SectionEntry {
  let content: Units
  let sectionType: String
}

enum SegmentBuilder {
  static func buildSectionMap(_ lyrics: Units) -> [String: SectionEntry] {
    var map: [String: SectionEntry] = [:]

    // 1. Named explicit blocks {soc: Name}...{eoc} (lazy, first end marker of any kind).
    var from = 0
    while let start = Directives.namedBlockStart.firstMatch(lyrics, from: from) {
      guard let end = Directives.sectionEnd.firstMatch(lyrics, from: start.end) else {
        from = start.start + 1
        continue
      }
      let directive = String(units: Directives.namedBlockStart.literals[start.literal])
      let sectionType = Directives.sectionTypes[directive] ?? "section"
      if let capture = start.capture {
        let name = JS.trim(lyrics, capture)
        if !name.isEmpty {
          let cleanName = String(units: SectionValue(name).name).lowercased()
          map[cleanName] = SectionEntry(
            content: JS.trim(lyrics, start.end..<end.start), sectionType: sectionType)
        }
      }
      from = end.end
    }

    // 2. Comment-labelled sections: content up to the next section boundary.
    from = 0
    while let m = Directives.namedComment.firstMatch(lyrics, from: from) {
      from = m.end
      let name = JS.trim(lyrics, m.capture!)
      let key = String(units: name).lowercased()
      if name.isEmpty || map[key] != nil { continue }
      let boundary = Directives.sectionBoundary(lyrics, from: m.end) ?? lyrics.count
      let content = JS.trim(lyrics, m.end..<boundary)
      if !content.isEmpty { map[key] = SectionEntry(content: content, sectionType: "comment") }
    }
    return map
  }

  private static let commentDirectives: Set<String> = [
    "c", "comment", "comment_italic", "comment_box"
  ]

  static func buildSegments(
    _ lyrics: Units, sectionMap: [String: SectionEntry], processor: ContentProcessor
  ) throws -> [LyricsSegment] {
    var segments: [LyricsSegment] = []
    var pos = 0

    func render(_ text: Units, inline: Bool) throws -> SongBody {
      try processor.box(text, inline: inline)
    }

    while true {
      guard let match = Directives.segmentScan.firstMatch(lyrics, from: pos) else {
        let tail = JS.trim(lyrics, pos..<lyrics.count)
        if !tail.isEmpty { segments.append(.normal(try render(tail, inline: false))) }
        break
      }
      let directive = String(units: Directives.segmentScan.literals[match.literal])
      let value = match.capture.map { JS.trim(lyrics, $0) } ?? []
      let before = JS.trim(lyrics, pos..<match.start)
      if !before.isEmpty { segments.append(.normal(try render(before, inline: false))) }

      var newPos = match.end

      if directive == "repeat" {
        if !value.isEmpty {
          let parsed = SectionValue(value)
          let name = String(units: parsed.name)
          let displayLabel = parsed.displayLabel.map { String(units: $0) }
          if let entry = sectionMap[name.lowercased()] {
            let inline = parsed.flags.contains(.inline)
            segments.append(
              .repeatRef(
                name: name, displayLabel: displayLabel, count: parsed.count,
                body: try render(entry.content, inline: inline), found: true,
                sectionType: entry.sectionType, flags: parsed.flags))
          } else {
            segments.append(
              .repeatRef(
                name: name, displayLabel: displayLabel, count: parsed.count,
                body: SongBody(lines: []), found: false, sectionType: "repeat", flags: []))
          }
        }
      } else if directive == "start_of_extend" || directive == "soex" {
        if !value.isEmpty {
          let parsed = SectionValue(value)
          let name = String(units: parsed.name)
          let entry = sectionMap[name.lowercased()]
          let end = Directives.extendEnd.firstMatch(lyrics, from: match.end)
          let extendBody = JS.trim(lyrics, match.end..<(end?.start ?? lyrics.count))
          var combined: Units
          if let entry {
            combined = entry.content
            if !extendBody.isEmpty { combined += [JS.lf] + extendBody }
          } else {
            combined = extendBody
          }
          segments.append(
            .extend(
              name: name, displayLabel: parsed.displayLabel.map { String(units: $0) },
              count: parsed.count,
              body: try render(combined, inline: parsed.flags.contains(.inline)),
              found: entry != nil, sectionType: entry?.sectionType ?? "extend",
              flags: parsed.flags))
          newPos = end?.end ?? lyrics.count
        }
      } else if commentDirectives.contains(directive) {
        if !value.isEmpty {
          let parsed = SectionValue(value)
          segments.append(
            .section(
              name: String(units: parsed.name),
              sectionType: parsed.flags.contains(.label) ? "comment-label" : "comment",
              body: SongBody(lines: []), count: 1, flags: [], inline: false))
        }
      } else {
        let sectionType = Directives.sectionTypes[directive] ?? "section"
        let name: String
        var count = 1
        var flags: [SectionFlag] = []
        if !value.isEmpty {
          let parsed = SectionValue(value)
          name = String(units: parsed.name)
          count = parsed.count
          flags = parsed.flags
        } else {
          name = processor.sectionLabels[sectionType] ?? sectionType
        }
        let end = Directives.sectionEnd.firstMatch(lyrics, from: match.end)
        let content = JS.trim(lyrics, match.end..<(end?.start ?? lyrics.count))
        let inline = flags.contains(.inline)
        segments.append(
          .section(
            name: name, sectionType: sectionType, body: try render(content, inline: inline),
            count: count, flags: flags, inline: inline))
        newPos = end?.end ?? lyrics.count
      }
      pos = newPos
    }
    return segments
  }
}
