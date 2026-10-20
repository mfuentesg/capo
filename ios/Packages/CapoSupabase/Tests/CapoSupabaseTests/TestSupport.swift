import CapoCore
import Foundation
import Supabase

@testable import CapoSupabase

struct RecordedRequest: Sendable {
  var method: String
  var url: URL
  var headers: [String: String]
  var body: Data

  var path: String { url.path }
  var query: [String: String] {
    var result: [String: String] = [:]
    for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
      result[item.name] = item.value ?? ""
    }
    return result
  }
  var rawQuery: String { url.query ?? "" }
  var json: Any? { try? JSONSerialization.jsonObject(with: body) }
  var jsonObject: [String: Any]? { json as? [String: Any] }
  var jsonArray: [[String: Any]]? { json as? [[String: Any]] }
  func header(_ name: String) -> String? {
    headers.first { $0.key.lowercased() == name.lowercased() }?.value
  }
}

enum StubResult: Sendable {
  case json(Int, String)
  case failure(URLError.Code)

  static func ok(_ body: String) -> StubResult { .json(200, body) }
  static func postgrestError(_ status: Int, code: String, message: String = "error") -> StubResult {
    .json(status, #"{"code":"\#(code)","message":"\#(message)","details":null,"hint":null}"#)
  }
}

/// One stub backend per test, addressed by a unique host so tests can run in parallel.
final class StubServer: @unchecked Sendable {
  typealias Handler = @Sendable (RecordedRequest) -> StubResult

  let host = "t\(UUID().uuidString.prefix(8).lowercased()).test"
  var url: URL { URL(string: "https://\(host)")! }

  private let lock = NSLock()
  private var _requests: [RecordedRequest] = []
  private var handler: Handler = { _ in .json(404, "{}") }

  var requests: [RecordedRequest] {
    lock.lock()
    defer { lock.unlock() }
    return _requests
  }

  /// Requests that hit the REST/RPC surface (auth traffic excluded).
  var restRequests: [RecordedRequest] { requests.filter { $0.path.hasPrefix("/rest/v1/") } }

  init() { StubURLProtocol.register(self) }
  deinit { StubURLProtocol.unregister(host: host) }

  func handle(_ handler: @escaping Handler) {
    lock.lock()
    self.handler = handler
    lock.unlock()
  }

  /// Answers each REST call from `responses` in order (last one repeats).
  func sequence(_ responses: [StubResult]) {
    let counter = Counter()
    handle { _ in responses[min(counter.next(), responses.count - 1)] }
  }

  fileprivate func respond(to request: RecordedRequest) -> StubResult {
    lock.lock()
    _requests.append(request)
    let current = handler
    lock.unlock()
    return current(request)
  }
}

final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0
  func next() -> Int {
    lock.lock()
    defer { lock.unlock() }
    defer { value += 1 }
    return value
  }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  nonisolated(unsafe) private static var servers: [String: StubServer] = [:]

  static func register(_ server: StubServer) {
    lock.lock()
    servers[server.host] = server
    lock.unlock()
  }
  static func unregister(host: String) {
    lock.lock()
    servers[host] = nil
    lock.unlock()
  }
  private static func server(for host: String?) -> StubServer? {
    lock.lock()
    defer { lock.unlock() }
    return host.flatMap { servers[$0] }
  }

  override class func canInit(with request: URLRequest) -> Bool {
    server(for: request.url?.host) != nil
  }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let url = request.url, let server = Self.server(for: url.host) else {
      client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
      return
    }
    var body = request.httpBody ?? Data()
    if body.isEmpty, let stream = request.httpBodyStream {
      stream.open()
      var buffer = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        body.append(buffer, count: count)
      }
      stream.close()
    }
    let recorded = RecordedRequest(
      method: request.httpMethod ?? "GET", url: url, headers: request.allHTTPHeaderFields ?? [:],
      body: body)

    switch server.respond(to: recorded) {
    case .failure(let code):
      client?.urlProtocol(self, didFailWithError: URLError(code))
    case .json(let status, let text):
      let response = HTTPURLResponse(
        url: url, statusCode: status, httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(text.utf8))
      client?.urlProtocolDidFinishLoading(self)
    }
  }
  override func stopLoading() {}
}

final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
  private let lock = NSLock()
  private var items: [String: Data]
  init(_ items: [String: Data] = [:]) { self.items = items }
  func store(key: String, value: Data) throws {
    lock.lock()
    items[key] = value
    lock.unlock()
  }
  func retrieve(key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return items[key]
  }
  func remove(key: String) throws {
    lock.lock()
    items[key] = nil
    lock.unlock()
  }
}

func makeClient(_ server: StubServer, storage: any AuthLocalStorage = MemoryAuthStorage())
  -> SupabaseClient
{
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [StubURLProtocol.self]
  return SupabaseClient(
    supabaseURL: server.url, supabaseKey: "test-publishable-key",
    options: SupabaseClientOptions(
      auth: .init(
        storage: storage, redirectToURL: URL(string: "capo://auth/callback"), flowType: .pkce,
        emitLocalSessionAsInitialSession: true),
      global: .init(session: URLSession(configuration: configuration))
    )
  )
}

func fixture(_ name: String) throws -> Data {
  let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
  return try Data(contentsOf: dir.appendingPathComponent("Fixtures/\(name).json"))
}

func fixtureString(_ name: String) throws -> String {
  String(decoding: try fixture(name), as: UTF8.self)
}

// Stable ids used across tests.
enum Ids {
  static let user = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
  static let team = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
  static let song = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
  static let song2 = UUID(uuidString: "33333333-3333-3333-3333-333333333334")!
  static let playlist = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
  static let tag = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
}

func makeSong(id: UUID = Ids.song, updatedAt: String = "2024-05-01T10:00:00.123456+00:00") -> Song {
  Song(
    id: id, title: "Amazing Grace", artist: "John Newton", key: "G", bpm: 80, lyrics: "[G]Amazing",
    notes: nil, transpose: 0, capo: 0, status: .published, userID: Ids.user, teamID: nil,
    createdBy: Ids.user, createdAt: ServerTimestamp("2024-05-01T10:00:00.123456+00:00"),
    updatedAt: ServerTimestamp(updatedAt))
}

func songRowJSON(id: UUID = Ids.song, updatedAt: String = "2024-05-01T10:00:00.123456+00:00")
  -> String
{
  """
  {"id":"\(id.pg)","title":"Amazing Grace","artist":"John Newton","key":"G","bpm":80,\
  "lyrics":"[G]Amazing","notes":null,"transpose":0,"capo":0,"status":"published",\
  "user_id":"\(Ids.user.pg)","team_id":null,"created_by":"\(Ids.user.pg)",\
  "created_at":"2024-05-01T10:00:00.123456+00:00","updated_at":"\(updatedAt)"}
  """
}
