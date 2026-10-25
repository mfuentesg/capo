import CapoCore
import Foundation
import Supabase

/// Permanently deletes the signed-in user's account. The RPC itself rejects any `p_user_id` other
/// than `auth.uid()`; failures map to `CapoError` like the other online-only calls.
public final class SupabaseAccountRemote: Sendable {
  private let client: SupabaseClient

  public init(client: SupabaseClient) { self.client = client }

  /// Same table and columns as the web's `submitFeedback` action (RLS lets any signed-in user insert).
  /// The web also emails a notification from its server action; a direct insert cannot.
  public func submitFeedback(_ draft: FeedbackDraft) async throws {
    guard draft.problem == nil else { throw CapoError.invalidInput("feedback") }
    let row: [String: JSONValue] = [
      "message": .string(draft.trimmedMessage),
      "newsletter_opt_in": .bool(draft.newsletterOptIn),
      "name": draft.trimmedName.isEmpty ? .null : .string(draft.trimmedName),
      "email": draft.trimmedEmail.isEmpty ? .null : .string(draft.trimmedEmail),
      "opt_in_at": draft.newsletterOptIn
        ? .string(ISO8601DateFormatter().string(from: Date())) : .null
    ]
    do {
      try await client.from("feedback").insert(row, returning: .minimal).execute()
    } catch {
      throw RemoteErrors.capoError(error)
    }
  }

  public func deleteAccount(userID: UserID) async throws {
    do {
      try await client.rpc("delete_user_account", params: ["p_user_id": userID.pg]).execute()
    } catch {
      throw RemoteErrors.capoError(error)
    }
  }
}
