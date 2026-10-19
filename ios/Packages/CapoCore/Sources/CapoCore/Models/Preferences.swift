import Foundation

public enum JSONValue: Hashable, Sendable, Codable {
  case string(String), number(Double), bool(Bool), null, array([JSONValue]), object([String: JSONValue])

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSONValue].self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let v): try container.encode(v)
    case .number(let v): try container.encode(v)
    case .bool(let v): try container.encode(v)
    case .null: try container.encodeNil()
    case .array(let v): try container.encode(v)
    case .object(let v): try container.encode(v)
    }
  }

  public var stringValue: String? {
    if case .string(let v) = self { return v }
    return nil
  }
}

public enum AppTheme: String, Codable, Sendable, CaseIterable {
  case light, dark, system
}

public struct UserPreferences: Hashable, Sendable, Codable {
  public var lyricsColumns: Int  // 1|2; default 2 (web mapJsonToPreferences)
  public var locale: String?
  public var theme: AppTheme?
  public var chordHand: String?
  public var palette: String?
  public var uiFont: String?
  public var raw: [String: JSONValue]  // full JSON, preserved on write

  /// Mirrors web `mapJsonToPreferences`: only a numeric 1 means one column.
  public init(json: [String: JSONValue]) {
    raw = json
    lyricsColumns = json["lyricsColumns"] == .number(1) ? 1 : 2
    locale = json["locale"]?.stringValue
    theme = json["theme"]?.stringValue.flatMap(AppTheme.init(rawValue:))
    let hand = json["chordHand"]?.stringValue
    chordHand = hand == "left" || hand == "right" ? hand : nil
    palette = json["palette"]?.stringValue
    uiFont = json["uiFont"]?.stringValue
  }

  /// The full preferences JSON with the patch applied; unknown keys are kept.
  public func json(applying patch: PreferencesPatch) -> [String: JSONValue] {
    var result = raw
    if let columns = patch.lyricsColumns { result["lyricsColumns"] = .number(Double(columns)) }
    if let locale = patch.locale { result["locale"] = .string(locale) }
    if let theme = patch.theme { result["theme"] = .string(theme.rawValue) }
    return result
  }

  public static let `default` = UserPreferences(json: [:])
}

public struct PreferencesPatch: Hashable, Sendable, Codable {
  public var lyricsColumns: Int?
  public var locale: String?
  public var theme: AppTheme?

  public init(lyricsColumns: Int? = nil, locale: String? = nil, theme: AppTheme? = nil) {
    self.lyricsColumns = lyricsColumns
    self.locale = locale
    self.theme = theme
  }
}

public struct Profile: Hashable, Sendable, Codable {
  public var id: UserID
  public var email: String?
  public var fullName: String?
  public var avatarURL: String?
  public var preferences: UserPreferences
  public var updatedAt: ServerTimestamp

  public init(
    id: UserID, email: String?, fullName: String?, avatarURL: String?,
    preferences: UserPreferences, updatedAt: ServerTimestamp
  ) {
    self.id = id
    self.email = email
    self.fullName = fullName
    self.avatarURL = avatarURL
    self.preferences = preferences
    self.updatedAt = updatedAt
  }
}

public struct UserSongSettings: Hashable, Sendable, Codable {
  public var songID: SongID
  public var transpose: Int
  public var capo: Int
  public var fontSize: Double?
  public var updatedAt: ServerTimestamp?

  public init(
    songID: SongID, transpose: Int, capo: Int, fontSize: Double?, updatedAt: ServerTimestamp?
  ) {
    self.songID = songID
    self.transpose = transpose
    self.capo = capo
    self.fontSize = fontSize
    self.updatedAt = updatedAt
  }
}

public struct EffectiveSongSettings: Hashable, Sendable {
  public var transpose: Int
  public var capo: Int
  public var fontSize: Double

  public init(transpose: Int, capo: Int, fontSize: Double) {
    self.transpose = transpose
    self.capo = capo
    self.fontSize = fontSize
  }

  /// user ?? song ?? defaults (font 1).
  public static func resolve(song: Song, user: UserSongSettings?) -> EffectiveSongSettings {
    EffectiveSongSettings(
      transpose: user?.transpose ?? song.transpose,
      capo: user?.capo ?? song.capo,
      fontSize: user?.fontSize ?? 1
    )
  }

  public static let transposeRange = -6...6, capoRange = 0...12, fontSizeRange = 0.5...3.0
  public static let fontSizeStep = 0.25
}
