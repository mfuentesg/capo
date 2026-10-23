import SwiftUI

/// Transient error/info banner. Bind a message; it clears itself after `duration`.
private struct ToastModifier: ViewModifier {
  @Binding var message: String?
  let duration: Duration

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottom) {
        if let message {
          Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(CapoFont.style(.subheadline, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red.gradient, in: Capsule())
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
