import Foundation

/// The landing/feedback form of the web (`features/feedback`): optional name and email, a message of
/// 5-5000 characters (trimmed) and a newsletter opt-in. Limits mirror the server action's zod schema.
public struct FeedbackDraft: Hashable, Sendable {
  public static let nameLimit = 100
  public static let emailLimit = 254
  public static let messageRange = 5...5000

  public var name = ""
  public var email = ""
  public var message = ""
  public var newsletterOptIn = false

  public init(name: String = "", email: String = "", message: String = "", newsletterOptIn: Bool = false) {
    self.name = name
    self.email = email
    self.message = message
    self.newsletterOptIn = newsletterOptIn
  }

  public enum Problem: Hashable, Sendable { case messageTooShort, messageTooLong, nameTooLong, invalidEmail }

  public var trimmedMessage: String { message.trimmingCharacters(in: .whitespacesAndNewlines) }
  public var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  public var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

  /// First problem found, nil when the draft can be sent.
  public var problem: Problem? {
    if trimmedMessage.count < Self.messageRange.lowerBound { return .messageTooShort }
    if trimmedMessage.count > Self.messageRange.upperBound { return .messageTooLong }
    if trimmedName.count > Self.nameLimit { return .nameTooLong }
    if !trimmedEmail.isEmpty, !Self.isEmail(trimmedEmail) { return .invalidEmail }
    return nil
  }

  static func isEmail(_ value: String) -> Bool {
    guard value.count <= emailLimit else { return false }
    let parts = value.split(separator: "@", omittingEmptySubsequences: false)
    return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
      && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".") && !value.contains(" ")
  }
}
