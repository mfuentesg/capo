import CapoDesign
import CapoIcons
import CapoSettingsUI
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
    #expect(other.context == .all(userID: other.userID))
  }

  @Test func defaultsToAllAndPersistsPersonalChoice() {
    let d = defaults()
    let user = UUID()
    let a = ContextStore(userID: user, defaults: d)
    #expect(a.context == .all(userID: user))
    a.selectPersonal()
    #expect(ContextStore(userID: user, defaults: d).context == .personal(userID: user))
    a.selectAll()
    #expect(ContextStore(userID: user, defaults: d).context == .all(userID: user))
    #expect(d.string(forKey: ContextStore.key(for: user)) == nil)
  }

  @Test func removedTeamFallsBackToAll() {
    let d = defaults()
    let user = UUID()
    let t = team(2)
    let store = ContextStore(userID: user, defaults: d)
    store.update(teams: [t])
    store.select(.team(teamID: t.id))
    store.update(teams: [])
    #expect(store.context == .all(userID: user))
    #expect(d.string(forKey: ContextStore.key(for: user)) == nil)
  }

  @Test func creationContextSurvivesSwitchingToAll() {
    let d = defaults()
    let user = UUID()
    let t = team(3)
    let store = ContextStore(userID: user, defaults: d)
    #expect(store.creationContext == .personal(userID: user))
    store.update(teams: [t])
    store.select(.team(teamID: t.id))
    store.selectAll()
    #expect(store.context == .all(userID: user))
    #expect(store.creationContext == .team(teamID: t.id))

    let relaunched = ContextStore(userID: user, defaults: d)
    #expect(relaunched.context == .all(userID: user))
    #expect(relaunched.creationContext == .team(teamID: t.id))
    relaunched.selectPersonal()
    #expect(relaunched.creationContext == .personal(userID: user))
  }

  @Test func creationContextIsTheStoredTeamBeforeTeamsLoad() {
    let d = defaults()
    let user = UUID()
    let t = team(4)
    let first = ContextStore(userID: user, defaults: d)
    first.update(teams: [t])
    first.select(.team(teamID: t.id))
    let cold = ContextStore(userID: user, defaults: d)
    #expect(cold.context == .all(userID: user))  // team not confirmed yet
    #expect(cold.creationContext == .team(teamID: t.id))
    cold.update(teams: [])
    #expect(cold.creationContext == .personal(userID: user))
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
    model.navigation.songPath = [UUID()]
    let teamID = UUID()
    model.select(.team(teamID: teamID))
    #expect(model.navigation.songPath.isEmpty)
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

@MainActor
@Suite struct ShellSettingsTests {
  private func make(allow: Bool, delete: (@Sendable () async throws -> Void)?) async throws -> SettingsContext {
    let deps = DemoSupport.dependencies
    let session = try #require(await deps.auth.currentSession())
    var services = try await deps.makeUserServices(session)
    services.deleteAccount = delete
    return ShellSettings.context(
      session: session, services: services, config: nil, isDemo: true,
      allowsAccountDeletion: allow, signOut: { _ in })
  }

  @Test func deleteAccountIsHiddenUnlessAllowedAndAvailable() async throws {
    #expect(try await make(allow: false, delete: {}).deleteAccount == nil)
    #expect(try await make(allow: true, delete: nil).deleteAccount == nil)
    #expect(try await make(allow: true, delete: {}).deleteAccount != nil)
  }

  @Test func allowedDeleteInvokesTheServiceClosureOnly() async throws {
    final class Calls: @unchecked Sendable { var count = 0 }
    let calls = Calls()
    let context = try await make(allow: true, delete: { calls.count += 1 })
    try await context.deleteAccount?()
    #expect(calls.count == 1)
  }

  @Test func releaseBuildsKeepDeletionHidden() {
    #if DEBUG
      #expect(ShellSettings.allowsAccountDeletion)
    #else
      #expect(!ShellSettings.allowsAccountDeletion)
    #endif
  }
}

@MainActor
@Suite struct ShellNavigationTests {
  @Test func tabsMatchWebItemsInOrder() {
    #expect(ShellTab.allCases == [.songs, .playlists, .chords, .teams])
    #expect(Set(ShellTab.allCases.map(\.icon.rawValue)).count == 4)
  }

  @Test func debugLaunchArgumentParsesDestinations() {
    #expect(ShellTab.debug("Chords") == .chords)
    #expect(ShellTab.debug("teams") == .teams)
    #expect(ShellTab.debug("settings") == nil)
    #expect(ShellTab.debug("nope") == nil)
  }

  @Test func openSongPushesOntoSongsStackAndSwitchesTab() {
    let nav = ShellNavigation()
    nav.open(.chords)
    let id = UUID()
    nav.openSong(id)
    #expect(nav.destination == .songs)
    #expect(nav.songPath == [id])
  }

  @Test func openingTheSameSongTwiceDoesNotStackDuplicates() {
    let nav = ShellNavigation()
    let id = UUID()
    nav.openSong(id)
    nav.openSong(id)
    #expect(nav.songPath == [id])
    let other = UUID()
    nav.openSong(other)
    #expect(nav.songPath == [id, other])
  }

  @Test func openPlaylistUsesItsOwnStack() {
    let nav = ShellNavigation()
    let song = UUID(), playlist = UUID()
    nav.openSong(song)
    nav.openPlaylist(playlist)
    #expect(nav.destination == .playlists)
    #expect(nav.playlistPath == [playlist])
    #expect(nav.songPath == [song])
  }

  @Test func reselectingTheActiveTabPopsToRoot() {
    let nav = ShellNavigation()
    nav.openSong(UUID())
    nav.open(.songs)
    #expect(nav.songPath.isEmpty)
    nav.openPlaylist(UUID())
    nav.open(.chords)
    #expect(!nav.playlistPath.isEmpty)
    nav.open(.playlists)
    #expect(!nav.playlistPath.isEmpty)
    nav.open(.playlists)
    #expect(nav.playlistPath.isEmpty)
  }

  @Test func resetSelectionsClearsBothStacks() {
    let nav = ShellNavigation()
    nav.openSong(UUID())
    nav.openPlaylist(UUID())
    nav.resetSelections()
    #expect(nav.songPath.isEmpty && nav.playlistPath.isEmpty)
  }

  @Test func actionsOpenSongThroughTheStack() {
    let nav = ShellNavigation()
    let id = UUID()
    nav.makeActions().openSong(id)
    #expect(nav.songPath == [id])
  }

  @Test func personalPillShowsNameAndIsNotFiltered() {
    let user = UUID()
    let named = ContextPillState.make(context: .personal(userID: user), team: nil, personalName: " Ana ")
    #expect(named.label == "Ana")
    #expect(named.isFiltered)
    let anon = ContextPillState.make(context: .personal(userID: user), team: nil, personalName: nil)
    #expect(anon.label == ContextStrings.personal)
  }

  @Test func allPillIsLabelledAllAndNotFiltered() {
    let state = ContextPillState.make(context: .all(userID: UUID()), team: nil, personalName: "Ana")
    #expect(state.kind == .all)
    #expect(state.label == L10n.Nav.viewAll)
    #expect(!state.isFiltered)
  }

  @Test func teamPillIsFilteredAndTruncationMatchesWeb() {
    let id = UUID()
    let state = ContextPillState.make(context: .team(teamID: id), team: nil, personalName: "Ana")
    #expect(state.isFiltered)
    #expect(state.teamID == id)
    #expect(ContextPillState.maxLabelWidth(compact: true) == 80)
    #expect(ContextPillState.maxLabelWidth(compact: false) == 120)
  }
}
