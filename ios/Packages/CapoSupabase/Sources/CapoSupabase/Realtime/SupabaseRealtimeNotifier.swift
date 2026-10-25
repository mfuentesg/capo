import CapoCore
import Foundation
import Supabase

/// Emits one `RealtimeChange` per postgres change on the tables the sync engine mirrors. The sync
/// engine treats any change as "pull soon", so payloads are ignored. Row-level visibility is
/// enforced by Realtime under the user's RLS; `scope` is not needed for filtering.
public final class SupabaseRealtimeNotifier: RealtimeNotifier {
  static let tables = [
    "songs", "playlists", "playlist_songs", "song_tags", "song_tag_assignments",
    "user_song_settings", "profiles", "team_members", "teams"
  ]

  private let client: SupabaseClient

  public init(client: SupabaseClient) {
    self.client = client
  }

  public func changes(scope: SyncScope) -> AsyncStream<RealtimeChange> {
    let client = self.client
    let (stream, continuation) = AsyncStream<RealtimeChange>.makeStream(
      bufferingPolicy: .bufferingNewest(64))

    let task = Task {
      let channel = client.channel("capo-sync-\(scope.userID.pg)-\(UUID().uuidString.prefix(8))")
      let subscriptions = Self.tables.map { table in
        channel.onPostgresChange(AnyAction.self, schema: "public", table: table) { _ in
          continuation.yield(RealtimeChange(table: table))
        }
      }
      do {
        try await channel.subscribeWithError()
        // Hold the subscriptions (and so the callbacks) until the consumer goes away.
        while !Task.isCancelled { try? await Task.sleep(for: .seconds(3600)) }
      } catch {
        // Realtime is an optimisation; the sync engine still pulls on its other triggers.
      }
      withExtendedLifetime(subscriptions) {}
      await channel.unsubscribe()
      await client.removeChannel(channel)
      continuation.finish()
    }
    continuation.onTermination = { _ in task.cancel() }
    return stream
  }
}
