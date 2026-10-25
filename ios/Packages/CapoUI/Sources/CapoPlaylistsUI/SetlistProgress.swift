import Foundation

/// The segmented progress bar of a setlist run: played songs, the current one, what is left.
nonisolated enum SetlistProgress {
  enum Segment: Equatable { case done, current, upcoming }

  static func segments(index: Int, count: Int) -> [Segment] {
    guard count > 0 else { return [] }
    let current = SetlistMath.clamp(index, count: count)
    return (0..<count).map { $0 < current ? .done : ($0 == current ? .current : .upcoming) }
  }

  /// "D · 100 BPM" under the peeking next card; nil when neither is known.
  static func peekDetail(key: String?, bpm: Int?, bpmLabel: String) -> String? {
    var parts: [String] = []
    if let key, !key.isEmpty { parts.append(key) }
    if let bpm, bpm > 0 { parts.append("\(bpm) \(bpmLabel)") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}
