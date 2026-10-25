import CapoCore
import Foundation
import Supabase

enum RemoteSupport {
  static let pageSize = 1000
  static let chunkSize = 100

  /// Pages `build(from, to)` with `.range` until a page comes back short.
  static func paged<Row: Decodable & Sendable>(
    _ type: Row.Type,
    _ build: (_ from: Int, _ to: Int) -> PostgrestTransformBuilder
  ) async throws -> [Row] {
    var result: [Row] = []
    var from = 0
    while true {
      let page: [Row] = try await build(from, from + pageSize - 1).execute().value
      result.append(contentsOf: page)
      if page.count < pageSize { return result }
      from += pageSize
    }
  }

  static func chunks<T>(_ values: [T]) -> [[T]] {
    stride(from: 0, to: values.count, by: chunkSize).map {
      Array(values[$0..<min($0 + chunkSize, values.count)])
    }
  }

  /// The `or=(user_id.eq.<me>,team_id.in.(…))` filter that scopes sync to the user and their teams.
  static func scopeFilter(_ scope: SyncScope) -> String {
    var parts = ["user_id.eq.\(scope.userID.pg)"]
    if !scope.teamIDs.isEmpty {
      parts.append("team_id.in.(\(scope.teamIDs.map(\.pg).joined(separator: ",")))")
    }
    return parts.joined(separator: ",")
  }
}

/// Error classification shared by the writer and the online-only teams calls.
enum RemoteErrors {
  static func code(_ error: Error) -> String? { (error as? PostgrestError)?.code }

  static func httpStatus(_ error: Error) -> Int? {
    if let http = error as? HTTPError { return http.response.statusCode }
    if case .api(_, _, _, let response) = error as? AuthError { return response.statusCode }
    return nil
  }

  /// PostgREST "function not found in the schema cache" (PGRST202) or Postgres undefined_function.
  static func isMissingFunction(_ error: Error) -> Bool {
    guard let code = code(error) else { return false }
    return code == "PGRST202" || code == "42883"
  }

  static func isUniqueViolation(_ error: Error) -> Bool { code(error) == "23505" }

  /// Permanent failures; `nil` means transient (network, 5xx, anything unrecognised) so the
  /// outbox retries.
  static func rejection(for error: Error) -> CapoError? {
    if let code = code(error) {
      if code == "42501" || code.hasPrefix("PGRST30") { return .permissionDenied }
      if ["23514", "22P02", "23502", "23503"].contains(code) {
        return .invalidInput((error as? PostgrestError)?.message ?? code)
      }
    }
    if let status = httpStatus(error), status == 401 || status == 403 { return .permissionDenied }
    return nil
  }

  /// Maps any thrown error to a user-facing `CapoError` for the online-only teams surface.
  static func capoError(_ error: Error) -> CapoError {
    if let capo = error as? CapoError { return capo }
    if let rejected = rejection(for: error) { return rejected }
    if error is URLError { return .offlineUnavailable }
    if let postgrest = error as? PostgrestError {
      if postgrest.code == "PGRST116" { return .notFound }
      return .server(postgrest.message)
    }
    if let auth = error as? AuthError, case .sessionMissing = auth { return .notAuthenticated }
    return .server(error.localizedDescription)
  }
}
