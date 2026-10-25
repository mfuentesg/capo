import CapoDesign
import Testing
@testable import CapoAuthUI

@MainActor
@Suite struct AuthFormModelTests {
  @Test func emailValidation() {
    let model = AuthFormModel()
    for bad in ["", "a", "a@b", "a@.com", "@b.com", "a b@c.com", "a@b@c.com"] {
      model.email = bad
      #expect(!model.isEmailValid, "\(bad)")
    }
    model.email = " ana@capo.app "
    #expect(model.isEmailValid)
    #expect(model.trimmedEmail == "ana@capo.app")
  }

  @Test func signUpNeedsLongerPassword() {
    let model = AuthFormModel()
    model.email = "a@b.co"
    model.password = "123"
    #expect(model.canSubmit)
    model.toggleMode()
    #expect(!model.canSubmit)
    model.password = "123456"
    #expect(model.canSubmit)
  }

  @Test func signInCallsActionWithTrimmedEmail() async {
    let model = AuthFormModel()
    model.email = " a@b.co "
    model.password = "pw"
    let box = Box()
    let actions = AuthActions(signIn: { email, password in await box.set("\(email)|\(password)") })
    await model.submit(with: actions)
    #expect(await box.value == "a@b.co|pw")
    #expect(model.errorMessage == nil)
    #expect(!model.isBusy)
  }

  @Test func failureSurfacesMessage() async {
    let model = AuthFormModel()
    model.email = "a@b.co"
    model.password = "pw"
    let actions = AuthActions(signIn: { _, _ in throw CapoError.offlineUnavailable })
    await model.submit(with: actions)
    #expect(model.errorMessage != nil)
  }

  @Test func signUpBlockedWhenNotAllowed() async {
    let model = AuthFormModel()
    model.email = "a@b.co"
    model.password = "123456"
    model.toggleMode()
    let box = Box()
    let actions = AuthActions(signUp: { _, _ in await box.set("called") }, allowsSignUp: false)
    await model.submit(with: actions)
    #expect(await box.value == nil)
    #expect(model.errorMessage != nil)
  }

  @Test func cancellationIsSilent() async {
    let model = AuthFormModel()
    let actions = AuthActions(signInWithGoogle: { throw CancellationError() })
    await model.signInWithGoogle(with: actions)
    #expect(model.errorMessage == nil)
  }
}

@MainActor @Suite struct AppleSignInTests {
  @Test func appleSignInRunsTheAction() async {
    let box = Box()
    let model = AuthFormModel()
    await model.signInWithApple(with: AuthActions(signInWithApple: { await box.set("apple") }))
    #expect(await box.value == "apple")
    #expect(model.errorMessage == nil)
  }

  @Test func cancellingTheAppleSheetIsSilent() async {
    let model = AuthFormModel()
    await model.signInWithApple(with: AuthActions(signInWithApple: { throw CancellationError() }))
    #expect(model.errorMessage == nil)
  }

  @Test func appleFailuresAreShown() async {
    let model = AuthFormModel()
    await model.signInWithApple(with: AuthActions(signInWithApple: { throw CapoError.offlineUnavailable }))
    #expect(model.errorMessage != nil)
  }
}

private actor Box {
  var value: String?
  func set(_ v: String) { value = v }
}
