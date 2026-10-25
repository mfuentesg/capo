import CapoCore
import CapoDesign
import Observation
import SwiftUI

/// Form state for the feedback sheet; free of SwiftUI so it can be unit tested.
@Observable @MainActor
final class FeedbackModel {
  var draft = FeedbackDraft()
  private(set) var isSending = false
  private(set) var succeeded = false
  var failed = false

  var canSend: Bool { draft.problem == nil && !isSending }
  var emailIsInvalid: Bool { draft.problem == .invalidEmail }

  func send(_ submit: @Sendable (FeedbackDraft) async throws -> Void) async {
    guard canSend else { return }
    isSending = true
    failed = false
    defer { isSending = false }
    do {
      try await submit(draft)
      succeeded = true
    } catch {
      failed = true
    }
  }
}

/// The web's feedback form (`features/feedback/components/feedback-form.tsx`), same fields and copy.
struct FeedbackView: View {
  let submit: @Sendable (FeedbackDraft) async throws -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.capoUIScale) private var scale
  @State private var model = FeedbackModel()

  var body: some View {
    NavigationStack {
      Group {
        if model.succeeded { success } else { form }
      }
      .background(CapoTheme.background)
      .navigationTitle(L10n.Landing.Feedback.headline)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(L10n.Common.close) { dismiss() }
        }
      }
    }
    .capoTheme()
    .tint(CapoTheme.primary)
  }

  private var form: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20 * scale) {
        Text(L10n.Landing.Feedback.description)
          .capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
        field(L10n.Landing.Feedback.nameLabel) {
          TextField(L10n.Landing.Feedback.namePlaceholder, text: $model.draft.name)
            .textContentType(.name)
            .fieldChrome(invalid: false)
        }
        field(L10n.Landing.Feedback.emailLabel) {
          TextField(L10n.Landing.Feedback.emailPlaceholder, text: $model.draft.email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .fieldChrome(invalid: model.emailIsInvalid)
        }
        field(L10n.Landing.Feedback.messageLabel) {
          TextField(
            L10n.Landing.Feedback.messagePlaceholder, text: $model.draft.message, axis: .vertical
          )
          .lineLimit(5...10)
          .fieldChrome(invalid: false)
        }
        Toggle(isOn: $model.draft.newsletterOptIn) {
          Text(L10n.Landing.Feedback.newsletterLabel)
            .capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
        }
        .tint(CapoTheme.primary)
        if model.failed {
          Text(L10n.Landing.Feedback.errorMessage)
            .capoText(.sm).foregroundStyle(CapoTheme.destructive)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CapoTheme.destructive.opacity(0.08), in: RoundedRectangle(cornerRadius: CapoRadius.md))
        }
        Button {
          Task { await model.send(submit) }
        } label: {
          Text(model.isSending ? L10n.Landing.Feedback.submitting : L10n.Landing.Feedback.submit)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CapoPrimaryButtonStyle())
        .disabled(!model.canSend)
      }
      .padding(20 * scale)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
  }

  private var success: some View {
    VStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(.green)
        .accessibilityHidden(true)
      Text(L10n.Landing.Feedback.successTitle).capoText(.lg, weight: .semibold)
      Text(L10n.Landing.Feedback.successDescription)
        .capoText(.sm).foregroundStyle(CapoTheme.mutedForeground).multilineTextAlignment(.center)
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6 * scale) {
      Text(label).capoText(.sm, weight: .medium)
      content()
    }
  }
}

private extension View {
  func fieldChrome(invalid: Bool) -> some View {
    padding(.horizontal, 12)
      .frame(minHeight: 44, alignment: .leading)
      .background(CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
          .strokeBorder(invalid ? CapoTheme.destructive : CapoTheme.input, lineWidth: 1))
  }
}
