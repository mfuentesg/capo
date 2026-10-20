import CapoCore
import Foundation
import Supabase
import Testing

@testable import CapoSupabase

/// Runs only with `CAPO_LOCAL_SUPABASE=1` and `CAPO_LOCAL_SUPABASE_KEY` set, against the
/// already-running local stack at 127.0.0.1:54321. Never resets or stops anything.
@Suite(
  .enabled(
    if: ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE"] == "1"
      && ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE_KEY"] != nil)
)
struct LocalE2E {
  @Test func songRoundTripWithConflict() async throws {
    let key = ProcessInfo.processInfo.environment["CAPO_LOCAL_SUPABASE_KEY"]!
    let client = SupabaseClient(
      supabaseURL: URL(string: "http://127.0.0.1:54321")!, supabaseKey: key,
      options: SupabaseClientOptions(
        auth: .init(storage: MemoryAuthStorage(), emitLocalSessionAsInitialSession: true)))
    let email = "ios-e2e+\(UUID().uuidString.lowercased())@example.test"
    let session = try await client.auth.signUp(email: email, password: "e2e-\(UUID().uuidString)")
    let userID = session.user.id
    let writer = SupabaseRemoteWriter(client: client)
    let source = SupabaseRemoteSyncSource(client: client)

    var song = makeSong(id: UUID())
    song.userID = userID
    song.createdBy = userID
    var created: Song?
    if case .applied(let server?) = try await writer.apply(.createSong(song)) { created = server }
    let server = try #require(created)

    let scope = SyncScope(userID: userID, teamIDs: [])
    #expect(try await source.songVersions(scope: scope).contains { $0.id == song.id })

    let first = try await writer.apply(
      .updateSong(id: song.id, patch: SongPatch(title: "One"), base: server.updatedAt))
    guard case .applied(let updated?) = first else { Issue.record("update not applied"); return }
    let stale = try await writer.apply(
      .updateSong(id: song.id, patch: SongPatch(title: "Two"), base: server.updatedAt))
    #expect(stale == .conflict(server: updated))

    _ = try await writer.apply(.deleteSong(id: song.id))
    try? await client.auth.signOut(scope: .local)
  }
}
