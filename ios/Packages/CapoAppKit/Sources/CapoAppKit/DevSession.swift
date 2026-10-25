#if DEBUG
  import Foundation
  import Supabase
  import os

  /// DEBUG-only: a session minted by `ios/scripts/mint-dev-session.sh` for the LOCAL stack, bundled as
  /// the git-ignored `DevSession.plist`. Lets the simulator and devices sign in without the Google
  /// browser step. Release builds compile this file out entirely.
  nonisolated struct DevSession: Sendable {
    let accessToken: String
    let refreshToken: String

    static let fileName = "DevSession"
    private static let logger = Logger(subsystem: "com.mfuentesg.capo", category: "dev-session")

    static func load(from bundle: Bundle) -> DevSession? {
      guard let url = bundle.url(forResource: fileName, withExtension: "plist"),
        let data = try? Data(contentsOf: url),
        let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
          as? [String: Any],
        let access = plist["ACCESS_TOKEN"] as? String, !access.isEmpty,
        let refresh = plist["REFRESH_TOKEN"] as? String, !refresh.isEmpty
      else { return nil }
      return DevSession(accessToken: access, refreshToken: refresh)
    }

    enum Failure: LocalizedError {
      case notBundled
      case rejected(String)
      var errorDescription: String? {
        switch self {
        case .notBundled: return "No DevSession.plist is bundled in this build."
        case .rejected(let reason): return "Dev session rejected: \(reason)"
        }
      }
    }

    /// Signs in with the bundled session, throwing a readable error. Used by the "Use dev session"
    /// button on the sign-in screen and by `applyIfPresent`.
    static func signIn(client: SupabaseClient, bundle: Bundle = .main) async throws {
      guard let session = load(from: bundle) else { throw Failure.notBundled }
      do {
        _ = try await client.auth.setSession(
          accessToken: session.accessToken, refreshToken: session.refreshToken)
        logger.notice("Signed in with the bundled dev session")
      } catch {
        logger.error("Dev session rejected: \(error.localizedDescription, privacy: .public)")
        throw Failure.rejected(error.localizedDescription)
      }
    }

    private static let appliedKey = "CapoDevSession.appliedRefreshToken"

    /// Applies the bundled session when this build carries a session
    /// that has not been applied on this device before (each `mint-dev-session.sh` run is applied
    /// once), or always with `-CapoDevSession YES`. Refresh tokens rotate, so after the first use
    /// the Keychain session takes over; reusing a spent token would revoke the whole family.
    static func applyIfPresent(to client: SupabaseClient, bundle: Bundle = .main) {
      guard let session = load(from: bundle) else { return }
      let defaults = UserDefaults.standard
      let force = defaults.bool(forKey: "CapoDevSession")
      let isNew = defaults.string(forKey: appliedKey) != session.refreshToken
      // A spent token is never retried automatically (reuse would revoke the session family);
      // after re-minting, or with the sign-in button, it applies again.
      guard force || isNew else { return }
      defaults.set(session.refreshToken, forKey: appliedKey)
      Task { try? await signIn(client: client, bundle: bundle) }
    }
  }
#endif
