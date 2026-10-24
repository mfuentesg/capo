import CoreText
import Foundation
import SwiftUI
import UIKit
import os

/// One of the web's twelve selectable UI fonts (`lib/font.ts`, `palette-settings.tsx` `FONTS`). Lyrics and
/// chords always stay Geist Mono; only the interface text follows the selection.
public nonisolated struct CapoUIFont: Sendable, Equatable, Identifiable {
  /// How the weights of a family are bundled.
  public nonisolated enum Face: Sendable, Equatable {
    /// One static file per weight (weight -> PostScript name).
    case statics([Int: String])
    /// One variable file (PostScript name) driven through its `wght` axis.
    case variable(String)
  }

  public let id: String
  public let name: String
  /// Picker caption (web `FONTS[].desc`).
  public let summary: String
  public let face: Face

  /// OpenType `wght` axis tag (`'wght'`).
  static let weightAxis: Int = 0x7767_6874

  /// The static weight closest to `weight` (ties go to the heavier face, like CSS font matching).
  public func staticPostScriptName(weight: Int) -> String? {
    guard case .statics(let faces) = face else { return nil }
    let best = faces.keys.sorted { lhs, rhs in
      let dl = abs(lhs - weight), dr = abs(rhs - weight)
      return dl == dr ? lhs > rhs : dl < dr
    }.first
    return best.flatMap { faces[$0] }
  }

  /// The variable font's PostScript name, when this family is variable.
  public var variablePostScriptName: String? {
    if case .variable(let name) = face { return name }
    return nil
  }

  /// Every PostScript name the family needs registered.
  public var postScriptNames: [String] {
    switch face {
    case .statics(let faces): faces.values.sorted()
    case .variable(let name): [name]
    }
  }
}

nonisolated extension CapoUIFont {
  private static func variable(_ id: String, _ name: String, _ summary: String, ps: String) -> CapoUIFont {
    CapoUIFont(id: id, name: name, summary: summary, face: .variable(ps))
  }

  public nonisolated static let geist = CapoUIFont(
    id: "geist", name: "Geist", summary: "Clean & modern",
    face: .statics([
      400: "Geist-Regular", 500: "Geist-Medium", 600: "Geist-SemiBold", 700: "Geist-Bold"
    ]))
  public nonisolated static let inter = variable("inter", "Inter", "Versatile & readable", ps: "Inter-Variable")
  public nonisolated static let roboto = variable("roboto", "Roboto", "Material Design", ps: "Roboto-Variable")
  public nonisolated static let poppins = CapoUIFont(
    id: "poppins", name: "Poppins", summary: "Geometric & bold",
    face: .statics([
      400: "Poppins-Regular", 500: "Poppins-Medium", 600: "Poppins-SemiBold", 700: "Poppins-Bold"
    ]))
  public nonisolated static let nunito = variable("nunito", "Nunito", "Rounded & warm", ps: "Nunito-Variable")
  public nonisolated static let outfit = variable("outfit", "Outfit", "Sharp & minimal", ps: "Outfit-Variable")
  public nonisolated static let dmSans = variable("dm-sans", "DM Sans", "Soft & friendly", ps: "DMSans-Variable")
  public nonisolated static let plusJakartaSans = variable(
    "plus-jakarta-sans", "Plus Jakarta Sans", "Fresh & modern", ps: "PlusJakartaSans-Variable")
  public nonisolated static let montserrat = variable(
    "montserrat", "Montserrat", "Bold & geometric", ps: "Montserrat-Variable")
  public nonisolated static let lato = CapoUIFont(
    id: "lato", name: "Lato", summary: "Clean & classic",
    face: .statics([400: "Lato-Regular", 700: "Lato-Bold"]))
  public nonisolated static let spaceGrotesk = variable(
    "space-grotesk", "Space Grotesk", "Technical & distinct", ps: "SpaceGrotesk-Variable")
  public nonisolated static let manrope = variable("manrope", "Manrope", "Precise & modern", ps: "Manrope-Variable")

  /// The twelve fonts in the web picker's order (`palette-settings.tsx` `FONTS`).
  public nonisolated static let all: [CapoUIFont] = [
    .geist, .inter, .roboto, .poppins, .nunito, .outfit, .dmSans, .plusJakartaSans, .montserrat, .lato,
    .spaceGrotesk, .manrope
  ]

  public nonisolated static let `default`: CapoUIFont = .geist

  /// The font for a stored id; nil when unknown (callers fall back to Geist).
  public nonisolated static func named(_ id: String?) -> CapoUIFont? { all.first { $0.id == id } }
}

/// Process-wide current UI font, readable from any thread (fonts are built inside view bodies and cached
/// UIKit providers).
nonisolated enum CapoUIFontStorage {
  private static let lock = OSAllocatedUnfairLock(initialState: CapoUIFont.geist)

  static var current: CapoUIFont {
    get { lock.withLock { $0 } }
    set { lock.withLock { $0 = newValue } }
  }
}

/// Builds fonts for a `CapoUIFont`. CoreText descriptors are cached because list rows ask for the same
/// handful of (family, weight, size) combinations on every render.
nonisolated enum CapoUIFontFactory {
  private final class Cache: @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: CTFont] = [:]
    func font(for key: String, make: () -> CTFont) -> CTFont {
      lock.lock()
      defer { lock.unlock() }
      if let hit = store[key] { return hit }
      let made = make()
      store[key] = made
      return made
    }
  }
  private static let cache = Cache()

  static func numericWeight(_ weight: Font.Weight) -> Int {
    switch weight {
    case .ultraLight: 100
    case .thin: 200
    case .light: 300
    case .medium: 500
    case .semibold: 600
    case .bold: 700
    case .heavy: 800
    case .black: 900
    default: 400
    }
  }

  /// A variable-font instance at `weight` (clamped by the font to its axis range).
  static func variableFont(postScriptName: String, weight: Int, size: CGFloat) -> CTFont {
    cache.font(for: "\(postScriptName)|\(weight)|\(size)") {
      let attributes: [CFString: Any] = [
        kCTFontNameAttribute: postScriptName,
        kCTFontVariationAttribute: [CapoUIFont.weightAxis: weight]
      ]
      let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
      return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
  }
}
