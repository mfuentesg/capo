import CapoDesign
import Foundation
import Testing
@testable import CapoShellUI

@MainActor
@Suite struct ContextStoreTests {
  private func defaults() -> UserDefaults {
    let suite = "capo.tests.\(UUID().uuidString)"
    return UserDefaults(suiteName: suite)!
  }

  private func team(_ n: Int, role: TeamRole = .member) -> TeamWithRole {
    let ts = ServerTimestamp("2026-01-01T00:00:00+00:00")
    let id = UUID(uuidString: "00000000-0000-4000-8000-00000000000\(n)")!
    return TeamWithRole(
      team: Team(id: id, name: "Team \(n)", icon: nil, avatarURL: nil, isPublic: false, createdBy: UUID(), createdAt: ts, updatedAt: ts),
      role: role)
  }

  @Test func selectionPersistsPerUser() {
    let d = defaults()
    let user = UUID()
    let t = team(1, role: .admin)
    let a = ContextStore(userID: user, defaults: d)
    a.update(teams: [t])
    a.select(.team(teamID: t.id))
    #expect(a.role == .admin)

    let b = ContextStore(userID: user, defaults: d)
    b.update(teams: [t])
    #expect(b.context == .team(teamID: t.id))

    let other = ContextStore(userID: UUID(), defaults: d)
    other.update(teams: [t])
    #expect(other.context.teamID == nil)
  }

  @Test func removedTeamFallsBackToPersonal() {
    let d = defaults()
    let user = UUID()
    let t = team(2)
    let store = ContextStore(userID: user, defaults: d)
    store.update(teams: [t])
    store.select(.team(teamID: t.id))
    store.update(teams: [])
    #expect(store.context == .personal(userID: user))
    #expect(d.string(forKey: ContextStore.key(for: user)) == nil)
  }

  @Test func personalHasNoRole() {
    let store = ContextStore(userID: UUID(), defaults: defaults())
    #expect(store.role == nil)
  }
}

@MainActor
@Suite struct SessionStoreTests {
  @Test func signUpOnlyOutsideProduction() {
    #expect(SessionStore.allowsSignUp(environmentName: "local", isDemo: false))
    #expect(!SessionStore.allowsSignUp(environmentName: "production", isDemo: false))
    #expect(!SessionStore.allowsSignUp(environmentName: nil, isDemo: false))
    #expect(SessionStore.allowsSignUp(environmentName: nil, isDemo: true))
  }

  @Test func demoSessionBecomesReadyThenSignsOut() async throws {
    let store = SessionStore(dependencies: DemoSupport.dependencies)
    let session = try #require(await store.dependencies.auth.currentSession())
    await store.handle(session)
    guard case .ready(let active) = store.phase else { Issue.record("expected ready"); return }
    #expect(active.session.userID == session.userID)

    await store.handle(nil)
    guard case .signedOut = store.phase else { Issue.record("expected signedOut"); return }
  }

  @Test func contextSwitchResetsSelections() async throws {
    let deps = DemoSupport.dependencies
    let session = try #require(await deps.auth.currentSession())
    let services = try await deps.makeUserServices(session)
    let model = ShellModel(session: session, services: services, defaults: UserDefaults(suiteName: "capo.tests.\(UUID())")!)
    model.navigation.songSelection = UUID()
    let teamID = UUID()
    model.select(.team(teamID: teamID))
    #expect(model.navigation.songSelection == nil)
    #expect(model.context == .team(teamID: teamID))
  }

  @Test func switchingContextRescopesLibraryStream() async throws {
    let deps = DemoSupport.dependencies
    let session = try #require(await deps.auth.currentSession())
    let services = try await deps.makeUserServices(session)
    func first(_ context: AppContext) async -> [SongListItem] {
      for await items in services.songs.songs(SongQuery(context: context)) { return items }
      return []
    }
    let personal = await first(.personal(userID: session.userID))
    let team = await first(.team(teamID: UUID(uuidString: "00000000-0000-4000-8000-0000000000B1")!))
    #expect(!personal.isEmpty)
    #expect(personal.allSatisfy { $0.teamID == nil })
    #expect(team.allSatisfy { $0.teamID != nil })
    #expect(Set(personal.map(\.id)).isDisjoint(with: Set(team.map(\.id))))
  }
}
