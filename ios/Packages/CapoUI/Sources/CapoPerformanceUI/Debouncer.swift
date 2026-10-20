/// Runs only the last scheduled action, `delay` after the last call. `flush()` runs a pending
/// action right away (used when the screen goes away so no change is lost).
final class Debouncer {
  typealias Sleep = @Sendable (Duration) async throws -> Void

  private let delay: Duration
  private let sleep: Sleep
  private var task: Task<Void, Never>?
  private var pending: (() async -> Void)?

  init(delay: Duration, sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
    self.delay = delay
    self.sleep = sleep
  }

  var hasPending: Bool { pending != nil }

  func schedule(_ action: @escaping () async -> Void) {
    task?.cancel()
    pending = action
    task = Task { [weak self, delay, sleep] in
      do { try await sleep(delay) } catch { return }
      await self?.runPending()
    }
  }

  func flush() async {
    task?.cancel()
    task = nil
    await runPending()
  }

  func cancel() {
    task?.cancel()
    task = nil
    pending = nil
  }

  private func runPending() async {
    guard let action = pending else { return }
    pending = nil
    await action()
  }
}
