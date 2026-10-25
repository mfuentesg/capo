import CapoCore
import Foundation
import Supabase

public enum SupabaseClientFactory {
  /// PKCE auth redirecting to `config.authCallbackURL`; the session lives in the default Keychain
  /// storage and is emitted locally first so offline cold starts restore it without the network.
  public static func make(config: AppConfig, session: URLSession = .shared) -> SupabaseClient {
    SupabaseClient(
      supabaseURL: config.supabaseURL,
      supabaseKey: config.supabaseKey,
      options: SupabaseClientOptions(
        auth: .init(
          redirectToURL: config.authCallbackURL,
          flowType: .pkce,
          emitLocalSessionAsInitialSession: true
        ),
        global: .init(session: session)
      )
    )
  }
}
