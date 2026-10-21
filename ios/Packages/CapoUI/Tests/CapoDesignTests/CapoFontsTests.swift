import Testing
import UIKit
@testable import CapoDesign

@MainActor
@Suite struct CapoFontsTests {
  @Test func bundledFontsResolveAfterRegistration() {
    #expect(CapoFonts.register())
    for name in [
      "Geist-Regular", "Geist-Medium", "Geist-SemiBold", "Geist-Bold", "GeistMono-Regular", "GeistMono-Bold"
    ] {
      #expect(UIFont(name: name, size: 16) != nil, "\(name) did not resolve")
    }
  }

  @Test func weightsMapToFaces() {
    #expect(CapoFont.postScriptName(.regular) == "Geist-Regular")
    #expect(CapoFont.postScriptName(.medium) == "Geist-Medium")
    #expect(CapoFont.postScriptName(.semibold) == "Geist-SemiBold")
    #expect(CapoFont.postScriptName(.bold) == "Geist-Bold")
    #expect(CapoFont.postScriptName(.bold, mono: true) == "GeistMono-Bold")
  }
}
