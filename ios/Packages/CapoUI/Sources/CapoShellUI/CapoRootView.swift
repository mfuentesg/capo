import CapoAuthUI
import CapoDesign
import SwiftUI

/// App root: configuration check, then auth, then the main shell.
public struct CapoRootView: View {
  @State private var store: SessionStore

  public init(dependencies: AppDependencies) {
    CapoFonts.register()
    _store = State(initialValue: SessionStore(dependencies: dependencies))
  }

  public var body: some View {
    Group {
      if store.dependencies.config == nil && !store.dependencies.isDemo {
        ConfigurationMissingView {
          store = SessionStore(dependencies: DemoSupport.dependencies)
        }
      } else {
        content
      }
    }
    .task(id: ObjectIdentifier(store)) {
      guard store.dependencies.config != nil || store.dependencies.isDemo else { return }
      await store.run()
    }
  }

  @ViewBuilder
  private var content: some View {
    switch store.phase {
    case .loading:
      ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
    case .signedOut:
      AuthView().environment(\.authActions, store.authActions)
    case .ready(let active):
      SignedInView(store: store, active: active)
    case .failed(let message):
      VStack(spacing: 16) {
        EmptyStateView(
          title: L10n.Ios.Shell.failed,
          message: message, systemImage: "exclamationmark.triangle")
        Button(L10n.Ios.Shell.retry) {
          Task { await store.retry() }
        }
        .buttonStyle(.borderedProminent)
        Button(ContextStrings.signOut, role: .destructive) { Task { await store.signOut(erase: false) } }
      }
    }
  }
}

/// Holds the per-user `ShellModel` for the lifetime of one signed-in user.
private struct SignedInView: View {
  let store: SessionStore
  let active: SessionStore.Active
  @State private var model: ShellModel

  init(store: SessionStore, active: SessionStore.Active) {
    self.store = store
    self.active = active
    let settings = ShellSettings.context(
      session: active.session, services: active.services, config: store.dependencies.config,
      isDemo: store.dependencies.isDemo,
      signOut: { erase in Task { await store.signOut(erase: erase) } })
    _model = State(
      initialValue: ShellModel(
        session: active.session, services: active.services, settingsContext: settings))
  }

  var body: some View {
    MainShellView(model: model) { erase in
      Task { await store.signOut(erase: erase) }
    }
    .capoToast(Binding(get: { store.errorMessage }, set: { store.errorMessage = $0 }))
  }
}

private struct ConfigurationMissingView: View {
  let useDemo: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      EmptyStateView(
        title: L10n.Ios.Shell.Config.title,
        message: L10n.Ios.Shell.Config.message,
        systemImage: "gearshape.2")
      Button(action: useDemo) {
        Text(L10n.Ios.Shell.Config.demo)
          .font(CapoFont.style(.headline))
          .frame(minHeight: CapoMetrics.minTouchTarget)
          .padding(.horizontal, 24)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding()
  }
}
