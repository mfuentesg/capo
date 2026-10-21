import CapoCore
import Foundation
import Supabase

/// Permanently deletes the signed-in user's account. The RPC itself rejects any `p_user_id` other
/// than `auth.uid()`; failures map to `CapoError` like the other online-only calls.
public final class SupabaseAccountRemote: Sendable {
  private let client: SupabaseClient

  public init(client: SupabaseClient) { self.client = client }

  public func deleteAccount(userID: UserID) async throws {
    do {
      try await client.rpc("delete_user_account", params: ["p_user_id": userID.pg]).execute()
    } catch {
      throw RemoteErrors.capoError(error)
    }
  }
}
