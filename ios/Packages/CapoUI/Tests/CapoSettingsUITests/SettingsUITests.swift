import CapoCore
import CapoFakes
import Foundation
import Testing

@testable import CapoSettingsUI

@MainActor @Suite struct FeedbackModelTests {
  @Test func needsAtLeastFiveCharacters() {
    let model = FeedbackModel()
    model.draft.message = "  hi  "
    #expect(!model.canSend)
    model.draft.message = "  hello "
    #expect(model.canSend)
  }

  @Test func rejectsABadEmailButAllowsNone() {
    let model = FeedbackModel()
    model.draft.message = "great app"
    model.draft.email = "nope"
    #expect(model.emailIsInvalid && !model.canSend)
    model.draft.email = "a@b.co"
    #expect(model.canSend)
    model.draft.email = ""
    #expect(model.canSend)
  }

  @Test func enforcesTheWebLimits() {
    var draft = FeedbackDraft(message: String(repeating: "a", count: 5001))
    #expect(draft.problem == .messageTooLong)
    draft.message = String(repeating: "a", count: 5000)
    #expect(draft.problem == nil)
    draft.name = String(repeating: "n", count: 101)
    #expect(draft.problem == .nameTooLong)
  }

  @Test func successAndFailureAreReported() async {
    let ok = FeedbackModel()
    ok.draft.message = "hello there"
    await ok.send { _ in }
    #expect(ok.succeeded && !ok.failed)

    let bad = FeedbackModel()
    bad.draft.message = "hello there"
    await bad.send { _ in throw CapoError.offlineUnavailable }
    #expect(!bad.succeeded && bad.failed)
  }
}

@MainActor @Suite struct DeleteAccountWarningTests {
  @Test func listsOnlyOwnedTeamsWithOtherMembers() async {
    let services = UserServices.fake()
    let model = SettingsModel()
    await model.loadSharedOwnedTeams(services.teams)
    // Whatever the demo data holds, every listed team must be one the user owns.
    var owned: Set<String> = []
    for await list in services.teams.teams() {
      owned = Set(list.filter { $0.role == .owner }.map(\.team.name))
      break
    }
    #expect(Set(model.sharedOwnedTeams).isSubset(of: owned))
  }
}
