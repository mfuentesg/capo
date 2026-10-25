import Foundation
import Testing

@testable import CapoDesign

@MainActor @Suite(.serialized) struct LiveLanguageTests {
  private func freshDefaults() -> UserDefaults {
    let name = "capo.live-language.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
  }

  @Test func stringsSwitchWithoutRelaunch() {
    defer { L10nRuntime.apply(nil) }
    L10nRuntime.apply("en")
    let english = L10n.Common.cancel
    L10nRuntime.apply("es")
    let spanish = L10n.Common.cancel
    #expect(english == "Cancel")
    #expect(spanish == "Cancelar")
  }

  @Test func choiceIsPersistedAndReappliedOnNextLaunch() {
    defer { L10nRuntime.apply(nil) }
    let defaults = freshDefaults()
    AppLanguage(defaults: defaults).set("es")
    #expect(defaults.string(forKey: AppLanguage.defaultsKey) == "es")
    L10nRuntime.apply(nil)
    let relaunched = AppLanguage(defaults: defaults)
    #expect(relaunched.code == "es")
    #expect(L10n.Common.cancel == "Cancelar")
  }

  @Test func unknownLanguageFallsBackToTheProcessLanguage() {
    defer { L10nRuntime.apply(nil) }
    L10nRuntime.apply("xx")
    #expect(!L10n.Common.cancel.isEmpty)
  }
}
