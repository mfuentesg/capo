import CapoDesign
import SwiftUI

/// Signed-out screen: Google plus email/password. Sign-up appears only when the shell allows it
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
    .background(Color(.systemGroupedBackground).ignoresSafeArea())
    .capoToast($model.errorMessage)
  }

  private var header: some View {
    VStack(spacing: 10) {
      Image(systemName: "guitars.fill")
        .font(.system(size: 52))
        .foregroundStyle(.tint)
        .padding(.top, 32)
        .accessibilityHidden(true)
      Text("Capo")
        .font(.largeTitle.bold())
      Text(String(localized: "ios.auth.tagline", defaultValue: "Your songs and setlists, ready on stage.", bundle: .capoDesign))  // TODO(i18n)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  private var googleButton: some View {
    Button {
      Task { await model.signInWithGoogle(with: actions) }
    } label: {
      Label(
        String(localized: "ios.auth.google", defaultValue: "Continue with Google", bundle: .capoDesign),  // TODO(i18n)
        systemImage: "globe"
      )
      .font(.headline)
      .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget)
    }
    .buttonStyle(.borderedProminent)
    .disabled(model.isBusy)
  }

  private var divider: some View {
    HStack {
      Rectangle().fill(.separator).frame(height: 1)
      Text(String(localized: "ios.auth.or", defaultValue: "or", bundle: .capoDesign))  // TODO(i18n)
        .font(.footnote)
        .foregroundStyle(.secondary)
      Rectangle().fill(.separator).frame(height: 1)
    }
  }

  private var form: some View {
    VStack(spacing: 12) {
      TextField(
        String(localized: "ios.auth.email", defaultValue: "Email", bundle: .capoDesign),  // TODO(i18n)
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
        String(localized: "ios.auth.password", defaultValue: "Password", bundle: .capoDesign),  // TODO(i18n)
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
                ? String(localized: "ios.auth.signIn", defaultValue: "Sign in", bundle: .capoDesign)  // TODO(i18n)
                : String(localized: "ios.auth.signUp", defaultValue: "Create account", bundle: .capoDesign)  // TODO(i18n)
            )
            .font(.headline)
          }
        }
        .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget)
      }
      .buttonStyle(.bordered)
      .disabled(!model.canSubmit)

      if actions.allowsSignUp {
        Button(action: model.toggleMode) {
          Text(
            model.mode == .signIn
              ? String(localized: "ios.auth.toSignUp", defaultValue: "No account? Create one", bundle: .capoDesign)  // TODO(i18n)
              : String(localized: "ios.auth.toSignIn", defaultValue: "Have an account? Sign in", bundle: .capoDesign)  // TODO(i18n)
          )
          .font(.subheadline)
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
      .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: CapoMetrics.cornerRadius, style: .continuous))
  }
}
