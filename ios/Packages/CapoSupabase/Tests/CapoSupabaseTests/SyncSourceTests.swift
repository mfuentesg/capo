import CapoCore
import Foundation
import Testing

@testable import CapoSupabase

@Suite struct SyncSourceTests {
  private func versionsJSON(_ count: Int, offset: Int = 0) -> String {
    let rows = (0..<count).map { i in
      let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", offset + i))!
      return #"{"id":"\#(id.pg)","updated_at":"2024-05-01T10:00:00.123456+00:00"}"#
    }
    return "[" + rows.joined(separator: ",") + "]"
  }

  @Test func songVersionsPagesUntilShortPage() async throws {
    let server = StubServer()
    server.handle { request in
      switch request.query["offset"] {
      case "0": return .ok(self.versionsJSON(1000))
      default: return .ok(self.versionsJSON(5, offset: 1000))
      }
    }
    let source = SupabaseRemoteSyncSource(client: makeClient(server))
    let scope = SyncScope(userID: Ids.user, teamIDs: [Ids.team])
    let versions = try await source.songVersions(scope: scope)

    #expect(versions.count == 1005)
    let requests = server.restRequests
    #expect(requests.count == 2)
    #expect(requests.map { $0.query["offset"] } == ["0", "1000"])
    #expect(requests.allSatisfy { $0.query["limit"] == "1000" })
    #expect(requests[0].path == "/rest/v1/songs")
    #expect(requests[0].query["select"] == "id,updated_at")
    #expect(requests[0].query["or"] == "(user_id.eq.\(Ids.user.pg),team_id.in.(\(Ids.team.pg)))")
    #expect(versions[0].updatedAt.raw == "2024-05-01T10:00:00.123456+00:00")
  }

  @Test func exactlyOnePageTriggersOneMoreRequestThatStops() async throws {
    let server = StubServer()
    server.handle { request in
      request.query["offset"] == "0" ? .ok(self.versionsJSON(1000)) : .ok("[]")
    }
    let source = SupabaseRemoteSyncSource(client: makeClient(server))
    let versions = try await source.playlistVersions(
      scope: SyncScope(userID: Ids.user, teamIDs: []))
    #expect(versions.count == 1000)
    #expect(server.restRequests.count == 2)
    #expect(server.restRequests[0].query["or"] == "(user_id.eq.\(Ids.user.pg))")
  }

  @Test func songsByIdAreChunkedTo100() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[]") }
    let source = SupabaseRemoteSyncSource(client: makeClient(server))
    _ = try await source.songs(ids: (0..<250).map { _ in UUID() })
    let counts = server.restRequests.map {
      ($0.query["id"] ?? "").split(separator: ",").count
    }
    #expect(counts == [100, 100, 50])
    #expect(server.restRequests[0].query["select"]?.contains("search_vector") == false)
  }

  @Test func profileMissingThrowsNotFound() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[]") }
    let source = SupabaseRemoteSyncSource(client: makeClient(server))
    await #expect(throws: CapoError.notFound) { try await source.profile(userID: Ids.user) }
  }

  @Test func timestampPlusIsPercentEncodedInEqFilter() async throws {
    let server = StubServer()
    server.handle { _ in .ok("[]") }
    let writer = SupabaseRemoteWriter(client: makeClient(server))
    _ = try await writer.apply(
      .updateSong(
        id: Ids.song, patch: SongPatch(title: "x"),
        base: ServerTimestamp("2024-05-01T10:00:00.123456+00:00")))
    let patch = try #require(server.restRequests.first)
    #expect(patch.method == "PATCH")
    #expect(patch.rawQuery.contains("%2B00"))
    #expect(!patch.rawQuery.contains("+00"))
  }
}
