import SwiftUI
import UIKit

/// `UITextView` wrapper with ChordPro highlighting and an accessory bar for `[`, `{`, directive
/// snippets and keyboard dismissal.
struct LyricsTextView: UIViewRepresentable {
  @Binding var text: String

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIView(context: Context) -> UITextView {
    let view = UITextView()
    view.delegate = context.coordinator
    view.backgroundColor = .clear
    view.autocapitalizationType = .none
    view.autocorrectionType = .no
    view.smartQuotesType = .no
    view.smartDashesType = .no
    view.alwaysBounceVertical = true
    view.keyboardDismissMode = .interactive
    view.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
    view.adjustsFontForContentSizeCategory = true
    view.accessibilityIdentifier = "editor.lyrics"
    view.inputAccessoryView = context.coordinator.makeAccessory(for: view)
    context.coordinator.textView = view
    view.text = text
    Coordinator.highlight(view)
    return view
  }

  func updateUIView(_ view: UITextView, context: Context) {
    context.coordinator.parent = self
    if view.text != text {
      let selection = view.selectedRange
      view.text = text
      view.selectedRange = NSRange(
        location: min(selection.location, (text as NSString).length), length: 0)
      Coordinator.highlight(view)
    }
  }

  @MainActor
  final class Coordinator: NSObject, UITextViewDelegate {
    var parent: LyricsTextView
    weak var textView: UITextView?

    init(_ parent: LyricsTextView) { self.parent = parent }

    static var font: UIFont {
      UIFontMetrics(forTextStyle: .body).scaledFont(
        for: .monospacedSystemFont(ofSize: 16, weight: .regular))
    }

    static func highlight(_ view: UITextView) {
      guard view.markedTextRange == nil else { return }  // don't disturb IME composition
      let storage = view.textStorage
      let full = NSRange(location: 0, length: storage.length)
      storage.beginEditing()
      storage.setAttributes([.font: font, .foregroundColor: UIColor.label], range: full)
      for token in LyricsHighlighter.tokens(in: view.text) {
        switch token.kind {
        case .chord:
          storage.addAttributes(
            [
              .foregroundColor: UIColor.systemBlue,
              .font: UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .semibold)
            ], range: token.range)
        case .directive:
          storage.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: token.range)
        case .comment:
          storage.addAttribute(
            .foregroundColor, value: UIColor.secondaryLabel, range: token.range)
        }
      }
      storage.endEditing()
    }

    func textViewDidChange(_ textView: UITextView) {
      Self.highlight(textView)
      if parent.text != textView.text { parent.text = textView.text }
    }

    // MARK: Accessory bar

    func makeAccessory(for view: UITextView) -> UIView {
      let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
      toolbar.autoresizingMask = .flexibleWidth

      func button(_ title: String, id: String, action: @escaping () -> Void) -> UIBarButtonItem {
        let item = UIBarButtonItem(
          title: title, primaryAction: UIAction { _ in action() })
        item.accessibilityIdentifier = id
        return item
      }

      let chord = button("[ ]", id: "editor.insertChord") { [weak self] in
        self?.insert("[]", caretOffset: 1)
      }
      let directive = button("{ }", id: "editor.insertBrace") { [weak self] in
        self?.insert("{}", caretOffset: 1)
      }
      let snippets = UIBarButtonItem(
        title: EditorStrings.insertDirective,
        image: UIImage(systemName: "text.badge.plus"),
        menu: UIMenu(
          title: EditorStrings.insertDirective,
          children: DirectiveSnippet.all.map { snippet in
            UIAction(title: snippet.label) { [weak self] _ in
              let resolved = snippet.resolved()
              self?.insert(resolved.text, caretOffset: resolved.caretOffset)
            }
          }))
      let done = UIBarButtonItem(
        image: UIImage(systemName: "keyboard.chevron.compact.down"),
        primaryAction: UIAction { [weak view] _ in view?.resignFirstResponder() })
      done.accessibilityLabel = EditorStrings.dismissKeyboard
      toolbar.items = [chord, directive, snippets, .flexibleSpace(), done]
      return toolbar
    }

    private func insert(_ string: String, caretOffset: Int) {
      guard let view = textView else { return }
      let start = view.selectedRange.location
      view.insertText(string)  // keeps the undo stack and fires the delegate
      view.selectedRange = NSRange(location: start + caretOffset, length: 0)
    }
  }
}
