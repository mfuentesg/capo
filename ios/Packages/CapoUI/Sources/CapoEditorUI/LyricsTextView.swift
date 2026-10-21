import SwiftUI
import UIKit

/// Code-editor palette for the ChordPro source (Catppuccin Latte / Mocha, like the web editor).
nonisolated enum EditorPalette {
  static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
    UIColor { $0.userInterfaceStyle == .dark ? hex(dark) : hex(light) }
  }

  static func hex(_ value: UInt32) -> UIColor {
    UIColor(
      red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255, alpha: 1)
  }

  static let text = dynamic(0x4c4f69, 0xcdd6f4)
  static let directive = dynamic(0x179299, 0x94e2d5)
  static let chord = dynamic(0x8839ef, 0xcba6f7)
  static let section = dynamic(0x1e66f5, 0x89b4fa)
  static let comment = dynamic(0x7c7f93, 0x9399b2)
  static let gutterText = dynamic(0x9ca0b0, 0x6c7086)
  static let gutterFill = dynamic(0xe6e9ef, 0x181825)
  static let gutterBorder = dynamic(0xccd0da, 0x313244)
  static let editorFill = dynamic(0xeff1f5, 0x1e1e2e)
  static let accessoryFill = dynamic(0xdce0e8, 0x181825)
  static let accessoryBorder = dynamic(0xbcc0cc, 0x45475a)
  static let chipFill = dynamic(0xeff1f5, 0x313244)
  static let peach = dynamic(0xfe640b, 0xfab387)
  static let directiveChipText = dynamic(0x0f6d73, 0x94e2d5)
}

/// Layout manager that draws the line-number gutter and the current-line highlight.
nonisolated final class CodeLayoutManager: NSLayoutManager {
  static let gutterWidth: CGFloat = 48
  var caretLocation = 0

  override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
    super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
    guard let context = UIGraphicsGetCurrentContext(), let container = textContainers.first else {
      return
    }
    let clip = context.boundingBoxOfClipPath
    let font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font, .foregroundColor: EditorPalette.gutterText
    ]
    let text = textStorage?.string as NSString? ?? ""
    let gutter = CGRect(x: origin.x, y: clip.minY, width: Self.gutterWidth, height: clip.height)
    context.setFillColor(EditorPalette.gutterFill.cgColor)
    context.fill(gutter)
    context.setFillColor(EditorPalette.gutterBorder.cgColor)
    context.fill(CGRect(x: gutter.maxX - 1, y: gutter.minY, width: 1, height: gutter.height))

    let caretLine = text.lineRange(for: NSRange(location: min(caretLocation, text.length), length: 0))
    var number = 1
    let drawLine: (CGRect, Int, Bool) -> Void = { rect, n, current in
      let r = rect.offsetBy(dx: origin.x, dy: origin.y)
      if current {
        context.setFillColor(EditorPalette.peach.withAlphaComponent(0.09).cgColor)
        context.fill(CGRect(x: r.minX + Self.gutterWidth, y: r.minY, width: 4000, height: r.height))
        context.setFillColor(EditorPalette.peach.withAlphaComponent(0.18).cgColor)
        context.fill(CGRect(x: r.minX, y: r.minY, width: Self.gutterWidth - 1, height: r.height))
      }
      let label = "\(n)" as NSString
      let size = label.size(withAttributes: attributes)
      label.draw(
        at: CGPoint(
          x: r.minX + Self.gutterWidth - 10 - size.width,
          y: r.minY + (r.height - size.height) / 2),
        withAttributes: attributes)
    }

    let all = NSRange(location: 0, length: numberOfGlyphs)
    enumerateLineFragments(forGlyphRange: all) { rect, _, _, glyphRange, _ in
      let chars = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
      let startsLine = chars.location == 0 || text.character(at: chars.location - 1) == 0x0A
      guard startsLine else { return }
      if rect.maxY + origin.y >= clip.minY, rect.minY + origin.y <= clip.maxY {
        drawLine(rect, number, chars.location == caretLine.location)
      }
      number += 1
    }
    if text.length == 0 || text.character(at: text.length - 1) == 0x0A {
      let rect = extraLineFragmentRect
      if !rect.isEmpty { drawLine(rect, number, caretLine.location >= text.length) }
    }
  }
}

/// `UITextView` wrapper with ChordPro highlighting, line numbers and a 48pt accessory bar.
struct LyricsTextView: UIViewRepresentable {
  @Binding var text: String
  var songKey: String = ""

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeUIView(context: Context) -> UITextView {
    let storage = NSTextStorage()
    let layout = CodeLayoutManager()
    storage.addLayoutManager(layout)
    let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    container.widthTracksTextView = true
    container.lineFragmentPadding = 0
    container.exclusionPaths = [
      UIBezierPath(rect: CGRect(x: 0, y: 0, width: CodeLayoutManager.gutterWidth + 12, height: 1_000_000))
    ]
    layout.addTextContainer(container)
    let view = UITextView(frame: .zero, textContainer: container)
    view.delegate = context.coordinator
    view.backgroundColor = EditorPalette.editorFill
    view.autocapitalizationType = .none
    view.autocorrectionType = .no
    view.smartQuotesType = .no
    view.smartDashesType = .no
    view.alwaysBounceVertical = true
    view.keyboardDismissMode = .interactive
    view.textContainerInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 12)
    view.tintColor = EditorPalette.peach
    view.adjustsFontForContentSizeCategory = true
    view.accessibilityIdentifier = "editor.lyrics"
    context.coordinator.textView = view
    context.coordinator.songKey = songKey
    view.inputAccessoryView = context.coordinator.makeAccessory(for: view)
    view.text = text
    Coordinator.highlight(view)
    return view
  }

  func updateUIView(_ view: UITextView, context: Context) {
    context.coordinator.parent = self
    if context.coordinator.songKey != songKey {
      context.coordinator.songKey = songKey
      context.coordinator.rebuildChips()
    }
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
    var songKey = ""
    private var chipStack: UIStackView?
    private let haptics = UIImpactFeedbackGenerator(style: .light)

    init(_ parent: LyricsTextView) { self.parent = parent }

    static var font: UIFont {
      UIFontMetrics(forTextStyle: .body).scaledFont(
        for: .monospacedSystemFont(ofSize: 17, weight: .regular))
    }

    static var lineHeight: CGFloat { 28 }

    static func highlight(_ view: UITextView) {
      guard view.markedTextRange == nil else { return }  // don't disturb IME composition
      let storage = view.textStorage
      let full = NSRange(location: 0, length: storage.length)
      let style = NSMutableParagraphStyle()
      style.minimumLineHeight = lineHeight
      style.maximumLineHeight = lineHeight
      let bold = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)
      let italic = UIFont(
        descriptor: font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? font.fontDescriptor,
        size: font.pointSize)
      let ns = view.text as NSString
      storage.beginEditing()
      storage.setAttributes(
        [.font: font, .foregroundColor: EditorPalette.text, .paragraphStyle: style], range: full)
      for token in LyricsHighlighter.tokens(in: view.text) {
        switch token.kind {
        case .chord:
          storage.addAttributes(
            [.foregroundColor: EditorPalette.chord, .font: bold], range: token.range)
        case .directive:
          storage.addAttribute(.foregroundColor, value: EditorPalette.directive, range: token.range)
          let source = ns.substring(with: token.range)
          if let name = LyricsHighlighter.sectionNameRange(inDirective: source) {
            storage.addAttributes(
              [.foregroundColor: EditorPalette.section, .font: bold],
              range: NSRange(location: token.range.location + name.lowerBound, length: name.count))
          }
        case .comment:
          storage.addAttributes(
            [.foregroundColor: EditorPalette.comment, .font: italic], range: token.range)
        }
      }
      storage.endEditing()
      view.typingAttributes = [
        .font: font, .foregroundColor: EditorPalette.text, .paragraphStyle: style
      ]
    }

    func textViewDidChange(_ textView: UITextView) {
      Self.highlight(textView)
      updateCaret(textView)
      if parent.text != textView.text { parent.text = textView.text }
    }

    func textViewDidChangeSelection(_ textView: UITextView) { updateCaret(textView) }

    private func updateCaret(_ textView: UITextView) {
      guard let layout = textView.layoutManager as? CodeLayoutManager else { return }
      layout.caretLocation = textView.selectedRange.location
      textView.setNeedsDisplay()
    }

    // MARK: Accessory bar

    func makeAccessory(for view: UITextView) -> UIView {
      let bar = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 64))
      bar.autoresizingMask = .flexibleWidth
      bar.backgroundColor = EditorPalette.accessoryFill
      bar.accessibilityIdentifier = "editor.accessory"
      let border = UIView()
      border.backgroundColor = EditorPalette.accessoryBorder
      border.translatesAutoresizingMaskIntoConstraints = false
      bar.addSubview(border)

      let undo = iconButton("arrow.uturn.backward", label: "Undo", id: "editor.undo") {
        [weak view] in view?.undoManager?.undo()
      }
      let done = iconButton(
        "keyboard.chevron.compact.down", label: EditorStrings.dismissKeyboard, id: "editor.dismissKeyboard"
      ) { [weak view] in view?.resignFirstResponder() }

      let scroll = UIScrollView()
      scroll.showsHorizontalScrollIndicator = false
      scroll.translatesAutoresizingMaskIntoConstraints = false
      let stack = UIStackView()
      stack.axis = .horizontal
      stack.spacing = 8
      stack.alignment = .center
      stack.translatesAutoresizingMaskIntoConstraints = false
      scroll.addSubview(stack)
      chipStack = stack

      let separator = UIView()
      separator.backgroundColor = EditorPalette.accessoryBorder
      separator.translatesAutoresizingMaskIntoConstraints = false
      for item in [undo, separator, scroll, done] {
        item.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(item)
      }
      NSLayoutConstraint.activate([
        border.topAnchor.constraint(equalTo: bar.topAnchor),
        border.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
        border.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
        border.heightAnchor.constraint(equalToConstant: 1),
        undo.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 12),
        undo.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        separator.leadingAnchor.constraint(equalTo: undo.trailingAnchor, constant: 8),
        separator.widthAnchor.constraint(equalToConstant: 1),
        separator.heightAnchor.constraint(equalToConstant: 32),
        separator.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        scroll.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 8),
        scroll.topAnchor.constraint(equalTo: bar.topAnchor),
        scroll.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        scroll.trailingAnchor.constraint(equalTo: done.leadingAnchor, constant: -8),
        done.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
        done.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
        stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
        stack.centerYAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerYAnchor)
      ])
      rebuildChips()
      return bar
    }

    func rebuildChips() {
      guard let stack = chipStack else { return }
      stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
      for chip in AccessoryChip.all(forKey: songKey) {
        stack.addArrangedSubview(chipButton(chip))
      }
    }

    private func chipButton(_ chip: AccessoryChip) -> UIButton {
      var config = UIButton.Configuration.plain()
      let color: UIColor
      switch chip.kind {
      case .plain:
        color = EditorPalette.text
        config.background.backgroundColor = EditorPalette.chipFill
      case .directive:
        color = EditorPalette.directiveChipText
        config.background.backgroundColor = EditorPalette.directive.withAlphaComponent(0.16)
      case .chord:
        color = EditorPalette.chord
        config.background.backgroundColor = EditorPalette.chord.withAlphaComponent(0.14)
      }
      config.attributedTitle = AttributedString(
        chip.label,
        attributes: AttributeContainer([
          .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .bold), .foregroundColor: color
        ]))
      config.background.cornerRadius = 12
      config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
      let button = UIButton(
        configuration: config,
        primaryAction: UIAction { [weak self] _ in
          let resolved = chip.resolved()
          self?.haptics.impactOccurred()
          self?.insert(resolved.text, caretOffset: resolved.caretOffset)
        })
      button.accessibilityIdentifier = "editor.chip.\(chip.label)"
      button.heightAnchor.constraint(equalToConstant: 48).isActive = true
      button.widthAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
      return button
    }

    private func iconButton(
      _ symbol: String, label: String, id: String, action: @escaping () -> Void
    ) -> UIButton {
      var config = UIButton.Configuration.plain()
      config.image = UIImage(systemName: symbol)
      config.baseForegroundColor = EditorPalette.text
      config.background.backgroundColor = EditorPalette.chipFill
      config.background.cornerRadius = 12
      let button = UIButton(
        configuration: config,
        primaryAction: UIAction { [weak self] _ in
          self?.haptics.impactOccurred()
          action()
        })
      button.accessibilityLabel = label
      button.accessibilityIdentifier = id
      button.widthAnchor.constraint(equalToConstant: 48).isActive = true
      button.heightAnchor.constraint(equalToConstant: 48).isActive = true
      return button
    }

    private func insert(_ string: String, caretOffset: Int) {
      guard let view = textView else { return }
      let start = view.selectedRange.location
      view.insertText(string)  // keeps the undo stack and fires the delegate
      view.selectedRange = NSRange(location: start + caretOffset, length: 0)
    }
  }
}
