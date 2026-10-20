import CapoDesign
import SwiftUI
import UIKit

/// Drives a UIScrollView at a constant speed in px/s with CADisplayLink, stopping at the bottom
/// (use-auto-scroll.ts semantics: elapsed time times speed per frame).
final class AutoScrollController {
  weak var scrollView: UIScrollView?
  var speed: Double = Double(AutoScrollSpeed.fallback)
  var onStop: (() -> Void)?

  private var displayLink: CADisplayLink?
  private var lastTimestamp: CFTimeInterval?
  /// Sub-pixel remainder, so slow speeds still move on high refresh rate displays.
  private var position: Double = 0

  var isRunning: Bool { displayLink != nil }

  func start() {
    guard displayLink == nil, let scrollView else { return }
    if atBottom(scrollView) {
      onStop?()
      return
    }
    position = scrollView.contentOffset.y
    lastTimestamp = nil
    let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.tick(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  func stop() {
    displayLink?.invalidate()
    displayLink = nil
    lastTimestamp = nil
  }

  fileprivate func tick(_ link: CADisplayLink) {
    guard let scrollView else {
      stop()
      return
    }
    if atBottom(scrollView) {
      stop()
      onStop?()
      return
    }
    // The user may have dragged since the last frame.
    if abs(scrollView.contentOffset.y - position) >= 1 { position = scrollView.contentOffset.y }
    if let lastTimestamp {
      position += speed * (link.timestamp - lastTimestamp)
      let maxOffset = ScrollMath.maxOffset(
        viewport: scrollView.bounds.height, content: scrollView.contentSize.height)
      scrollView.contentOffset.y = min(position, maxOffset)
    }
    lastTimestamp = link.timestamp
  }

  private func atBottom(_ scrollView: UIScrollView) -> Bool {
    ScrollMath.isAtBottom(
      offset: scrollView.contentOffset.y, viewport: scrollView.bounds.height,
      content: scrollView.contentSize.height)
  }
}

/// CADisplayLink retains its target; the proxy keeps the controller free to deinit.
private final class DisplayLinkProxy: NSObject {
  weak var controller: AutoScrollController?
  init(_ controller: AutoScrollController) { self.controller = controller }

  @objc func tick(_ link: CADisplayLink) {
    guard let controller else {
      link.invalidate()
      return
    }
    controller.tick(link)
  }
}

/// Lets SwiftUI ask the scroll view to page.
final class PerformanceScrollProxy {
  fileprivate weak var controller: PerformanceScrollViewController?

  /// Pages down; returns false when already at the bottom.
  @discardableResult
  func pageDown() -> Bool { controller?.page(down: true) ?? false }

  @discardableResult
  func pageUp() -> Bool { controller?.page(down: false) ?? false }

  func scrollToTop() { controller?.scrollToTop() }
}

/// `UIScrollView` hosting the SwiftUI song content, with hardware key commands.
struct PerformanceScrollView<Content: View>: UIViewControllerRepresentable {
  let proxy: PerformanceScrollProxy
  let isAutoScrolling: Bool
  let speed: Int
  let onAction: (PerformanceAction) -> Void
  let onAutoScrollStopped: () -> Void
  let onContentMeasured: (Double) -> Void
  @ViewBuilder let content: () -> Content

  func makeUIViewController(context: Context) -> PerformanceScrollViewController {
    let controller = PerformanceScrollViewController(rootView: AnyView(content()))
    proxy.controller = controller
    update(controller)
    return controller
  }

  func updateUIViewController(_ controller: PerformanceScrollViewController, context: Context) {
    controller.setRootView(AnyView(content()))
    proxy.controller = controller
    update(controller)
  }

  private func update(_ controller: PerformanceScrollViewController) {
    controller.onAction = onAction
    controller.onContentMeasured = onContentMeasured
    controller.autoScroll.onStop = onAutoScrollStopped
    controller.autoScroll.speed = Double(speed)
    if isAutoScrolling { controller.autoScroll.start() } else { controller.autoScroll.stop() }
  }

  static func dismantleUIViewController(_ controller: PerformanceScrollViewController, coordinator: ()) {
    controller.autoScroll.stop()
  }
}

final class PerformanceScrollViewController: UIViewController {
  let scrollView = UIScrollView()
  let autoScroll = AutoScrollController()
  var onAction: ((PerformanceAction) -> Void)?
  var onContentMeasured: ((Double) -> Void)?

  private let hosting: UIHostingController<AnyView>
  private var lastReportedHeight: Double?

  init(rootView: AnyView) {
    hosting = UIHostingController(rootView: rootView)
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  override func viewDidLoad() {
    super.viewDidLoad()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    scrollView.keyboardDismissMode = .onDrag
    view.addSubview(scrollView)

    addChild(hosting)
    hosting.sizingOptions = .intrinsicContentSize
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(hosting.view)
    hosting.didMove(toParent: self)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
    ])
    autoScroll.scrollView = scrollView
  }

  func setRootView(_ rootView: AnyView) {
    hosting.rootView = rootView
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let scrollable = Double(scrollView.contentSize.height - scrollView.bounds.height)
    guard scrollView.contentSize.height > 0, scrollable != lastReportedHeight else { return }
    lastReportedHeight = scrollable
    onContentMeasured?(scrollable)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    autoScroll.stop()
  }

  // MARK: Paging

  func page(down: Bool) -> Bool {
    let offset = Double(scrollView.contentOffset.y)
    let viewport = Double(scrollView.bounds.height)
    let content = Double(scrollView.contentSize.height)
    if down, ScrollMath.isAtBottom(offset: offset, viewport: viewport, content: content) {
      return false
    }
    if !down, offset <= 0 { return false }
    let target =
      down
      ? ScrollMath.pageDown(offset: offset, viewport: viewport, content: content)
      : ScrollMath.pageUp(offset: offset, viewport: viewport)
    scrollView.setContentOffset(CGPoint(x: 0, y: target), animated: true)
    return true
  }

  func scrollToTop() {
    scrollView.setContentOffset(.zero, animated: false)
  }

  // MARK: Key commands

  override var canBecomeFirstResponder: Bool { true }

  override var keyCommands: [UIKeyCommand]? {
    PerformanceKeyMap.bindings.map { binding in
      let command = UIKeyCommand(
        title: PerformanceScrollViewController.title(for: binding.action),
        action: #selector(handleKeyCommand(_:)), input: binding.input)
      command.wantsPriorityOverSystemBehavior = true
      return command
    }
  }

  @objc private func handleKeyCommand(_ command: UIKeyCommand) {
    guard let input = command.input, let action = PerformanceKeyMap.action(for: input) else { return }
    onAction?(action)
  }

  static func title(for action: PerformanceAction) -> String {
    switch action {
    case .pageDown: return L10n.Ios.Performance.pageDown
    case .pageUp: return L10n.Ios.Performance.pageUp
    case .nextSong: return L10n.Ios.Performance.nextSong
    case .previousSong: return L10n.Ios.Performance.previousSong
    case .toggleAutoScroll: return L10n.Ios.Performance.toggleAutoScroll
    case .scrollSlower: return L10n.Ios.Performance.scrollSlower
    case .scrollFaster: return L10n.Ios.Performance.scrollFaster
    case .increaseFont: return L10n.Ios.Performance.increaseFont
    case .decreaseFont: return L10n.Ios.Performance.decreaseFont
    }
  }
}
