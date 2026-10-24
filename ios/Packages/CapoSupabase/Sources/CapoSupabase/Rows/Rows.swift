import CapoCore
import Foundation

/// Hand-mirrored PostgREST row shapes for `lib/supabase/database.types.ts`.
///
/// Every column of the table's `Row` type has a `CodingKeys` case; `RowsDriftTests` compares the two.
/// Timestamps stay raw strings (`ServerTimestamp`) so they survive a round trip byte-for-byte.

extension UUID {
  /// Lowercase form, as Postgres prints UUIDs; used in filters and request bodies.
  var pg: String { uuidString.lowercased() }
}

struct SongRow: Codable, Sendable {
  var artist: String?
  var bpm: Int?
  var capo: Int
  var createdAt: ServerTimestamp
  var createdBy: UUID
  var id: UUID
  var key: String?
  var lyrics: String?
  var notes: String?
  var status: SongStatus
  var teamID: UUID?
  var title: String
  var transpose: Int
  var updatedAt: ServerTimestamp
  var userID: UUID?

  enum CodingKeys: String, CodingKey, CaseIterable {
    case artist, bpm, capo, id, key, lyrics, notes, status, title, transpose
    case createdAt = "created_at"
    case createdBy = "created_by"
    case teamID = "team_id"
    case updatedAt = "updated_at"
    case userID = "user_id"
  }

  /// Everything except `search_vector`, which is server-side only.
  static let columns = CodingKeys.allCases.map(\.rawValue).joined(separator: ",")

  var model: Song {
    Song(
      id: id, title: title, artist: artist, key: key, bpm: bpm, lyrics: lyrics, notes: notes,
      transpose: transpose, capo: capo, status: status, userID: userID, teamID: teamID,
      createdBy: createdBy, createdAt: createdAt, updatedAt: updatedAt)
  }

  /// Insert body with the client id; `created_at`/`updated_at` are left to the server.
  static func insertPayload(_ song: Song) -> [String: JSONValue] {
    [
      "id": .string(song.id.pg),
      "title": .string(song.title),
      "artist": .optionalString(song.artist),
      "key": .optionalString(song.key),
      "bpm": .optionalInt(song.bpm),
      "lyrics": .optionalString(song.lyrics),
      "notes": .optionalString(song.notes),
      "transpose": .number(Double(song.transpose)),
      "capo": .number(Double(song.capo)),
      "status": .string(song.status.rawValue),
      "user_id": .optionalUUID(song.userID),
      "team_id": .optionalUUID(song.teamID),
      "created_by": .string(song.createdBy.pg)
    ]
  }

  /// Update body mirroring web `mapFrontendUpdatesToDB`: empty string / 0 bpm clear the column.
  static func updatePayload(_ patch: SongPatch) -> [String: JSONValue] {
    var body: [String: JSONValue] = [:]
    if let title = patch.title { body["title"] = .string(title) }
    if let artist = patch.artist { body["artist"] = .nonEmptyString(artist) }
    if let key = patch.key { body["key"] = .nonEmptyString(key) }
    if let bpm = patch.bpm { body["bpm"] = bpm == 0 ? .null : .number(Double(bpm)) }
    if let lyrics = patch.lyrics { body["lyrics"] = .nonEmptyString(lyrics) }
    if let notes = patch.notes { body["notes"] = .nonEmptyString(notes) }
    if let transpose = patch.transpose { body["transpose"] = .number(Double(transpose)) }
    if let capo = patch.capo { body["capo"] = .number(Double(capo)) }
    if let status = patch.status { body["status"] = .string(status.rawValue) }
    if let teamID = patch.teamID {
      body["team_id"] = .string(teamID.pg)
      body["user_id"] = .null
    }
    return body
  }
}

struct PlaylistRow: Codable, Sendable {
  var allowGuestEditing: Bool
  var archivedAt: ServerTimestamp?
  var createdAt: ServerTimestamp
  var createdBy: UUID
  var date: String?
  var description: String?
  var id: UUID
  var isPublic: Bool
  var name: String
  var shareCode: String?
  var shareExpiresAt: ServerTimestamp?
  var teamID: UUID?
  var updatedAt: ServerTimestamp
  var userID: UUID?

  enum CodingKeys: String, CodingKey, CaseIterable {
    case date, description, id, name
    case allowGuestEditing = "allow_guest_editing"
    case archivedAt = "archived_at"
    case createdAt = "created_at"
    case createdBy = "created_by"
    case isPublic = "is_public"
    case shareCode = "share_code"
    case shareExpiresAt = "share_expires_at"
    case teamID = "team_id"
    case updatedAt = "updated_at"
    case userID = "user_id"
  }

  static let columns = CodingKeys.allCases.map(\.rawValue).joined(separator: ",")

  var model: Playlist {
    Playlist(
      id: id, name: name, description: description, date: date, isPublic: isPublic,
      allowGuestEditing: allowGuestEditing, shareCode: shareCode, shareExpiresAt: shareExpiresAt,
      archivedAt: archivedAt, userID: userID, teamID: teamID, createdBy: createdBy,
      createdAt: createdAt, updatedAt: updatedAt)
  }

  static func insertPayload(_ playlist: Playlist, shareCode: String) -> [String: JSONValue] {
    [
      "id": .string(playlist.id.pg),
      "name": .string(playlist.name),
      "description": .optionalString(playlist.description),
      "date": .optionalString(playlist.date),
      "is_public": .bool(playlist.isPublic),
      "allow_guest_editing": .bool(playlist.allowGuestEditing),
      "user_id": .optionalUUID(playlist.userID),
      "team_id": .optionalUUID(playlist.teamID),
      "created_by": .string(playlist.createdBy.pg),
      "share_code": .string(shareCode)
    ]
  }

  static func updatePayload(_ patch: PlaylistPatch) -> [String: JSONValue] {
    var body: [String: JSONValue] = [:]
    if let name = patch.name { body["name"] = .string(name) }
    if let description = patch.description { body["description"] = .nonEmptyString(description) }
    if let date = patch.date { body["date"] = .nonEmptyString(date) }
    if let isPublic = patch.isPublic { body["is_public"] = .bool(isPublic) }
    if let allow = patch.allowGuestEditing { body["allow_guest_editing"] = .bool(allow) }
    return body
  }
}

struct PlaylistSongRow: Codable, Sendable {
  var createdAt: ServerTimestamp
  var id: UUID
  var playlistID: UUID
  var position: Int
  var songID: UUID

  enum CodingKeys: String, CodingKey, CaseIterable {
    case id, position
    case createdAt = "created_at"
    case playlistID = "playlist_id"
    case songID = "song_id"
  }

  var model: PlaylistEntry {
    PlaylistEntry(id: id, playlistID: playlistID, songID: songID, position: position)
  }
}

struct ProfileRow: Codable, Sendable {
  var avatarURL: String?
  var createdAt: ServerTimestamp
  var email: String?
  var fullName: String?
  var id: UUID
  var preferences: [String: JSONValue]?
  var updatedAt: ServerTimestamp

  enum CodingKeys: String, CodingKey, CaseIterable {
    case email, id, preferences
    case avatarURL = "avatar_url"
    case createdAt = "created_at"
    case fullName = "full_name"
    case updatedAt = "updated_at"
  }

  var model: Profile {
    Profile(
      id: id, email: email, fullName: fullName, avatarURL: avatarURL,
      preferences: UserPreferences(json: preferences ?? [:]), updatedAt: updatedAt)
  }
}

struct SongTagAssignmentRow: Codable, Sendable {
  var songID: UUID
  var tagID: UUID

  enum CodingKeys: String, CodingKey, CaseIterable {
    case songID = "song_id"
    case tagID = "tag_id"
  }

  var model: TagAssignment { TagAssignment(songID: songID, tagID: tagID) }
}

struct SongTagRow: Codable, Sendable {
  var color: String?
  var createdAt: ServerTimestamp
  var id: UUID
  var name: String
  var teamID: UUID?
  var userID: UUID?

  enum CodingKeys: String, CodingKey, CaseIterable {
    case color, id, name
    case createdAt = "created_at"
    case teamID = "team_id"
    case userID = "user_id"
  }

  var model: SongTag {
    SongTag(
      id: id, name: name, color: color, userID: userID, teamID: teamID, createdAt: createdAt)
  }

  static func insertPayload(_ tag: SongTag) -> [String: JSONValue] {
    [
      "id": .string(tag.id.pg),
      "name": .string(tag.name),
      "color": .optionalString(tag.color),
      "user_id": .optionalUUID(tag.userID),
      "team_id": .optionalUUID(tag.teamID)
    ]
  }
}

struct TeamInvitationRow: Codable, Sendable {
  var acceptedAt: ServerTimestamp?
  var createdAt: ServerTimestamp
  var email: String
  var expiresAt: ServerTimestamp
  var id: UUID
  var invitedBy: UUID
  var role: TeamRole
  var teamID: UUID
  var token: String

  enum CodingKeys: String, CodingKey, CaseIterable {
    case email, id, role, token
    case acceptedAt = "accepted_at"
    case createdAt = "created_at"
    case expiresAt = "expires_at"
    case invitedBy = "invited_by"
    case teamID = "team_id"
  }

  var model: TeamInvitation {
    TeamInvitation(
      id: id, teamID: teamID, email: email, role: role, invitedBy: invitedBy, token: token,
      expiresAt: expiresAt, acceptedAt: acceptedAt, createdAt: createdAt)
  }
}

struct TeamMemberRow: Codable, Sendable {
  var createdAt: ServerTimestamp
  var id: UUID
  var joinedAt: ServerTimestamp
  var role: TeamRole
  var teamID: UUID
  var userID: UUID

  enum CodingKeys: String, CodingKey, CaseIterable {
    case id, role
    case createdAt = "created_at"
    case joinedAt = "joined_at"
    case teamID = "team_id"
    case userID = "user_id"
  }

  var model: TeamMembership {
    TeamMembership(id: id, teamID: teamID, userID: userID, role: role, joinedAt: joinedAt)
  }
}

struct TeamRow: Codable, Sendable {
  var avatarURL: String?
  var createdAt: ServerTimestamp
  var createdBy: UUID
  var icon: String?
  var id: UUID
  var isPublic: Bool
  var name: String
  var updatedAt: ServerTimestamp

  enum CodingKeys: String, CodingKey, CaseIterable {
    case icon, id, name
    case avatarURL = "avatar_url"
    case createdAt = "created_at"
    case createdBy = "created_by"
    case isPublic = "is_public"
    case updatedAt = "updated_at"
  }

  var model: Team {
    Team(
      id: id, name: name, icon: icon, avatarURL: avatarURL, isPublic: isPublic,
      createdBy: createdBy, createdAt: createdAt, updatedAt: updatedAt)
  }
}

struct UserSongSettingsRow: Codable, Sendable {
  var capo: Int
  var createdAt: ServerTimestamp
  var fontSize: Double?
  var id: UUID
  var songID: UUID
  var transpose: Int
  var updatedAt: ServerTimestamp
  var userID: UUID

  enum CodingKeys: String, CodingKey, CaseIterable {
    case capo, id, transpose
    case createdAt = "created_at"
    case fontSize = "font_size"
    case songID = "song_id"
    case updatedAt = "updated_at"
    case userID = "user_id"
  }

  var model: UserSongSettings {
    UserSongSettings(
      songID: songID, transpose: transpose, capo: capo, fontSize: fontSize, updatedAt: updatedAt)
  }

  static func upsertPayload(_ settings: UserSongSettings, userID: UserID) -> [String: JSONValue] {
    [
      "user_id": .string(userID.pg),
      "song_id": .string(settings.songID.pg),
      "transpose": .number(Double(settings.transpose)),
      "capo": .number(Double(settings.capo)),
      "font_size": settings.fontSize.map { .number($0) } ?? .null,
      "updated_at": .string((settings.updatedAt ?? .now()).raw)
    ]
  }
}

// MARK: - RPC and embed shapes

/// `team_members` with the embedded `profiles(full_name,email,avatar_url)` PostgREST returns as an
/// object or, when the relationship cardinality is ambiguous, a one-element array.
struct TeamMemberWithProfileRow: Decodable, Sendable {
  struct Profile: Decodable, Sendable {
    var fullName: String?
    var email: String?
    var avatarURL: String?
    enum CodingKeys: String, CodingKey {
      case email
      case fullName = "full_name"
      case avatarURL = "avatar_url"
    }
  }

  var member: TeamMemberRow
  var profile: Profile?

  enum CodingKeys: String, CodingKey { case profiles }

  init(from decoder: Decoder) throws {
    member = try TeamMemberRow(from: decoder)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let single = try? container.decodeIfPresent(Profile.self, forKey: .profiles) {
      profile = single
    } else if let many = try? container.decodeIfPresent([Profile].self, forKey: .profiles) {
      profile = many.first
    }
  }
}

/// `team_invitations` with `team:teams(name)` and `inviter:profiles(full_name,email)` embedded.
struct PendingInvitationRow: Decodable, Sendable {
  struct TeamName: Decodable, Sendable { var name: String }
  struct Inviter: Decodable, Sendable {
    var fullName: String?
    var email: String?
    enum CodingKeys: String, CodingKey {
      case email
      case fullName = "full_name"
    }
  }

  var invitation: TeamInvitationRow
  var team: TeamName?
  var inviter: Inviter?

  enum CodingKeys: String, CodingKey { case team, inviter }

  init(from decoder: Decoder) throws {
    invitation = try TeamInvitationRow(from: decoder)
    let container = try decoder.container(keyedBy: CodingKeys.self)
    team = Self.decodeOneOrMany(TeamName.self, container, .team)
    inviter = Self.decodeOneOrMany(Inviter.self, container, .inviter)
  }

  private static func decodeOneOrMany<T: Decodable>(
    _ type: T.Type, _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
  ) -> T? {
    if let single = try? container.decodeIfPresent(T.self, forKey: key) { return single }
    return (try? container.decodeIfPresent([T].self, forKey: key))?.first
  }

  var model: PendingInvitation {
    PendingInvitation(
      invitation: invitation.model, teamName: team?.name ?? "",
      inviterName: inviter.flatMap { $0.fullName ?? $0.email })
  }
}

/// `{id, version}` projection used by the version-diff queries.
struct VersionRow: Codable, Sendable {
  var id: UUID
  var updatedAt: ServerTimestamp

  enum CodingKeys: String, CodingKey, CaseIterable {
    case id
    case updatedAt = "updated_at"
  }
}

// MARK: - JSONValue helpers

extension JSONValue {
  static func optionalString(_ value: String?) -> JSONValue { value.map { .string($0) } ?? .null }
  static func optionalInt(_ value: Int?) -> JSONValue { value.map { .number(Double($0)) } ?? .null }
  static func optionalUUID(_ value: UUID?) -> JSONValue { value.map { .string($0.pg) } ?? .null }
  /// Empty string becomes NULL (web `value || null`).
  static func nonEmptyString(_ value: String) -> JSONValue { value.isEmpty ? .null : .string(value) }
}
