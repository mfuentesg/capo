import AVFoundation
import Foundation
import Observation

/// Pure parts of chord playback, kept in step with `features/chord-audio` on the web.
public nonisolated enum ChordAudioMath {
  /// Seconds each note rings (`NOTE_DURATION`).
  public static let noteDuration = 1.5
  /// Delay between strings, low to high (`now + i * 0.025`).
  public static let stagger = 0.025
  /// How long the play button stays in its playing state (`PLAYING_INDICATOR_MS`).
  public static let playingIndicator = 1.5
  /// Standard tuning E2 A2 D3 G3 B3 E4, as `OPEN_STRING_MIDI` in `chord-diagram.tsx`.
  public static let openStringMIDI = [40, 45, 50, 55, 59, 64]

  private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

  /// Port of `midiToNote`: 60 -> "C4".
  public static func midiToNote(_ midi: Int) -> String {
    noteNames[midi % 12] + String(midi / 12 - 1)
  }

  public static func frequency(midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

  /// MIDI pitches of a fingering, low string first, muted strings skipped. Frets are relative to
  /// `baseFret`, exactly as the web derives `midi` from the diagram data.
  public static func midiNotes(for position: ChordPosition) -> [Int] {
    position.frets.enumerated().compactMap { index, fret in
      guard fret >= 0, index < openStringMIDI.count else { return nil }
      return openStringMIDI[index] + (fret == 0 ? 0 : fret + position.baseFret - 1)
    }
  }

  /// A plucked string (Karplus-Strong), so playback needs no downloaded samples and works offline.
  public static func pluck(frequency: Double, duration: Double, sampleRate: Double) -> [Float] {
    let count = Int(duration * sampleRate)
    let period = max(2, Int((sampleRate / frequency).rounded()))
    var seed: UInt64 = 0x9E37_79B9_7F4A_7C15 ^ UInt64(frequency * 1000)
    var ring = (0..<period).map { _ -> Float in
      seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Float(Int64(bitPattern: seed >> 11) % 2000) / 1000 - 1
    }
    var out = [Float](repeating: 0, count: count)
    var head = 0
    let fadeStart = Int(Double(count) * 0.85)
    for i in 0..<count {
      let next = (head + 1) % period
      let value = ring[head]
      ring[head] = 0.4985 * (value + ring[next])
      head = next
      let fade = i < fadeStart ? 1 : Float(count - i) / Float(count - fadeStart)
      out[i] = value * fade
    }
    return out
  }

  /// All notes mixed into one buffer, each starting `stagger` after the previous one.
  public static func mix(midi: [Int], sampleRate: Double) -> [Float] {
    let total = Int((noteDuration + stagger * Double(max(midi.count - 1, 0))) * sampleRate)
    var out = [Float](repeating: 0, count: total)
    let gain = 0.5 / Float(max(midi.count, 1)).squareRoot()
    for (i, note) in midi.enumerated() {
      let start = Int(Double(i) * stagger * sampleRate)
      let samples = pluck(frequency: frequency(midi: note), duration: noteDuration, sampleRate: sampleRate)
      for (j, sample) in samples.enumerated() where start + j < total { out[start + j] += sample * gain }
    }
    return out
  }
}

/// Plays a chord through `AVAudioEngine`. One shared instance, like the web's module-level sampler.
@Observable @MainActor
public final class ChordAudioPlayer {
  public static let shared = ChordAudioPlayer()

  public private(set) var isPlaying = false
  private var engine: AVAudioEngine?
  private var node: AVAudioPlayerNode?
  private var resetTask: Task<Void, Never>?

  public func play(_ midiNotes: [Int]) {
    guard !midiNotes.isEmpty else { return }
    let sampleRate = 44_100.0
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
    let samples = ChordAudioMath.mix(midi: midiNotes, sampleRate: sampleRate)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
    else { return }
    buffer.frameLength = AVAudioFrameCount(samples.count)
    samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }

    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      let engine = self.engine ?? AVAudioEngine()
      let node = self.node ?? AVAudioPlayerNode()
      if self.engine == nil {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.engine = engine
        self.node = node
      }
      if !engine.isRunning { try engine.start() }
      node.stop()
      node.scheduleBuffer(buffer, at: nil, options: .interrupts)
      node.play()
    } catch {
      isPlaying = false
      return
    }
    isPlaying = true
    resetTask?.cancel()
    resetTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(ChordAudioMath.playingIndicator))
      guard !Task.isCancelled else { return }
      self?.isPlaying = false
    }
  }

  public func stop() {
    node?.stop()
    resetTask?.cancel()
    isPlaying = false
  }
}
