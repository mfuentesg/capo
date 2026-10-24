import CapoDesign
import CapoIcons
import SwiftUI
import UIKit

nonisolated struct ReferenceDirective: Equatable {
  enum Category: String, CaseIterable { case metadata, section, comment, chord, formatting }
  var name: String
  var shorthand: String?
  var category: Category
  var summary: String
  var example: String
}

nonisolated struct ReferenceFlag: Equatable {
  var flag: String
  var summary: String
  var example: String
}

extension ReferenceDirective {
  /// Web `CATEGORY_ORDER`.
  static let categoryOrder: [Category] = [.metadata, .section, .comment, .chord, .formatting]

  static func directives(in category: Category) -> [ReferenceDirective] {
    ReferenceData.directives.filter { $0.category == category }
  }

  static func title(for category: Category) -> String {
    switch category {
    case .metadata: L10n.Songs.Lyrics.Reference.metadata
    case .section: L10n.Songs.Lyrics.Reference.section
    case .comment: L10n.Songs.Lyrics.Reference.comment
    case .chord: L10n.Songs.Lyrics.Reference.chord
    case .formatting: L10n.Songs.Lyrics.Reference.formatting
    }
  }
}

/// Copy action text: `←` annotations are dropped (web `CopyButton`).
nonisolated func cleanReferenceExample(_ text: String) -> String {
  text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
    guard let arrow = line.firstIndex(of: "←") else { return String(line) }
    var kept = line[..<arrow]
    while kept.last == " " || kept.last == "\t" { kept = kept.dropLast() }
    return String(kept)
  }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

/// ChordPro reference (web `chordpro-reference.tsx`): directives by category, then performance flags.
struct ChordProReferenceView: View {
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(L10n.Songs.Lyrics.chordproReference).capoText(.sm, weight: .semibold)
          .accessibilityAddTraits(.isHeader)
        Spacer()
        Button(action: onClose) {
          CapoIcon(.x, size: 18).frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(L10n.Common.close)
      }
      .padding(.leading, 16).padding(.trailing, 4)
      Divider().overlay(CapoTheme.border)
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(ReferenceDirective.categoryOrder, id: \.self) { category in
            heading(ReferenceDirective.title(for: category))
            let items = ReferenceDirective.directives(in: category)
            ForEach(items.indices, id: \.self) { index in
              directive(items[index], isLast: index == items.count - 1)
            }
          }
          heading(L10n.Songs.Lyrics.Reference.performanceFlags)
          Text(L10n.Songs.Lyrics.Reference.performanceFlagsDescription)
            .capoText(.px12).foregroundStyle(CapoTheme.mutedForeground).padding(.top, 4)
          ForEach(ReferenceData.flags.indices, id: \.self) { index in
            flag(ReferenceData.flags[index], isLast: index == ReferenceData.flags.count - 1)
          }
        }
        .padding(.horizontal, 16).padding(.bottom, 40)
      }
    }
    .background(CapoTheme.background)
  }

  private func heading(_ title: String) -> some View {
    HStack(spacing: 12) {
      Text(title).capoText(.px10, weight: .bold, tracking: 0.2).textCase(.uppercase)
        .foregroundStyle(CapoTheme.mutedForeground.opacity(0.7)).fixedSize()
      Rectangle().fill(CapoTheme.border).frame(height: 1)
    }
    .padding(.top, 28).padding(.bottom, 2)
    .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
  }

  private func codeChip(_ text: String, tint: Color) -> some View {
    Text(text).font(CapoFont.mono(12, weight: .semibold)).foregroundStyle(tint)
      .padding(.horizontal, 6).padding(.vertical, 2)
      .background(CapoTheme.muted.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
      .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(CapoTheme.border.opacity(0.5)))
  }

  private func directive(_ item: ReferenceDirective, isLast: Bool) -> some View {
    let tint = item.category == .formatting ? ReferenceTint.green : ReferenceTint.blue
    return VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        codeChip("{\(item.name)}", tint: tint)
        if let shorthand = item.shorthand {
          Text(L10n.Songs.Lyrics.Reference.shorthand).capoText(.px11)
            .foregroundStyle(CapoTheme.mutedForeground.opacity(0.6))
          codeChip("{\(shorthand)}", tint: tint)
        }
      }
      Text(item.summary).capoText(.px12).foregroundStyle(CapoTheme.mutedForeground)
      ExampleBlock(code: item.example)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) { if !isLast { Divider().overlay(CapoTheme.border) } }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func flag(_ item: ReferenceFlag, isLast: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      codeChip(item.flag, tint: ReferenceTint.green)
      Text(item.summary).capoText(.px12).foregroundStyle(CapoTheme.mutedForeground)
      ExampleBlock(code: item.example)
    }
    .padding(.vertical, 14)
    .overlay(alignment: .bottom) { if !isLast { Divider().overlay(CapoTheme.border) } }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Directive chip tints from the web (blue-600/300, green-700/400).
nonisolated enum ReferenceTint {
  static let blue = Color(
    uiColor: UIColor { $0.userInterfaceStyle == .dark ? EditorPalette.hex(0x93C5FD) : EditorPalette.hex(0x2563EB) })
  static let green = Color(
    uiColor: UIColor { $0.userInterfaceStyle == .dark ? EditorPalette.hex(0x4ADE80) : EditorPalette.hex(0x15803D) })
}

/// Read-only highlighted ChordPro sample with a copy button (web `CodeBlock`).
struct ExampleBlock: View {
  let code: String
  @State private var copied = false

  var body: some View {
    Text(Self.highlighted(code))
      .font(CapoFont.mono(12))
      .lineSpacing(5)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 10).padding(.horizontal, 12).padding(.trailing, 28)
      .background(Color(uiColor: EditorPalette.editorFill))
      .clipShape(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
          .strokeBorder(CapoTheme.border.opacity(0.5))
      )
      .overlay(alignment: .topTrailing) {
        Button {
          UIPasteboard.general.string = cleanReferenceExample(code)
          copied = true
          Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
          }
        } label: {
          CapoIcon(copied ? .check : .copy, size: 12)
            .foregroundStyle(copied ? Color.green : CapoTheme.mutedForeground)
            .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(L10n.Ios.Editor.copyExample)
      }
      .padding(.top, 2)
  }

  static func highlighted(_ code: String) -> AttributedString {
    var result = AttributedString(code)
    let ns = code as NSString
    for token in LyricsHighlighter.tokens(in: code) {
      guard let range = Range(token.range, in: code),
        let attributed = Range(range, in: result)
      else { continue }
      _ = ns
      switch token.kind {
      case .chord: result[attributed].foregroundColor = Color(uiColor: EditorPalette.chord)
      case .directive: result[attributed].foregroundColor = Color(uiColor: EditorPalette.directive)
      case .comment: result[attributed].foregroundColor = Color(uiColor: EditorPalette.comment)
      }
    }
    return result
  }
}
