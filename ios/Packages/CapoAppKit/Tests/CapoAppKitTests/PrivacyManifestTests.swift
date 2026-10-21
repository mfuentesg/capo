import Foundation
import Testing

/// Guards `ios/Capo/Capo/PrivacyInfo.xcprivacy`: valid plist, no tracking, UserDefaults reason declared.
@Suite struct PrivacyManifestTests {
  private func manifest() throws -> [String: Any] {
    // .../ios/Packages/CapoAppKit/Tests/CapoAppKitTests/<file> -> .../ios
    let ios = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: ios.appendingPathComponent("Capo/Capo/PrivacyInfo.xcprivacy"))
    return try #require(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
  }

  @Test func declaresNoTracking() throws {
    let plist = try manifest()
    #expect(plist["NSPrivacyTracking"] as? Bool == false)
    #expect((plist["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
  }

  @Test func declaresUserDefaultsReason() throws {
    let types = try #require(try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
    let defaults = types.first {
      $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
    }
    #expect(defaults?["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
  }
}
