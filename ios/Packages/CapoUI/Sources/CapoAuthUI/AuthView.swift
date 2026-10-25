import CapoDesign
import SwiftUI

/// Signed-out screen, laid out like the web login: Google and Apple (outline buttons), an
/// uppercase divider, then email/password. Sign-up appears only when the shell allows it
/// (`AuthActions.allowsSignUp`, i.e. environment != production).
public struct AuthView: View {
  @Environment(\.authActions) private var actions
  @State private var model = AuthFormModel()
  @FocusState private var focus: Field?

  private enum Field { case email, password }

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        header
        VStack(spacing: 16) {
          googleButton
          appleButton
          devSessionButton
          divider
          form
        }
        .frame(maxWidth: 420)
      }
      .padding(24)
      .frame(maxWidth: .infinity)
    }
    .scrollBounceBehavior(.basedOnSize)
    .scrollDismissesKeyboard(.interactively)
    .capoTheme()
    .capoToast($model.errorMessage)
  }

  private var header: some View {
    VStack(spacing: 10) {
      Image(systemName: "music.note")
        .font(CapoFont.ui(34, weight: .bold))
        .foregroundStyle(CapoTheme.onPrimary)
        .frame(width: 76, height: 76)
        .background(CapoTheme.primary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 32)
        .accessibilityHidden(true)
      Text("Capo")
        .font(CapoFont.style(.largeTitle, weight: .bold))
      Text(L10n.Auth.tagline)
        .font(CapoFont.style(.subheadline))
        .foregroundStyle(CapoTheme.subtext)
        .multilineTextAlignment(.center)
    }
  }

  private var googleButton: some View {
    Button {
      Task { await model.signInWithGoogle(with: actions) }
    } label: {
      HStack(spacing: 12) {
        Text("G").font(CapoFont.ui(17, weight: .bold)).accessibilityHidden(true)
        Text(model.isBusy ? L10n.Auth.loggingIn : L10n.Auth.loginWith(provider: L10n.Common.google))
          .font(CapoFont.style(.headline))
      }
      .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget)
    }
    .buttonStyle(CapoSecondaryButtonStyle())
    .disabled(model.isBusy)
  }

  /// Apple's guideline: same prominence as the other providers, the system logo, never smaller.
  private var appleButton: some View {
    Button {
      Task { await model.signInWithApple(with: actions) }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "applelogo").font(CapoFont.ui(17, weight: .semibold)).accessibilityHidden(true)
        Text(L10n.Auth.loginWith(provider: "Apple")).font(CapoFont.style(.headline))
      }
      .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget)
    }
    .buttonStyle(CapoSecondaryButtonStyle())
    .disabled(model.isBusy)
  }

  @ViewBuilder private var devSessionButton: some View {
    if let devSignIn = actions.devSignIn {
      // DEBUG builds only (the closure is nil in Release). Plain English on purpose: not user-facing.
      Button {
        Task { await model.run { try await devSignIn() } }
      } label: {
        Label("Use dev session (local)", systemImage: "hammer")
          .font(CapoFont.style(.headline))
          .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget)
      }
      .buttonStyle(CapoSecondaryButtonStyle())
      .disabled(model.isBusy)
    }
  }

  private var divider: some View {
    HStack {
      Rectangle().fill(.separator).frame(height: 1)
      Text(L10n.Auth.orContinueWith.uppercased())
        .font(CapoFont.style(.caption2, weight: .medium))
        .tracking(0.8)
        .foregroundStyle(CapoTheme.subtext)
      Rectangle().fill(.separator).frame(height: 1)
    }
  }

  private var form: some View {
    VStack(spacing: 12) {
      TextField(
        L10n.Ios.Auth.email,
        text: $model.email
      )
      .textContentType(.emailAddress)
      .keyboardType(.emailAddress)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .submitLabel(.next)
      .focused($focus, equals: .email)
      .onSubmit { focus = .password }
      .fieldStyle()

      SecureField(
        L10n.Ios.Auth.password,
        text: $model.password
      )
      .textContentType(model.mode == .signUp ? .newPassword : .password)
      .submitLabel(.go)
      .focused($focus, equals: .password)
      .onSubmit { submit() }
      .fieldStyle()

      Button(action: submit) {
        Group {
          if model.isBusy {
            ProgressView()
          } else {
            Text(
              model.mode == .signIn
                ? L10n.Ios.Auth.signIn
                : L10n.Ios.Auth.signUp
            )
            .font(CapoFont.style(.headline))
          }
        }
        .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget)
      }
      .buttonStyle(CapoPrimaryButtonStyle())
      .disabled(!model.canSubmit)

      if actions.allowsSignUp {
        Button(action: model.toggleMode) {
          Text(
            model.mode == .signIn
              ? L10n.Ios.Auth.toSignUp
              : L10n.Ios.Auth.toSignIn
          )
          .font(CapoFont.style(.subheadline))
          .frame(minHeight: CapoMetrics.minTouchTarget)
        }
      }
    }
  }

  private func submit() {
    focus = nil
    Task { await model.submit(with: actions) }
  }
}

private extension View {
  func fieldStyle() -> some View {
    padding(.horizontal, 14)
      .frame(minHeight: CapoMetrics.minTouchTarget)
      .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous).strokeBorder(CapoTheme.border, lineWidth: 1))
  }
}
