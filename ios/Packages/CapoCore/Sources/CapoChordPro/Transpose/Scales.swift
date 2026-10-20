// Port of chordsheetjs 12.3.1 src/scales.ts and src/normalize_mappings/enharmonic-normalize.ts.

enum ChordType: Sendable {
  case symbol, solfege, numeric, numeral
}

enum Modifier: Sendable, Equatable {
  case sharp, flat

  var string: String { self == .sharp ? "#" : "b" }
}

/// `ModifierMaybe`: a modifier or `NO_MODIFIER` ("NM").
enum ModifierKey: Sendable {
  case none, sharp, flat

  init(_ modifier: Modifier?) {
    switch modifier {
    case .sharp: self = .sharp
    case .flat: self = .flat
    case nil: self = .none
    }
  }
}

enum Scales {
  private static let symbolToGrade: [ModifierKey: [String: Int]] = [
    .none: ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11],
    .sharp: ["B": 0, "C": 1, "D": 3, "E": 5, "F": 6, "G": 8, "A": 10],
    .flat: ["D": 1, "E": 3, "F": 4, "G": 6, "A": 8, "B": 10, "C": 11]
  ]
  private static let solfegeToGrade: [ModifierKey: [String: Int]] = [
    .none: ["Do": 0, "Re": 2, "Mi": 4, "Fa": 5, "Sol": 7, "La": 9, "Si": 11],
    .sharp: ["Si": 0, "Do": 1, "Re": 3, "Mi": 5, "Fa": 6, "Sol": 8, "La": 10],
    .flat: ["Re": 1, "Mi": 3, "Fa": 4, "Sol": 6, "La": 8, "Si": 10, "Do": 11]
  ]
  private static let numericMajorToGrade: [ModifierKey: [String: Int]] = [
    .none: ["1": 0, "2": 2, "3": 4, "4": 5, "5": 7, "6": 9, "7": 11],
    .sharp: ["7": 0, "1": 1, "2": 3, "3": 5, "4": 6, "5": 8, "6": 10],
    .flat: ["2": 1, "3": 3, "4": 4, "5": 6, "6": 8, "7": 10, "1": 11]
  ]
  private static let numericMinorToGrade: [ModifierKey: [String: Int]] = [
    .none: ["1": 0, "2": 2, "3": 3, "4": 5, "5": 7, "6": 8, "7": 10],
    .sharp: ["1": 1, "2": 3, "3": 4, "4": 6, "5": 8, "6": 9, "7": 11],
    .flat: ["2": 1, "3": 2, "4": 4, "5": 6, "6": 7, "7": 9, "1": 11]
  ]
  private static let numeralMajorToGrade: [ModifierKey: [String: Int]] = [
    .none: ["I": 0, "II": 2, "III": 4, "IV": 5, "V": 7, "VI": 9, "VII": 11],
    .sharp: ["VII": 0, "I": 1, "II": 3, "III": 5, "IV": 6, "V": 8, "VI": 10],
    .flat: ["II": 1, "III": 3, "IV": 4, "V": 6, "VI": 8, "VII": 10, "I": 11]
  ]
  private static let numeralMinorToGrade: [ModifierKey: [String: Int]] = [
    .none: ["I": 0, "II": 2, "III": 3, "IV": 5, "V": 7, "VI": 8, "VII": 10],
    .sharp: ["I": 1, "II": 3, "III": 4, "IV": 6, "V": 8, "VI": 9, "VII": 11],
    .flat: ["II": 1, "III": 2, "IV": 4, "V": 6, "VI": 7, "VII": 9, "I": 11]
  ]

  static func keyToGrade(_ type: ChordType, minor: Bool, _ modifier: ModifierKey) -> [String: Int] {
    switch type {
    case .symbol: return symbolToGrade[modifier]!
    case .solfege: return solfegeToGrade[modifier]!
    case .numeric: return (minor ? numericMinorToGrade : numericMajorToGrade)[modifier]!
    case .numeral: return (minor ? numeralMinorToGrade : numeralMajorToGrade)[modifier]!
    }
  }

  private static let symbolToKey: [ModifierKey: [Int: String]] = [
    .none: [0: "C", 2: "D", 4: "E", 5: "F", 7: "G", 9: "A", 11: "B"],
    .sharp: [0: "B#", 1: "C#", 3: "D#", 5: "E#", 6: "F#", 8: "G#", 10: "A#"],
    .flat: [1: "Db", 3: "Eb", 4: "Fb", 6: "Gb", 8: "Ab", 10: "Bb", 11: "Cb"]
  ]
  private static let solfegeToKey: [ModifierKey: [Int: String]] = [
    .none: [0: "Do", 2: "Re", 4: "Mi", 5: "Fa", 7: "Sol", 9: "La", 11: "Si"],
    .sharp: [0: "Si#", 1: "Do#", 3: "Re#", 5: "Mi#", 6: "Fa#", 8: "Sol#", 10: "La#"],
    .flat: [1: "Reb", 3: "Mib", 4: "Fab", 6: "Solb", 8: "Lab", 10: "Sib", 11: "Dob"]
  ]
  private static let numericMajorToKey: [ModifierKey: [Int: String]] = [
    .none: [0: "1", 2: "2", 4: "3", 5: "4", 7: "5", 9: "6", 11: "7"],
    .sharp: [0: "#7", 1: "#1", 3: "#2", 5: "#3", 6: "#4", 8: "#5", 10: "#6"],
    .flat: [1: "b2", 3: "b3", 4: "b4", 6: "b5", 8: "b6", 10: "b7", 11: "b1"]
  ]
  private static let numericMinorToKey: [ModifierKey: [Int: String]] = [
    .none: [0: "1", 2: "2", 3: "3", 5: "4", 7: "5", 8: "6", 10: "7"],
    .sharp: [1: "#1", 3: "#2", 4: "#3", 6: "#4", 8: "#5", 9: "#6", 11: "#7"],
    .flat: [1: "b2", 2: "b3", 4: "b4", 6: "b5", 7: "b6", 9: "b7", 11: "b1"]
  ]
  private static let numeralMajorToKey: [ModifierKey: [Int: String]] = [
    .none: [0: "I", 2: "II", 4: "III", 5: "IV", 7: "V", 9: "VI", 11: "VII"],
    .sharp: [0: "#VII", 1: "#I", 3: "#II", 5: "#III", 6: "#IV", 8: "#V", 10: "#VI"],
    .flat: [1: "bII", 3: "bIII", 4: "bIV", 6: "bV", 8: "bVI", 10: "bVII", 11: "bI"]
  ]
  private static let numeralMinorToKey: [ModifierKey: [Int: String]] = [
    .none: [0: "I", 2: "II", 3: "III", 5: "IV", 7: "V", 8: "VI", 10: "VII"],
    .sharp: [1: "#I", 3: "#II", 4: "#III", 6: "#IV", 8: "#V", 9: "#VI", 11: "#VII"],
    .flat: [1: "bII", 2: "bIII", 4: "bIV", 6: "bV", 7: "bVI", 9: "bVII", 11: "bI"]
  ]

  static func gradeToKey(_ type: ChordType, minor: Bool, _ modifier: ModifierKey) -> [Int: String] {
    switch type {
    case .symbol: return symbolToKey[modifier]!
    case .solfege: return solfegeToKey[modifier]!
    case .numeric: return (minor ? numericMinorToKey : numericMajorToKey)[modifier]!
    case .numeral: return (minor ? numeralMinorToKey : numeralMajorToKey)[modifier]!
    }
  }

  static let romanNumerals = ["I", "II", "III", "IV", "V", "VI", "VII"]

  static let enharmonics: [String: [String: String]] = [
    "Ab": ["B": "Cb"],
    "Cb": ["B": "Cb", "A#": "Bb", "E": "Fb"],
    "C": ["C#": "Db", "D#": "Eb", "F#": "Gb", "G#": "Ab", "A#": "Bb"],
    "C#": ["Eb": "D#", "Bb": "A#"],
    "Db": ["Cb": "B", "F#": "Gb", "G#": "Ab", "A#": "Bb"],
    "D": ["D#": "Eb", "A#": "Bb", "Gb": "F#"],
    "Eb": ["D#": "Eb", "F#": "Gb", "G#": "Ab", "A#": "Bb"],
    "E": ["Ab": "G#", "A#": "Bb", "D#": "Eb", "Db": "C#", "Eb": "D#"],
    "F": ["A#": "Bb", "F#": "Gb", "D#": "Eb", "G#": "Ab"],
    "F#": ["Bb": "A#", "Eb": "D#"],
    "Gb": ["A#": "Bb", "D#": "Eb", "G#": "Ab", "B": "Cb", "E": "Fb"],
    "G": ["A#": "Bb", "D#": "Eb", "G#": "Ab", "C#": "Db"],
    "G#": ["A#": "Bb", "D#": "Eb", "Cb": "B#"],
    "Am": ["G#": "Ab", "F#": "Gb", "C#": "Db", "D#": "Eb", "A#": "Bb"],
    "Bbm": ["Cb": "B", "Gb": "F#"],
    "Bm": ["A#": "Bb", "D#": "Eb"],
    "C#m": ["A#": "Bb", "D#": "Eb", "Gb": "F#"],
    "Cm": ["G#": "Ab", "A#": "Bb", "D#": "Eb", "F#": "Gb", "C#": "Db"],
    "Dm": ["A#": "Bb", "D#": "Eb", "F#": "Gb", "G#": "Ab", "C#": "Db"],
    "Em": ["A#": "Bb", "D#": "Eb", "C#": "Db"],
    "F#m": ["A#": "Bb", "D#": "Eb", "Gb": "F#", "Ab": "G#", "Db": "C#"],
    "Fm": ["G#": "Ab", "A#": "Bb", "D#": "Eb", "F#": "Gb", "C#": "Db"],
    "Gm": ["G#": "Ab", "A#": "Bb", "D#": "Eb", "C#": "Db", "F#": "Gb"],
    "G#m": ["Bb": "A#", "Eb": "D#"],
    "B": ["Eb": "D#"],
    "Lab": ["Si": "Dob"],
    "Dob": ["Si": "Dob", "La#": "Sib", "Mi": "Fab"],
    "Do": ["Do#": "Reb", "Re#": "Mib", "Fa#": "Solb", "Sol#": "Lab", "La#": "Sib"],
    "Do#": ["Mib": "Re#", "Sib": "La#"],
    "Reb": ["Si": "Dob", "Fa#": "Solb"],
    "Re": ["Re#": "Mib", "La#": "Sib", "Solb": "Fa#"],
    "Mib": ["Re#": "Mib", "Fa#": "Solb", "Sol#": "Lab", "La#": "Sib"],
    "Mi": ["Lab": "Sol#", "La#": "Sib", "Re#": "Mib", "Reb": "Do#", "Mib": "Re#"],
    "Fa": ["La#": "Sib", "Fa#": "Solb", "Re#": "Mib", "Sol#": "Lab"],
    "Fa#": ["Sib": "La#", "Mib": "Re#"],
    "Solb": ["La#": "Sib", "Re#": "Mib", "Sol#": "Lab", "Si": "Dob", "Mi": "Fab"],
    "Sol": ["La#": "Sib", "Re#": "Mib", "Sol#": "Lab", "Do#": "Reb"],
    "Sol#": ["La#": "Sib", "Re#": "Mib", "Dob": "Si#"],
    "Lam": ["Sol#": "Lab", "Fa#": "Solb", "Do#": "Reb", "Re#": "Mib", "La#": "Sib"],
    "Sibm": ["Dob": "Si", "Solb": "Fa#"],
    "Sim": ["La#": "Sib", "Re#": "Mib"],
    "Do#m": ["La#": "Sib", "Re#": "Mib", "Solb": "Fa#"],
    "Dom": ["Sol#": "Lab", "La#": "Sib", "Re#": "Mib", "Fa#": "Solb", "Do#": "Reb"],
    "Rem": ["La#": "Sib", "Re#": "Mib", "Fa#": "Solb", "Sol#": "Lab", "Do#": "Reb"],
    "Mim": ["La#": "Sib", "Re#": "Mib", "Do#": "Reb"],
    "Fa#m": ["La#": "Sib", "Re#": "Mib", "Solb": "Fa#", "Lab": "Sol#", "Reb": "Do#"],
    "Fam": ["Sol#": "Lab", "La#": "Sib", "Re#": "Mib", "Fa#": "Solb", "Do#": "Reb"],
    "Solm": ["Sol#": "Lab", "La#": "Sib", "Re#": "Mib", "Do#": "Reb", "Fa#": "Solb"],
    "Sol#m": ["Sib": "La#", "Mib": "Re#"],
    "Si": ["Mib": "Re#"]
  ]
}
