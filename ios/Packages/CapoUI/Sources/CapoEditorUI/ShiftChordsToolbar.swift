import CapoDesign
import SwiftUI

/// "Shift chords" −1 / +1 semitone chips (web `song-editor-impl.tsx`).
struct ShiftChordsToolbar: View {
  let onShift: (Int) -> Void

  var body: some View {
    HStack(spacing: 6) {
      Text(L10n.Songs.Lyrics.shiftChords).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
        .padding(.trailing, 2)
      ForEach([-1, 1], id: \.self) { step in
        Button { onShift(step) } label: {
          Text("\(step > 0 ? "+1" : "−1") \(L10n.Songs.Lyrics.semitone)").capoText(.xs, weight: .medium)
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
        .accessibilityIdentifier("editor.shift.\(step > 0 ? "up" : "down")")
        .accessibilityHint(L10n.Songs.Lyrics.shiftChordsHint)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .background(CapoTheme.muted.opacity(0.3))
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
  }
}
