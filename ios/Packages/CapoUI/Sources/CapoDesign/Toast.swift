import SwiftUI

/// Transient error/info banner, bottom-center like the web's sonner toasts. Bind a message; it clears itself after `duration`.
private struct ToastModifier: ViewModifier {
  @Binding var message: String?
  let duration: Duration

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if let message {
          // sonner: bottom-center, background + border + shadow-lg, 356pt wide at most.
          Label {
            Text(message).foregroundStyle(CapoTheme.foreground)
          } icon: {
            Image(systemName: "exclamationmark.circle").foregroundStyle(CapoTheme.destructive)
          }
          .font(CapoFont.web(.sm, weight: .medium))
          .padding(16)
          .frame(maxWidth: 356, alignment: .leading)
          .background(
            CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
          )
          .overlay(
            RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
              .strokeBorder(CapoTheme.border, lineWidth: 1)
          )
          .shadow(color: .black.opacity(0.1), radius: 8, y: 6)
          .padding(.bottom, 24)
          .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
            .onTapGesture { self.message = nil }
        }
      }
      .animation(.snappy, value: message)
      .task(id: message) {
        guard message != nil else { return }
        try? await Task.sleep(for: duration)
        if !Task.isCancelled { message = nil }
      }
  }
}

extension View {
  public func capoToast(_ message: Binding<String?>, duration: Duration = .seconds(4)) -> some View {
    modifier(ToastModifier(message: message, duration: duration))
  }
}
