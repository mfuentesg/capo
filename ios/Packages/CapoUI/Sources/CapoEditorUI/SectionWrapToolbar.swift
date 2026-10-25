import CapoDesign
import SwiftUI

/// "Wrap as" chips shown while text is selected (web `section-wrap-toolbar.tsx`).
struct SectionWrapToolbar: View {
  let onWrap: (SectionType) -> Void

  var body: some View {
    HStack(spacing: 6) {
      Text(L10n.Songs.Lyrics.wrapAs).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
        .padding(.trailing, 2)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(SectionType.all) { type in
            Button { onWrap(type) } label: {
              Text(type.label).capoText(.xs, weight: .medium)
                .foregroundStyle(CapoTheme.foreground)
                .padding(.horizontal, 10).frame(minHeight: 44)
                .background(
                  CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
                    .strokeBorder(CapoTheme.border)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("editor.wrap.\(type.key)")
          }
        }
      }
    }
    .padding(.horizontal, 12)
    .background(CapoTheme.muted.opacity(0.3))
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
    .transition(.move(edge: .top).combined(with: .opacity))
  }
}
