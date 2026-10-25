import CapoChordsUI
import CapoDesign
import CapoIcons
import CapoEditorUI
import CapoLibraryUI
import CapoPerformanceUI
import CapoPlaylistsUI
import CapoSettingsUI
import CapoTeamsUI
import SwiftUI

/// Signed-in shell, one layout at every size: slim top bar, one navigation stack per tab, bottom bar.
struct MainShellView: View {
  let model: ShellModel
  let onSignOut: (_ erase: Bool) -> Void

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var nav = model.navigation
    ShellContainer(model: model)
    .capoTheme()
    .id(model.context)
    .shellEnvironment(model)
    .task { await model.observeTeams() }
    .task { await model.observeSync() }
    .task { await model.observeConflicts() }
    .task { await model.observeFailedOperations() }
    .task(id: model.context) { await model.observeSongCount() }
    .task { await model.observePreferences() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { model.syncNow(.foreground) }
    }
    .sheet(item: $nav.editor) { item in
      SongEditorView(request: item.request) { id in
        model.navigation.editor = nil
        if let id { model.navigation.openSong(id) }
      }
      .shellEnvironment(model)
    }
    .fullScreenCover(item: $nav.setlistRun) { run in
      SetlistPerformanceView(playlistID: run.playlistID, startIndex: run.startIndex) {
        model.navigation.setlistRun = nil
      }
      .shellEnvironment(model)
    }
    .sheet(item: $nav.pendingAdd) { _ in
      AddToPlaylistView { model.navigation.pendingAdd = nil }
        .shellEnvironment(model)
    }
    .sheet(item: $nav.pendingShare) { share in
      PlaylistShareSheet(playlistID: share.playlistID).shellEnvironment(model)
    }
    .sheet(isPresented: $nav.showConflicts) {
      NavigationStack {
        ConflictsView().toolbar { doneButton { model.navigation.showConflicts = false } }
      }
      .shellEnvironment(model)
    }
    .sheet(isPresented: $nav.showSettings) {
      NavigationStack {
        SettingsView().toolbar { doneButton { model.navigation.showSettings = false } }
      }
      .shellEnvironment(model)
    }
    .sheet(isPresented: $nav.showInvitations) {
      NavigationStack {
        PendingInvitationsView().toolbar { doneButton { model.navigation.showInvitations = false } }
      }
      .shellEnvironment(model)
    }
    .confirmationDialog(
      L10n.Ios.Shell.SignOut.title,
      isPresented: $nav.showSignOut, titleVisibility: .visible
    ) {
      Button(L10n.Ios.Shell.SignOut.keep) {
        onSignOut(false)
      }
      Button(L10n.Ios.Shell.SignOut.erase, role: .destructive) {
        onSignOut(true)
      }
      Button(L10n.Ios.Shell.cancel, role: .cancel) {}
    } message: {
      Text(signOutMessage)
    }
  }

  private var signOutMessage: String {
    let pending = model.syncStatus.pendingOperations
    guard pending > 0 else {
      return L10n.Ios.Shell.SignOut.message
    }
    return L10n.Ios.Shell.SignOut.pending(count: String(pending))
  }

  private func doneButton(_ action: @escaping () -> Void) -> some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) {
      Button(ContextStrings.done, action: action)
    }
  }
}

// MARK: - Container

/// Top bar, tab content and bottom bar. Both bars hide while a song is full screen on stage.
private struct ShellContainer: View {
  let model: ShellModel
  private let stage = AppFullscreen.shared
  /// Tabs shown at least once stay alive, so their search, filters and scroll position survive a switch.
  @State private var visited: Set<ShellTab> = [.songs]

  var body: some View {
    VStack(spacing: 0) {
      if !stage.isActive { ShellTopBar(model: model).transition(.move(edge: .top)) }
      tabs
      if !stage.isActive { ShellBottomBar(navigation: model.navigation).transition(.move(edge: .bottom)) }
    }
    .animation(.snappy(duration: 0.28), value: stage.isActive)
    .background(CapoTheme.background.ignoresSafeArea())
    .background { shortcuts }
    .onChange(of: model.navigation.destination, initial: true) { _, tab in visited.insert(tab) }
  }

  private var tabs: some View {
    @Bindable var nav = model.navigation
    return ZStack {
      ForEach(ShellTab.allCases, id: \.self) { tab in
        if visited.contains(tab) {
          let selected = nav.destination == tab
          root(tab)
            .opacity(selected ? 1 : 0)
            .allowsHitTesting(selected)
            .accessibilityHidden(!selected)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private func root(_ tab: ShellTab) -> some View {
    @Bindable var nav = model.navigation
    switch tab {
    case .songs:
      NavigationStack(path: $nav.songPath) {
        LibraryView()
          .navigationDestination(for: SongID.self) { id in SongPerformanceView(songID: id).id(id) }
      }
    case .playlists:
      NavigationStack(path: $nav.playlistPath) {
        PlaylistsView { id in model.navigation.openPlaylist(id) }
          .navigationDestination(for: PlaylistID.self) { id in PlaylistDetailView(playlistID: id).id(id) }
      }
    case .chords:
      NavigationStack { ChordsView().toolbar(.hidden, for: .navigationBar) }
    case .teams:
      NavigationStack { TeamsView().toolbar(.hidden, for: .navigationBar) }
    }
  }

  /// Hidden buttons carrying the keyboard shortcuts: Command-1...4 switch tabs.
  private var shortcuts: some View {
    Group {
      ForEach(Array(ShellTab.allCases.enumerated()), id: \.element) { index, tab in
        Button("") { model.navigation.open(tab) }
          .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
      }
    }
    .opacity(0)
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }
}

// MARK: - Top bar

/// 56 pt bar: wordmark on the left; sync state, context pill and account menu on the right.
private struct ShellTopBar: View {
  let model: ShellModel

  var body: some View {
    let status = model.syncStatus
    let healthy = status.phase == .idle && status.pendingOperations == 0 && status.conflicts == 0
    HStack(spacing: 4) {
      CapoLogo(height: 24)
      Spacer(minLength: 8)
      if !healthy { SyncButton(model: model) }
      ContextPill(model: model)
      AvatarMenu(model: model)
    }
    .padding(.horizontal, 16)
    .frame(height: ShellMetrics.topBarHeight)
    .background(CapoTheme.background.ignoresSafeArea(edges: .top))
    .overlay(alignment: .bottom) { CapoTheme.border.opacity(0.4).frame(height: 1) }
  }
}

enum ShellMetrics {
  static let topBarHeight: CGFloat = 56
}

// MARK: - Bottom bar

/// Songs, Playlists, Chords, Teams. iPad: centred pills with icon and label side by side;
/// iPhone: four equal items with the label under the icon. Active tab = primary tint.
private struct ShellBottomBar: View {
  let navigation: ShellNavigation
  @Environment(\.horizontalSizeClass) private var sizeClass

  private var wide: Bool { sizeClass == .regular }

  var body: some View {
    HStack(spacing: wide ? 8 : 0) {
      ForEach(ShellTab.allCases, id: \.self) { tab in item(tab) }
    }
    .padding(.horizontal, wide ? 16 : 8)
    .padding(.top, wide ? 8 : 6)
    .padding(.bottom, wide ? 8 : 4)
    .frame(maxWidth: .infinity)
    .background(CapoTheme.background.ignoresSafeArea(edges: .bottom))
    .overlay(alignment: .top) { CapoTheme.border.opacity(0.4).frame(height: 1) }
  }

  private func item(_ tab: ShellTab) -> some View {
    let selected = navigation.destination == tab
    return Button { navigation.open(tab) } label: {
      Group {
        if wide {
          HStack(spacing: 8) {
            CapoIcon(tab.icon, size: 20)
            Text(tab.title).capoText(.sm, weight: .medium)
          }
          .padding(.horizontal, 22)
          .frame(height: 44)
        } else {
          VStack(spacing: 3) {
            CapoIcon(tab.icon, size: 22)
            Text(tab.title).capoText(.px11, weight: .semibold)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 52)
        }
      }
      .foregroundStyle(selected ? CapoTheme.primary : CapoTheme.mutedForeground)
      .background(selected ? CapoTheme.primary.opacity(0.14) : Color.clear, in: Capsule())
      .contentShape(Capsule())
      .padding(.horizontal, wide ? 0 : 6)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(tab.title)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
