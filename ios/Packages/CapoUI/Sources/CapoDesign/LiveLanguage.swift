import Foundation
import Observation
import SwiftUI
import os

/// Which `.lproj` the generated `L10n` accessors read. Without an override the process language
/// (system or `AppleLanguages`) decides; an override switches strings at runtime, no relaunch.
public nonisolated enum L10nRuntime {
  private static let override = OSAllocatedUnfairLock<Bundle?>(initialState: nil)
  private static let token = LanguageToken()

  /// Reading this inside a SwiftUI body registers an Observation dependency, so every view that
  /// shows a localized string re-renders when `apply` changes the language (sheets stay open).
  public static var bundle: Bundle {
    _ = token.revision
    return override.withLock { $0 } ?? .module
  }

  /// The compiled lproj of the design bundle for `code` ("en", "es"), if it exists.
  public static func bundle(for code: String) -> Bundle? {
    Bundle.module.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:))
  }

  /// nil goes back to the process language.
  public static func apply(_ code: String?) {
    let resolved = code.flatMap { bundle(for: $0) }
    override.withLock { $0 = resolved }
    token.revision &+= 1
  }
}

@Observable
private nonisolated final class LanguageToken: @unchecked Sendable {
  var revision = 0
}

/// The in-app language choice; persisted, applied at launch and switchable live.
@Observable @MainActor
public final class AppLanguage {
  public static let shared = AppLanguage()
  public static let defaultsKey = "capo.language"

  /// nil follows the system language.
  public private(set) var code: String?
  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    code = defaults.string(forKey: Self.defaultsKey)
    L10nRuntime.apply(code)
  }

  public func set(_ newCode: String) {
    guard newCode != code else { return }
    code = newCode
    defaults.set(newCode, forKey: Self.defaultsKey)
    // Keeps system-provided text (date formats, alerts) in step on the next launch.
    defaults.set([newCode], forKey: "AppleLanguages")
    L10nRuntime.apply(newCode)
  }
}

private struct LiveLanguage: ViewModifier {
  func body(content: Content) -> some View {
    content
      .environment(\.locale, AppLanguage.shared.code.map(Locale.init(identifier:)) ?? .current)
  }
}

extension View {
  /// Apply once at the app root: date and number formatting follow the in-app language too.
  public func liveLanguage() -> some View { modifier(LiveLanguage()) }
}
