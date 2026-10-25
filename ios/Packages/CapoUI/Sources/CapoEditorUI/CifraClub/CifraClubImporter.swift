import Foundation

/// Fetches and parses a CifraClub page on device (the web does this in a server action, which the app
/// cannot call). Mirrors `fetch-cifraclub-page.ts`: 8 s timeout, 3 MB cap, at most 3 redirects, and
/// every redirect target re-checked against the host allowlist.
public nonisolated struct CifraClubImporter: Sendable {
  public typealias Loader = @Sendable (URL) async throws -> (Data, HTTPURLResponse)

  static let timeout: TimeInterval = 8
  static let maxBytes = 3_000_000
  static let maxRedirects = 3
  static let userAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

  let load: Loader

  public init(load: @escaping Loader = Self.liveLoader) { self.load = load }

  public func importSong(from input: String) async -> Result<CifraClubSong, CifraClubError> {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 2000 else { return .failure(.invalidURL) }
    switch CifraClubParser.validate(trimmed) {
    case .failure(let error): return .failure(error)
    case .success(let url):
      switch await fetchPage(url) {
      case .failure(let error): return .failure(error)
      case .success(let html): return CifraClubParser.parse(html: html, url: url)
      }
    }
  }

  func fetchPage(_ start: URL) async -> Result<String, CifraClubError> {
    var current = start
    for _ in 0...Self.maxRedirects {
      let data: Data
      let response: HTTPURLResponse
      do { (data, response) = try await load(current) } catch { return .failure(.network) }

      if (300..<400).contains(response.statusCode) {
        guard let location = response.value(forHTTPHeaderField: "Location"),
          let target = URL(string: location, relativeTo: current)?.absoluteURL
        else { return .failure(.httpStatus) }
        switch CifraClubParser.validate(target.absoluteString) {
        case .success(let validated): current = validated
        case .failure(let error): return .failure(error == .wrongHost ? .wrongHost : .httpStatus)
        }
        continue
      }
      guard (200..<300).contains(response.statusCode), data.count <= Self.maxBytes else {
        return .failure(.httpStatus)
      }
      return .success(Self.decode(data, response))
    }
    return .failure(.httpStatus)
  }

  /// Honors the response charset (CifraClub has served Latin-1 pages); UTF-8 otherwise. Without this a
  /// non-UTF-8 page turns every accented letter into U+FFFD.
  static func decode(_ data: Data, _ response: HTTPURLResponse) -> String {
    if let name = response.textEncodingName {
      let cf = CFStringConvertIANACharSetNameToEncoding(name as CFString)
      if cf != kCFStringEncodingInvalidId {
        let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
        if let text = String(data: data, encoding: encoding) { return text }
      }
    }
    return String(decoding: data, as: UTF8.self)
  }

  /// URLSession without automatic redirects, with the web's browser-like headers.
  public static let liveLoader: Loader = { url in
    var request = URLRequest(url: url, timeoutInterval: CifraClubImporter.timeout)
    request.setValue(CifraClubImporter.userAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
    request.setValue("en-US,en;q=0.9,pt-BR;q=0.8,es;q=0.7", forHTTPHeaderField: "Accept-Language")
    let (data, response) = try await URLSession.shared.data(for: request, delegate: NoRedirects())
    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    return (data, http)
  }

  private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
      _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
      newRequest request: URLRequest
    ) async -> URLRequest? { nil }
  }
}
