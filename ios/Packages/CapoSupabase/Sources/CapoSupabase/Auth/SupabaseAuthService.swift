import CapoCore
import Foundation
import Supabase

#if canImport(AuthenticationServices)
  import AuthenticationServices
#endif

public final class SupabaseAuthService: AuthService {
  private let client: SupabaseClient
  private let callbackURL: URL

  public init(client: SupabaseClient, callbackURL: URL) {
    self.client = client
    self.callbackURL = callbackURL
  }

  /// First element is the locally stored session, read synchronously from storage so an expired
  /// session on an offline device still restores. Later elements follow auth state changes; the
  /// SDK's own `initialSession` event is skipped because it may reflect a failed refresh.
  public func sessionStream() -> AsyncStream<AuthSession?> {
    let auth = client.auth
    let (stream, continuation) = AsyncStream<AuthSession?>.makeStream(bufferingPolicy: .unbounded)
    let initial = auth.currentSession.map(Self.map)
    continuation.yield(initial)

    let task = Task {
      var last = initial
      for await change in auth.authStateChanges {
        if change.event == .initialSession { continue }
        let mapped = change.session.map(Self.map)
        if mapped == last { continue }
        last = mapped
        continuation.yield(mapped)
      }
      continuation.finish()
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
  }

  /// Local, offline-safe: the stored session even if its access token has expired.
  public func currentSession() async -> AuthSession? {
    client.auth.currentSession.map(Self.map)
  }

  /// Google OAuth with PKCE through `ASWebAuthenticationSession`. A user-cancelled web sheet
  /// surfaces as `CancellationError`.
  public func signInWithGoogle() async throws {
    do {
      try await client.auth.signInWithOAuth(provider: .google, redirectTo: callbackURL)
    } catch {
      #if canImport(AuthenticationServices)
        if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
          throw CancellationError()
        }
      #endif
      throw error
    }
  }

  public func signIn(email: String, password: String) async throws {
    try await client.auth.signIn(email: email, password: password)
  }

  public func signUp(email: String, password: String) async throws {
    try await client.auth.signUp(email: email, password: password)
  }

  /// Local scope so signing out works offline; the refresh token is simply discarded.
  public func signOut() async throws {
    do {
      try await client.auth.signOut(scope: .local)
    } catch {
      // The SDK drops the local session before calling /logout; a network failure after that
      // still leaves the device signed out.
      if client.auth.currentSession != nil { throw error }
    }
  }

  /// Handles `capo://auth/callback?code=…`; returns false for any other URL or a failed exchange.
  public func handleOpenURL(_ url: URL) async -> Bool {
    guard Self.matches(url, callback: callbackURL) else { return false }
    do {
      try await client.auth.session(from: url)
      return true
    } catch {
      return false
    }
  }

  static func matches(_ url: URL, callback: URL) -> Bool {
    url.scheme?.lowercased() == callback.scheme?.lowercased()
      && url.host?.lowercased() == callback.host?.lowercased()
      && url.path == callback.path
  }

  static func map(_ session: Session) -> AuthSession {
    let user = session.user
    let metadata = user.userMetadata
    let name = metadata["full_name"]?.stringValue ?? metadata["name"]?.stringValue
    let avatar = (metadata["avatar_url"]?.stringValue ?? metadata["picture"]?.stringValue)
      .flatMap(URL.init(string:))
    return AuthSession(
      userID: user.id, email: user.email, fullName: name, avatarURL: avatar,
      provider: user.appMetadata["provider"]?.stringValue)
  }
}
