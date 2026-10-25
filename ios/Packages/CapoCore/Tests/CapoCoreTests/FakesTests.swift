import CapoCore
import CapoFakes
import Foundation
import Testing

@Suite struct FakesTests {
  @Test func seedShape() {
    let state = FakeSeed.demo()
    #expect(state.songs.count == 12)
    #expect(state.playlists.count == 2)
    #expect(state.teams.count == 1)
    #expect(state.tags.count == 4)
  }

  @Test func songStreamReflectsContextSearchAndMutations() async throws {
    let services = UserServices.fake()
    let personal = SongQuery(context: .personal(userID: FakeIDs.user))
    var stream = services.songs.songs(personal).makeAsyncIterator()
    #expect(await stream.next()?.count == 8)

    let team = try #require(await services.songs.songs(SongQuery(context: .team(teamID: FakeIDs.team)))
      .first(where: { _ in true }))
    #expect(team.count == 4)

    let search = SongQuery(context: .personal(userID: FakeIDs.user), searchText: "cancion")
    let found = await services.songs.songs(search).first(where: { _ in true })
    #expect(found?.map(\.title) == ["Canción del Mar"])

    _ = try await services.songs.create(SongDraft(title: "Nueva"), in: .personal(userID: FakeIDs.user))
    #expect(await stream.next()?.count == 9)
  }

  @Test func scriptedWriterAndRemote() async throws {
    let writer = FakeRemoteWriter()
    await writer.enqueueFailure()
    await #expect(throws: FakeError.self) { try await writer.apply(.deleteSong(id: FakeIDs.songs[0])) }
    let result = try await writer.apply(.deleteSong(id: FakeIDs.songs[0]))
    #expect(result == .applied(serverSong: nil))

    let remote = FakeRemoteSyncSource(state: FakeSeed.demo())
    let versions = try await remote.songVersions(scope: SyncScope(userID: FakeIDs.user, teamIDs: []))
    #expect(versions.count == 8)
    await remote.failNext("profile")
    await #expect(throws: FakeError.self) { try await remote.profile(userID: FakeIDs.user) }
    #expect(await remote.calls == ["songVersions", "profile"])
  }
}
