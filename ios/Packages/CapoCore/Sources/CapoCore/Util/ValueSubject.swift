import Foundation
import os

/// A thread-safe current value that multicasts changes. Each `stream()` replays the current value first.
public final class ValueSubject<Value: Sendable>: Sendable {
  private struct State: Sendable {
    var value: Value
    var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
  }

  private let state: OSAllocatedUnfairLock<State>

  public init(_ initial: Value) {
    state = OSAllocatedUnfairLock(initialState: State(value: initial))
  }

  deinit {
    for continuation in state.withLock({ $0.continuations.values }) {
      continuation.finish()
    }
  }

  public var value: Value {
    state.withLock { $0.value }
  }

  public func send(_ value: Value) {
    let continuations = state.withLock { state in
      state.value = value
      return Array(state.continuations.values)
    }
    for continuation in continuations {
      continuation.yield(value)
    }
  }

  /// Applies `transform` atomically and broadcasts the result.
  public func update(_ transform: @Sendable (inout Value) -> Void) {
    let (value, continuations) = state.withLock { state in
      transform(&state.value)
      return (state.value, Array(state.continuations.values))
    }
    for continuation in continuations {
      continuation.yield(value)
    }
  }

  public func stream() -> AsyncStream<Value> {
    let id = UUID()
    let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let current = state.withLock { state in
      state.continuations[id] = continuation
      return state.value
    }
    continuation.yield(current)
    continuation.onTermination = { [weak self] _ in
      _ = self?.state.withLock { $0.continuations.removeValue(forKey: id) }
    }
    return stream
  }
}
