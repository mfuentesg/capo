// Reproduces the HTML strings song-pipeline.ts builds. The render model is a total encoding of
// that HTML, so this serializer is what the golden tests compare against.
//
// Chord and lyric text are emitted unescaped (as the web does); comment, label, note, section,
// volta and box labels go through escapeHtml.

public enum LegacyHTMLSerializer {
  public static func html(_ body: SongBody, commentLabel: String) -> String {
    var out = ""
    append(body, commentLabel: escape(commentLabel), to: &out)
    return out
  }

  private static func append(_ body: SongBody, commentLabel: String, to out: inout String) {
    for (index, line) in body.lines.enumerated() {
      if index > 0 { out += "\n" }
      append(line, commentLabel: commentLabel, to: &out)
    }
  }

  private static func append(_ line: BodyLine, commentLabel: String, to out: inout String) {
    switch line {
    case .chordLyrics(let pairs):
      out += "<span class=\"clp-pair\"><span class=\"clp-chords\">"
      for pair in pairs {
        let width = max(pair.chord.utf16.count, pair.lyrics.utf16.count)
        out += "<span class=\"clp-col\" style=\"min-width:\(width)ch\">"
        if !pair.chord.isEmpty { out += "<span class=\"chord\">\(pair.chord)</span>" }
        out += "</span>"
      }
      out += "</span><span class=\"clp-lyric-text\">"
      for pair in pairs { out += pair.lyrics }
      out += "</span></span>"
    case .inline(let parts):
      for part in parts {
        switch part {
        case .text(let text): out += text
        case .chord(let chord): out += "<span class=\"chord\">\(chord)</span>"
        }
      }
    case .text(let text):
      out += text
    case .comment(let text):
      out +=
        "<div class=\"lyrics-comment\"><div class=\"lyrics-comment-label\">\(commentLabel)</div>"
        + "<div class=\"lyrics-comment-body\">\(escape(text))</div></div>"
    case .label(let text):
      out += "<div class=\"lyrics-label\">\(escape(text))</div>"
    case .performanceNote(let text):
      out += "<span class=\"performance-note\">\(escape(text))</span>"
    case .sectionLabel(let type, let label):
      out += "<span class=\"section-label section-label--\(type)\">\(escape(label))</span>"
    case .volta(let label, let body):
      out += "<div class=\"volta-block\">"
      if !label.isEmpty { out += "<div class=\"volta-label\">\(escape(label))</div>" }
      out += "<div class=\"volta-content\">"
      append(body, commentLabel: commentLabel, to: &out)
      out += "</div></div>"
    case .box(let label, let body):
      out += "<div class=\"lyrics-box\">"
      if !label.isEmpty { out += "<div class=\"lyrics-box-label\">\(escape(label))</div>" }
      out += "<div class=\"lyrics-box-content\">"
      append(body, commentLabel: commentLabel, to: &out)
      out += "</div></div>"
    }
  }

  /// song-pipeline.ts `escapeHtml`: & < > " only.
  static func escape(_ s: String) -> String {
    guard s.utf8.contains(where: { $0 == 0x26 || $0 == 0x3C || $0 == 0x3E || $0 == 0x22 }) else {
      return s
    }
    var out = ""
    out.reserveCapacity(s.utf8.count + 16)
    for scalar in s.unicodeScalars {
      switch scalar {
      case "&": out += "&amp;"
      case "<": out += "&lt;"
      case ">": out += "&gt;"
      case "\"": out += "&quot;"
      default: out.unicodeScalars.append(scalar)
      }
    }
    return out
  }
}
