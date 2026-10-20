import CapoDesign
import Foundation
import Testing

@testable import CapoEditorUI

private func song(
  title: String = "Grace", artist: String? = "JN", key: String? = "G", bpm: Int? = 90,
  lyrics: String? = "[G]Amazing", notes: String? = nil
) -> Song {
  Song(
    id: UUID(), title: title, artist: artist, key: key, bpm: bpm, lyrics: lyrics, notes: notes,
    transpose: 0, capo: 0, status: .published, userID: UUID(), teamID: nil, createdBy: UUID(),
    createdAt: ServerTimestamp("2026-01-01T00:00:00.000000+00:00"),
    updatedAt: ServerTimestamp("2026-01-01T00:00:01.000000+00:00"))
}

@MainActor private func spans(_ text: String, _ kind: LyricsTokenKind) -> [String] {
  let ns = text as NSString
  return LyricsHighlighter.tokens(in: text).filter { $0.kind == kind }.map { ns.substring(with: $0.range) }
}

@MainActor @Suite struct HighlighterTests {
  @Test func findsChordsAndDirectives() {
    let text = "{sov: Verse 1}\n[G]Amazing [D/F#]grace\n{eov}"
    #expect(spans(text, .chord) == ["[G]", "[D/F#]"])
    #expect(spans(text, .directive) == ["{sov: Verse 1}", "{eov}"])
  }

  @Test func unterminatedBracketIsIgnored() {
    #expect(spans("[G]one [Am\nsecond [C]", .chord) == ["[G]", "[C]"])
    #expect(spans("{comment: oops\n[G]x", .directive).isEmpty)
  }

  @Test func hashLinesAreComments() {
    let text = "# note [G]\n[C]x"
    #expect(spans(text, .comment) == ["# note [G]"])
    #expect(spans(text, .chord) == ["[C]"])
  }

  @Test func handlesEmojiAndEmptyInput() {
    #expect(LyricsHighlighter.tokens(in: "").isEmpty)
    #expect(spans("🎸 [Em]hola\n", .chord) == ["[Em]"])
  }

  @Test func crlfLines() {
    #expect(spans("[G]a\r\n[C]b", .chord) == ["[G]", "[C]"])
  }
}

@MainActor @Suite struct SnippetTests {
  @Test func caretLandsAtMarker() {
    let (text, caret) = DirectiveSnippet.all[0].resolved()
    #expect(text == "{sov: }\n\n{eov}")
    #expect(caret == 6)
  }

  @Test func insertReplacesSelection() {
    let result = insertText("[]", caretOffset: 1, into: "abcdef", selection: NSRange(location: 2, length: 2))
    #expect(result.text == "ab[]ef")
    #expect(result.selection == NSRange(location: 3, length: 0))
  }

  @Test func insertClampsOutOfRangeSelection() {
    let result = insertText("x", caretOffset: 1, into: "ab", selection: NSRange(location: 9, length: 3))
    #expect(result.text == "abx")
  }
}

@MainActor @Suite struct FormTests {
  @Test func titleIsRequired() {
    var form = EditorForm()
    #expect(form.issues == [.titleRequired])
    form.title = "   "
    #expect(!form.isValid)
    form.title = "Hi"
    #expect(form.isValid)
  }

  @Test func bpmValidation() {
    var form = EditorForm()
    form.title = "x"
    form.bpm = ""
    #expect(form.isValid)
    form.bpm = "120"
    #expect(form.parsedBPM == .value(120))
    for bad in ["0", "401", "abc", "-5", "1.5"] {
      form.bpm = bad
      #expect(form.issues == [.bpmInvalid], "bpm \(bad)")
    }
  }

  @Test func draftTrimsAndMapsEmptyToNil() {
    var form = EditorForm()
    form.title = "  Song "
    form.artist = " "
    form.bpm = "100"
    form.capo = 2
    let draft = form.draft()
    #expect(draft.title == "Song")
    #expect(draft.artist == nil)
    #expect(draft.key == nil)
    #expect(draft.bpm == 100)
    #expect(draft.capo == 2)
    #expect(draft.lyrics == nil)
  }

  @Test func unchangedFormProducesEmptyPatch() {
    let s = song()
    #expect(EditorForm(song: s).patch(against: s).isEmpty)
  }

  @Test func patchContainsOnlyChangedFields() {
    let s = song()
    var form = EditorForm(song: s)
    form.title = "New"
    form.transpose = 2
    let patch = form.patch(against: s)
    #expect(patch.title == "New")
    #expect(patch.transpose == 2)
    #expect(patch.artist == nil && patch.lyrics == nil && patch.bpm == nil)
  }

  @Test func clearingFieldsUsesEmptyStringAndZeroBPM() {
    let s = song(notes: "n")
    var form = EditorForm(song: s)
    form.artist = ""
    form.key = ""
    form.bpm = ""
    form.notes = ""
    let patch = form.patch(against: s)
    #expect(patch.artist == "")
    #expect(patch.key == "")
    #expect(patch.bpm == 0)
    #expect(patch.notes == "")
  }

  @Test func keyListHasMajorsAndMinors() {
    #expect(EditorForm.keys.count == 24)
    #expect(EditorForm.keys.contains("F#m"))
  }
}

@MainActor @Suite struct ConflictComparisonTests {
  @Test func marksDifferingFields() {
    let local = song(title: "Mine")
    var server = local
    server.title = "Theirs"
    let fields = ConflictComparison.fields(local: local, server: server)
    #expect(fields.filter(\.differs).map(\.label) == [EditorStrings.title])
  }

  @Test func deletedServerRowHasNoTheirsValues() {
    let fields = ConflictComparison.fields(local: song(), server: nil)
    #expect(fields.allSatisfy { $0.theirs == nil && !$0.differs })
  }
}
