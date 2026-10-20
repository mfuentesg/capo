import CapoCore
import Foundation

/// Editable copy of a song's authored fields. Pure value type so validation and diffing are testable.
struct EditorForm: Equatable {
  static let keys: [String] = {
    let roots = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
    return roots + roots.map { $0 + "m" }
  }()
  static let bpmRange = 1...400

  var title = ""
  var artist = ""
  var key = ""
  var bpm = ""
  var transpose = 0
  var capo = 0
  var notes = ""
  var lyrics = ""
  var status: SongStatus = .published

  init() {}

  init(song: Song) {
    title = song.title
    artist = song.artist ?? ""
    key = song.key ?? ""
    bpm = song.bpm.map(String.init) ?? ""
    transpose = song.transpose
    capo = song.capo
    notes = song.notes ?? ""
    lyrics = song.lyrics ?? ""
    status = song.status
  }

  enum Issue: Equatable { case titleRequired, bpmInvalid }

  var issues: [Issue] {
    var result: [Issue] = []
    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append(.titleRequired) }
    if parsedBPM == .invalid { result.append(.bpmInvalid) }
    return result
  }

  var isValid: Bool { issues.isEmpty }

  enum BPM: Equatable { case none, value(Int), invalid }

  var parsedBPM: BPM {
    let trimmed = bpm.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return .none }
    guard let value = Int(trimmed), Self.bpmRange.contains(value) else { return .invalid }
    return .value(value)
  }

  private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

  private func clean(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  func draft() -> SongDraft {
    var bpmValue: Int?
    if case .value(let v) = parsedBPM { bpmValue = v }
    return SongDraft(
      title: cleanTitle, artist: clean(artist), key: clean(key), bpm: bpmValue,
      lyrics: lyrics.isEmpty ? nil : lyrics, notes: clean(notes),
      transpose: transpose, capo: capo, status: status)
  }

  /// Only the fields that differ from `song`. Empty string / 0 bpm clear a field (web semantics).
  func patch(against song: Song) -> SongPatch {
    var patch = SongPatch()
    let original = EditorForm(song: song)
    if cleanTitle != original.cleanTitle { patch.title = cleanTitle }
    if clean(artist) != clean(original.artist) { patch.artist = clean(artist) ?? "" }
    if clean(key) != clean(original.key) { patch.key = clean(key) ?? "" }
    if parsedBPM != original.parsedBPM {
      if case .value(let v) = parsedBPM { patch.bpm = v } else { patch.bpm = 0 }
    }
    if lyrics != original.lyrics { patch.lyrics = lyrics }
    if clean(notes) != clean(original.notes) { patch.notes = clean(notes) ?? "" }
    if transpose != original.transpose { patch.transpose = transpose }
    if capo != original.capo { patch.capo = capo }
    if status != original.status { patch.status = status }
    return patch
  }
}

extension SongPatch {
  var isEmpty: Bool { self == SongPatch() }
}

// MARK: Highlighting

enum LyricsTokenKind: Equatable { case chord, directive, comment }

struct LyricsToken: Equatable {
  var range: NSRange
  var kind: LyricsTokenKind
}

enum LyricsHighlighter {
  /// Finds `[chord]`, `{directive}` and `# comment` spans. Spans never cross a newline; an
  /// unterminated bracket is left unstyled so typing `[` does not recolor the rest of the song.
  static func tokens(in text: String) -> [LyricsToken] {
    let ns = text as NSString
    var tokens: [LyricsToken] = []
    var lineStart = 0
    while lineStart <= ns.length {
      var lineEnd = 0
      var contentsEnd = 0
      ns.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))
      let line = NSRange(location: lineStart, length: contentsEnd - lineStart)
      scan(ns, line, into: &tokens)
      if lineEnd <= lineStart { break }
      lineStart = lineEnd
    }
    return tokens
  }

  private static func scan(_ ns: NSString, _ line: NSRange, into tokens: inout [LyricsToken]) {
    guard line.length > 0 else { return }
    if ns.character(at: line.location) == 0x23 {  // '#'
      tokens.append(LyricsToken(range: line, kind: .comment))
      return
    }
    var index = line.location
    let end = line.location + line.length
    while index < end {
      let c = ns.character(at: index)
      let close: unichar? = c == 0x5B ? 0x5D : (c == 0x7B ? 0x7D : nil)
      if let close {
        var j = index + 1
        while j < end, ns.character(at: j) != close { j += 1 }
        if j < end {
          tokens.append(
            LyricsToken(
              range: NSRange(location: index, length: j - index + 1),
              kind: c == 0x5B ? .chord : .directive))
          index = j + 1
          continue
        }
      }
      index += 1
    }
  }
}

// MARK: Directive snippets

struct DirectiveSnippet: Identifiable, Equatable {
  var id: String { label }
  var label: String
  /// Text inserted at the caret. `$0` marks where the caret lands afterwards (removed on insert).
  var template: String

  func resolved() -> (text: String, caretOffset: Int) {
    guard let range = template.range(of: "$0") else { return (template, template.utf16.count) }
    let offset = template[..<range.lowerBound].utf16.count
    return (template.replacingCharacters(in: range, with: ""), offset)
  }

  /// Mirrors the section / comment / metadata entries of `chordpro-directives.ts`.
  static let all: [DirectiveSnippet] = [
    DirectiveSnippet(label: "Verse", template: "{sov: $0}\n\n{eov}"),
    DirectiveSnippet(label: "Chorus", template: "{soc: $0}\n\n{eoc}"),
    DirectiveSnippet(label: "Bridge", template: "{sob: $0}\n\n{eob}"),
    DirectiveSnippet(label: "Pre-chorus", template: "{sopc: $0}\n\n{eopc}"),
    DirectiveSnippet(label: "Tab", template: "{sot: $0}\n\n{eot}"),
    DirectiveSnippet(label: "Grid", template: "{sog: $0}\n\n{eog}"),
    DirectiveSnippet(label: "Comment", template: "{comment: $0}"),
    DirectiveSnippet(label: "Comment (italic)", template: "{comment_italic: $0}"),
    DirectiveSnippet(label: "Comment (box)", template: "{comment_box: $0}"),
    DirectiveSnippet(label: "Key", template: "{key: $0}"),
    DirectiveSnippet(label: "Tempo", template: "{tempo: $0}"),
    DirectiveSnippet(label: "Time", template: "{time: $0}")
  ]
}

/// Applies an insertion to `text` at `selection` (UTF-16), replacing the selection.
func insertText(_ insertion: String, caretOffset: Int, into text: String, selection: NSRange)
  -> (text: String, selection: NSRange)
{
  let ns = text as NSString
  let safe = NSRange(
    location: min(selection.location, ns.length),
    length: min(selection.length, ns.length - min(selection.location, ns.length)))
  let result = ns.replacingCharacters(in: safe, with: insertion)
  return (result, NSRange(location: safe.location + caretOffset, length: 0))
}
