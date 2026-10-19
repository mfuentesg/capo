import Foundation

public typealias UserID = UUID
public typealias SongID = UUID
public typealias PlaylistID = UUID
public typealias TagID = UUID
public typealias TeamID = UUID

/// A PostgREST `timestamptz` kept as its exact wire string.
///
/// Postgres stores microseconds, which `Date` cannot round-trip exactly, so equality
/// (and optimistic-concurrency `eq` filters) always use `raw`. `date` is for display and ordering.
public struct ServerTimestamp: Hashable, Comparable, Sendable, Codable {
  public let raw: String

  public init(_ raw: String) {
    self.raw = raw
  }

  /// Parses `yyyy-MM-dd[T ]HH:mm:ss[.f{0,6}][Z|±hh[:mm]]`. A missing zone means UTC.
  public var date: Date? {
    Self.parse(raw)
  }

  /// ISO8601 with milliseconds in UTC, used for client-authored LWW values.
  public static func now() -> ServerTimestamp {
    ServerTimestamp(Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(Date()))
  }

  public static func < (l: ServerTimestamp, r: ServerTimestamp) -> Bool {
    let ld = l.date ?? .distantPast
    let rd = r.date ?? .distantPast
    if ld != rd { return ld < rd }
    return l.raw < r.raw
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    raw = try container.decode(String.self)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(raw)
  }

  private static func parse(_ string: String) -> Date? {
    let chars = Array(string.utf8)
    var index = 0

    func digits(_ count: Int) -> Int? {
      guard index + count <= chars.count else { return nil }
      var value = 0
      for i in index..<(index + count) {
        let c = chars[i]
        guard c >= 48, c <= 57 else { return nil }
        value = value * 10 + Int(c - 48)
      }
      index += count
      return value
    }
    func expect(_ allowed: Set<UInt8>) -> Bool {
      guard index < chars.count, allowed.contains(chars[index]) else { return false }
      index += 1
      return true
    }

    guard let year = digits(4), expect([45]), let month = digits(2), expect([45]),
      let day = digits(2), expect([84, 116, 32]),  // T, t, space
      let hour = digits(2), expect([58]), let minute = digits(2), expect([58]),
      let second = digits(2)
    else { return nil }

    var fraction = 0.0
    if index < chars.count, chars[index] == 46 {  // "."
      index += 1
      var scale = 0.1
      var count = 0
      while index < chars.count, chars[index] >= 48, chars[index] <= 57 {
        fraction += Double(chars[index] - 48) * scale
        scale /= 10
        index += 1
        count += 1
      }
      guard count > 0 else { return nil }
    }

    var offsetSeconds = 0
    if index < chars.count {
      let sign = chars[index]
      if sign == 90 || sign == 122 {  // Z, z
        index += 1
      } else if sign == 43 || sign == 45 {  // +, -
        index += 1
        guard let oh = digits(2) else { return nil }
        var om = 0
        if index < chars.count {
          _ = expect([58])
          guard let m = digits(2) else { return nil }
          om = m
        }
        offsetSeconds = (oh * 3600 + om * 60) * (sign == 45 ? -1 : 1)
      } else {
        return nil
      }
    }
    guard index == chars.count else { return nil }

    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    guard let base = calendar.date(from: components) else { return nil }
    return base.addingTimeInterval(fraction - Double(offsetSeconds))
  }
}
