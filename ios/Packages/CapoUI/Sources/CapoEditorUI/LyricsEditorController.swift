import Observation
import UIKit

/// Bridge between the SwiftUI editor chrome and the `UITextView`: exposes the selection and applies
/// edits through the text view so undo and the change delegate keep working.
@MainActor @Observable
final class LyricsEditorController {
  @ObservationIgnored weak var textView: UITextView?
  private(set) var selection = NSRange(location: 0, length: 0)

  var hasSelection: Bool { selection.length > 0 }

  func selectionChanged(_ range: NSRange) {
    if range != selection { selection = range }
  }

  /// Wraps the selected text in a section directive (web `wrapWithSection`).
  func wrap(_ type: SectionType) {
    guard let view = textView, view.selectedRange.length > 0 else { return }
    let range = view.selectedRange
    let ns = view.text as NSString
    let replacement = type.wrap(ns.substring(with: range), in: view.text)
    view.insertText(replacement)  // replaces the selection, keeps undo and fires the delegate
    view.selectedRange = NSRange(location: range.location + (replacement as NSString).length, length: 0)
  }

  /// Shifts the chords in the selection (or the whole text when nothing is selected) by `semitones`.
  /// Rewrites stored lyrics only; key, capo and transpose settings are untouched.
  func shiftChords(by semitones: Int) {
    guard let view = textView else { return }
    let ns = view.text as NSString
    let range = view.selectedRange.length > 0 ? view.selectedRange : NSRange(location: 0, length: ns.length)
    let original = ns.substring(with: range)
    let shifted = ShiftChords.shiftLyrics(original, by: semitones)
    guard shifted != original else { return }
    view.selectedRange = range
    view.insertText(shifted)  // replaces the range, keeps undo and fires the delegate
    view.selectedRange = NSRange(location: range.location, length: (shifted as NSString).length)
  }
}
