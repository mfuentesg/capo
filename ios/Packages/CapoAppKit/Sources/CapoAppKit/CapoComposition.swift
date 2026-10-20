import CapoCore
import CapoFakes
import CapoStore
import CapoSupabase
import CapoSync
import Foundation
import os

public enum CapoComposition {
  private static let logger = Logger(subsystem: "com.mfuentesg.capo", category: "composition")

  /// Demo mode when `config` is nil or the app was launched with `-CapoDemoMode YES`.
  public static func make(config: AppConfig?) -> AppDependencies {
    guard let config, !UserDefaults.standard.bool(forKey: "CapoDemoMode") else {
      logger.info("Starting in demo mode")
      return .demo
    }
    return makeLive(config: config)
  }

  /// Wave 2 (WP-INT) wires SupabaseAuthService, CapoDatabase and SyncEngine here.
  /// Until then the live path falls back to demo data.
  static func makeLive(config: AppConfig) -> AppDependencies {
    logger.notice(
      "Live composition not wired yet; falling back to demo (env: \(config.environmentName, privacy: .public))"
    )
    return .demo
  }
}
