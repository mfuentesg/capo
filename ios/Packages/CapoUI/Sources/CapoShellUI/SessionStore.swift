import CapoDesign
import Foundation
import Observation

/// Owns the signed-in lifecycle: restores the session, builds `UserServices`, starts sync and
/// tears everything down on sign-out.
@Observable
@MainActor
final class SessionStore {
  struct Active {
    let session: AuthSession
    let services: UserServices
  }

  enum Phase {
    case loading
    case signedOut
    case ready(Active)
    case failed(String)
  }

  let dependencies: AppDependencies
  private(set) var phase: Phase = .loading
  var errorMessage: String?
  private var eraseOnNextTearDown = false

  init(dependencies: AppDependencies) {
    self.dependencies = dependencies
  }

  var authActions: AuthActions {
    let auth = dependencies.auth
    let environment = dependencies.config?.environmentName
    return AuthActions(
      signInWithGoogle: { try await auth.signInWithGoogle() },
      signIn: { try await auth.signIn(email: $0, password: $1) },
      signUp: { try await auth.signUp(email: $0, password: $1) },
      allowsSignUp: Self.allowsSignUp(environmentName: environment, isDemo: dependencies.isDemo))
  }

  static func allowsSignUp(environmentName: String?, isDemo: Bool) -> Bool {
    isDemo || (environmentName ?? "production") != "production"
  }

  /// Drives the store until cancelled; the first element is the restored (offline-safe) session.
  func run() async {
    for await session in dependencies.auth.sessionStream() {
      if Task.isCancelled { return }
      await handle(session)
    }
  }

  func retry() async {
    await handle(await dependencies.auth.currentSession())
  }

  func signOut(erase: Bool) async {
    eraseOnNextTearDown = erase
    do {
      try await dependencies.auth.signOut()
    } catch {
      eraseOnNextTearDown = false
      errorMessage = error.localizedDescription
    }
  }

  func handle(_ session: AuthSession?) async {
    if case .ready(let active) = phase {
      if let session, session.userID == active.session.userID {
        if session != active.session { phase = .ready(Active(session: session, services: active.services)) }
        return
      }
      await tearDown(active)
    }
    guard let session else {
      phase = .signedOut
      return
    }
    phase = .loading
    do {
      let services = try await dependencies.makeUserServices(session)
      phase = .ready(Active(session: session, services: services))
      Task {
        await services.sync.start()
        await services.sync.syncNow(reason: .appLaunch)
      }
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  private func tearDown(_ active: Active) async {
    let erase = eraseOnNextTearDown
    eraseOnNextTearDown = false
    await active.services.sync.stop()
    await active.services.tearDown(erase)
  }
}
