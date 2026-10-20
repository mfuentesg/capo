import CapoCore
import Foundation
import Network

/// `ReachabilityMonitor` backed by `NWPathMonitor`. Streams replay the latest known state and
/// only emit on change.
public final class NWReachabilityMonitor: ReachabilityMonitor {
  private let monitor = NWPathMonitor()
  private let subject = ValueSubject(false)

  public init() {
    let subject = subject
    monitor.pathUpdateHandler = { path in
      let online = path.status == .satisfied
      if subject.value != online { subject.send(online) }
    }
    monitor.start(queue: DispatchQueue(label: "capo.reachability"))
  }

  deinit { monitor.cancel() }

  public func isOnline() -> AsyncStream<Bool> {
    subject.stream()
  }
}
