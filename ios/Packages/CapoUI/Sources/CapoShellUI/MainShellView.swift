import CapoDesign
import CapoEditorUI
import CapoLibraryUI
import CapoPerformanceUI
import CapoPlaylistsUI
import CapoSettingsUI
import CapoTeamsUI
import SwiftUI

/// Signed-in shell: sidebar split view on regular width, tab bar on compact width.
struct MainShellView: View {
  let model: ShellModel
  let onSignOut: (_ erase: Bool) -> Void

  @Environment(\.horizontalSizeClass) private var sizeClass
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    @Bindable var nav = model.navigation
    Group {
      if sizeClass == .regular {
        RegularShell(model: model)
      } else {
        CompactShell(model: model)
      }
    }
    .id(model.context)
    .shellEnvironment(model)
    .task { await model.observeTeams() }
    .task { await model.observeSync() }
    .task { await model.observeConflicts() }
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
    .sheet(item: $nav.pendingAdd) { pending in
      AddToSetlistSheet(songIDs: pending.songIDs).shellEnvironment(model)
    }
    .sheet(isPresented: $nav.showConflicts) {
      NavigationStack {
        ConflictsView().toolbar { doneButton { model.navigation.showConflicts = false } }
      }
      .shellEnvironment(model)
    }
    .sheet(isPresented: $nav.showTeams) {
      NavigationStack {
        TeamsView().toolbar { doneButton { model.navigation.showTeams = false } }
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
      String(localized: "ios.shell.signOut.title", defaultValue: "Sign out of Capo?", bundle: .capoDesign),  // TODO(i18n)
      isPresented: $nav.showSignOut, titleVisibility: .visible
    ) {
      Button(String(localized: "ios.shell.signOut.keep", defaultValue: "Sign out and keep offline data", bundle: .capoDesign)) {  // TODO(i18n)
        onSignOut(false)
      }
      Button(String(localized: "ios.shell.signOut.erase", defaultValue: "Sign out and erase offline data", bundle: .capoDesign), role: .destructive) {  // TODO(i18n)
        onSignOut(true)
      }
      Button(String(localized: "ios.shell.cancel", defaultValue: "Cancel", bundle: .capoDesign), role: .cancel) {}  // TODO(i18n)
    } message: {
      Text(signOutMessage)
    }
  }

  private var signOutMessage: String {
    let pending = model.syncStatus.pendingOperations
    guard pending > 0 else {
      return String(localized: "ios.shell.signOut.message", defaultValue: "Erasing removes the songs stored on this device.", bundle: .capoDesign)  // TODO(i18n)
    }
    return String(
      format: String(localized: "ios.shell.signOut.pending", defaultValue: "%d changes have not synced yet and will be lost if you erase offline data.", bundle: .capoDesign),  // TODO(i18n)
      pending)
  }

  private func doneButton(_ action: @escaping () -> Void) -> some ToolbarContent {
    ToolbarItem(placement: .confirmationAction) {
      Button(ContextStrings.done, action: action)
    }
  }
}

// MARK: - Compact

private struct CompactShell: View {
  let model: ShellModel

  var body: some View {
    @Bindable var nav = model.navigation
    TabView(selection: $nav.tab) {
      NavigationStack {
        LibraryView(selection: $nav.songSelection)
          .toolbar { shellToolbar }
          .navigationDestination(item: $nav.songSelection) { id in
            SongPerformanceView(songID: id).id(id)
          }
      }
      .tabItem { Label(ContextStrings.library, systemImage: "music.note.list") }
      .tag(CompactTab.library)

      NavigationStack {
        PlaylistsView(selection: $nav.playlistSelection)
          .toolbar { shellToolbar }
          .navigationDestination(item: $nav.playlistSelection) { id in
            PlaylistDetailView(playlistID: id).id(id)
          }
      }
      .tabItem { Label(ContextStrings.setlists, systemImage: "list.bullet.rectangle") }
      .tag(CompactTab.setlists)

      NavigationStack {
        SettingsView().toolbar { shellToolbar }
      }
      .tabItem { Label(ContextStrings.settings, systemImage: "gearshape") }
      .tag(CompactTab.settings)
    }
  }

  @ToolbarContentBuilder
  private var shellToolbar: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) { ContextPill(model: model) }
    ToolbarItem(placement: .topBarTrailing) { SyncButton(model: model) }
  }
}

// MARK: - Regular

private struct RegularShell: View {
  let model: ShellModel
  @State private var visibility: NavigationSplitViewVisibility = .all

  var body: some View {
    @Bindable var nav = model.navigation
    NavigationSplitView(columnVisibility: $visibility) {
      SidebarView(model: model)
    } content: {
      switch nav.sidebar ?? .library {
      case .library: LibraryView(selection: $nav.songSelection)
      case .setlists: PlaylistsView(selection: $nav.playlistSelection)
      case .teams: TeamsView()
      case .conflicts: ConflictsView()
      case .settings: SettingsView()
      }
    } detail: {
      detail
    }
    .navigationSplitViewStyle(.balanced)
  }

  @ViewBuilder
  private var detail: some View {
    let nav = model.navigation
    switch nav.sidebar ?? .library {
    case .library:
      if let id = nav.songSelection {
        NavigationStack { SongPerformanceView(songID: id).id(id) }
      } else {
        placeholder("music.note", String(localized: "ios.shell.selectSong", defaultValue: "Select a song", bundle: .capoDesign))  // TODO(i18n)
      }
    case .setlists:
      if let id = nav.playlistSelection {
        NavigationStack { PlaylistDetailView(playlistID: id).id(id) }
      } else {
        placeholder("list.bullet.rectangle", String(localized: "ios.shell.selectSetlist", defaultValue: "Select a setlist", bundle: .capoDesign))  // TODO(i18n)
      }
    case .teams, .conflicts, .settings:
      placeholder("guitars", "Capo")
    }
  }

  private func placeholder(_ symbol: String, _ title: String) -> some View {
    EmptyStateView(title: title, message: nil, systemImage: symbol)
  }
}

private struct SidebarView: View {
  let model: ShellModel

  var body: some View {
    @Bindable var nav = model.navigation
    List(selection: $nav.sidebar) {
      Section {
        ContextRows(model: model)
      } header: {
        Text(String(localized: "ios.shell.context", defaultValue: "Library", bundle: .capoDesign))  // TODO(i18n)
      }
      Section {
        row(.library, ContextStrings.library, "music.note.list")
        row(.setlists, ContextStrings.setlists, "list.bullet.rectangle")
        row(.teams, ContextStrings.teams, "person.3")
        row(.conflicts, ContextStrings.conflicts, "exclamationmark.triangle", badge: model.conflictCount)
        row(.settings, ContextStrings.settings, "gearshape")
      }
    }
    .navigationTitle("Capo")
    .safeAreaInset(edge: .bottom) { footer }
  }

  private func row(_ item: SidebarItem, _ title: String, _ symbol: String, badge: Int = 0) -> some View {
    Label(title, systemImage: symbol)
      .badge(badge)
      .frame(minHeight: CapoMetrics.minTouchTarget - 8)
      .tag(item)
  }

  private var footer: some View {
    HStack {
      SyncButton(model: model)
      Text(SyncStatusBadge.label(for: model.syncStatus))
        .font(.footnote)
        .foregroundStyle(.secondary)
      Spacer()
      Button {
        model.navigation.showSignOut = true
      } label: {
        Image(systemName: "rectangle.portrait.and.arrow.right")
          .frame(minWidth: CapoMetrics.minTouchTarget, minHeight: CapoMetrics.minTouchTarget)
      }
      .accessibilityLabel(ContextStrings.signOut)
    }
    .padding(.horizontal, 8)
    .background(.bar)
  }
}
