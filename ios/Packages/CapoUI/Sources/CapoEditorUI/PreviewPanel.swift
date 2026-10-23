import CapoDesign
import CapoRendering
import SwiftUI

/// Live preview card: header with Chords/Lyrics toggle and the rendered song.
struct LivePreviewPanel: View {
  let rendered: RenderedSong
  @Binding var showChords: Bool
  var onCollapse: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(EditorStrings.livePreview.uppercased())
          .font(CapoFont.ui(13, weight: .bold))
          .tracking(1)
          .foregroundStyle(CapoTheme.subtext)
        Spacer()
        modeToggle
        if let onCollapse {
          Button(action: onCollapse) { Image(systemName: "chevron.right") }
            .buttonStyle(CapoIconButtonStyle())
            .accessibilityLabel(EditorStrings.hidePreview)
            .accessibilityIdentifier("editor.preview.collapse")
        }
      }
      ScrollView {
        ChordProContentView(rendered: rendered, style: style)
          .padding(.horizontal, 22).padding(.vertical, 20)
      }
      .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(CapoTheme.border, lineWidth: 1))
    }
  }

  private var style: SongRenderStyle {
    var style = SongRenderStyle()
    style.showChords = showChords
    return style
  }

  private var modeToggle: some View {
    HStack(spacing: 0) {
      segment(EditorStrings.chordsMode, selected: showChords) { showChords = true }
      segment(EditorStrings.lyrics, selected: !showChords) { showChords = false }
    }
    .padding(3)
    .background(CapoTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(CapoFont.ui(14, weight: .semibold))
        .foregroundStyle(selected ? CapoTheme.text : CapoTheme.subtext)
        .padding(.horizontal, 14).frame(minHeight: 36)
        .background(
          selected ? CapoTheme.card : Color.clear,
          in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Thin drag handle between the editor and the preview panel (iPad).
struct PreviewResizeHandle: View {
  @Binding var layout: PreviewPanelLayout
  let containerWidth: CGFloat
  @State private var dragStart: CGFloat?

  var body: some View {
    Rectangle()
      .fill(CapoTheme.border)
      .frame(width: 1)
      .overlay {
        Capsule().fill(CapoTheme.subtext.opacity(0.6)).frame(width: 4, height: 44)
      }
      .frame(width: 24)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 2)
          .onChanged { value in
            let start = dragStart ?? layout.resolvedWidth(containerWidth: containerWidth)
            dragStart = start
            layout.width = PreviewPanelLayout.clamp(
              start - value.translation.width, containerWidth: containerWidth)
          }
          .onEnded { _ in
            dragStart = nil
            layout.save()
          }
      )
      .accessibilityLabel(EditorStrings.resizePreview)
      .accessibilityAdjustableAction { direction in
        let step: CGFloat = direction == .increment ? -40 : 40
        layout.width = PreviewPanelLayout.clamp(
          layout.resolvedWidth(containerWidth: containerWidth) + step, containerWidth: containerWidth)
        layout.save()
      }
      .accessibilityIdentifier("editor.preview.handle")
  }
}
