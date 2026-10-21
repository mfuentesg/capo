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
    .capoTheme()
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
      AddToPlaylistView(songIDs: pending.songIDs) { model.navigation.pendingAdd = nil }
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
      .badge(model.conflictCount)
      .tag(CompactTab.settings)
    }
    .tint(CapoTheme.primary)
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
  @AppStorage("capo.sidebar.collapsed") private var sidebarCollapsed = false
  @AppStorage("capo.split.layout") private var splitRaw = SplitLayout().rawValue

  private var split: Binding<SplitLayout> {
    Binding(
      get: { SplitLayout(rawValue: splitRaw) ?? SplitLayout() },
      set: { splitRaw = $0.rawValue })
  }

  var body: some View {
    HStack(spacing: 0) {
      SidebarView(model: model, collapsed: $sidebarCollapsed)
        .frame(width: SidebarMetrics.width(collapsed: sidebarCollapsed))
        .background(CapoTheme.sidebar.ignoresSafeArea())
        .overlay(alignment: .trailing) { CapoTheme.border.frame(width: 1).ignoresSafeArea() }
      mainArea
    }
    .animation(.snappy(duration: 0.28), value: sidebarCollapsed)
    .background(CapoTheme.background.ignoresSafeArea())
    .background { shortcuts }
  }

  /// Hidden buttons carrying the keyboard shortcuts.
  private var shortcuts: some View {
    Group {
      Button("") { sidebarCollapsed.toggle() }
        .keyboardShortcut("s", modifiers: [.command, .option])
      Button("") {
        var layout = split.wrappedValue
        layout.toggleList()
        withAnimation(.snappy(duration: 0.28)) { split.wrappedValue = layout }
      }
      .keyboardShortcut("l", modifiers: [.command, .option])
    }
    .opacity(0)
    .accessibilityHidden(true)
    .allowsHitTesting(false)
  }

  @ViewBuilder
  private var mainArea: some View {
    @Bindable var nav = model.navigation
    switch nav.sidebar ?? .library {
    case .library:
      ResizableSplit(layout: split, collapseLabel: ContextStrings.library) {
        NavigationStack { LibraryView(selection: $nav.songSelection) }
      } detail: {
        if let id = nav.songSelection {
          NavigationStack { SongPerformanceView(songID: id).id(id) }
        } else {
          placeholder("music.note", L10n.Ios.Shell.selectSong)
        }
      }
    case .setlists:
      ResizableSplit(layout: split, collapseLabel: ContextStrings.setlists) {
        NavigationStack { PlaylistsView(selection: $nav.playlistSelection) }
      } detail: {
        if let id = nav.playlistSelection {
          NavigationStack { PlaylistDetailView(playlistID: id).id(id) }
        } else {
          placeholder("list.bullet.rectangle", L10n.Ios.Shell.selectSetlist)
        }
      }
    case .teams: NavigationStack { TeamsView() }
    case .conflicts: NavigationStack { ConflictsView() }
    case .settings: NavigationStack { SettingsView() }
    }
  }

  private func placeholder(_ symbol: String, _ title: String) -> some View {
    EmptyStateView(title: title, message: nil, systemImage: symbol)
  }
}

/// List/detail split with a draggable handle and a collapsible list, like the web's `ResizablePanel`.
private struct ResizableSplit<List: View, Detail: View>: View {
  @Binding var layout: SplitLayout
  let collapseLabel: String
  @ViewBuilder let list: () -> List
  @ViewBuilder let detail: () -> Detail

  @State private var dragStartWidth: CGFloat?
  @State private var dragWidth: CGFloat?

  var body: some View {
    GeometryReader { proxy in
      let total = proxy.size.width
      let width = dragWidth ?? layout.listWidth(total: total)
      HStack(spacing: 0) {
        if !layout.isListCollapsed {
          list()
            .frame(width: width)
            .transition(.move(edge: .leading))
          handle(total: total, width: width)
        }
        detail()
          .frame(maxWidth: .infinity)
          .overlay(alignment: .leading) {
            if layout.isListCollapsed { expandTab }
          }
      }
      .animation(dragWidth == nil ? .snappy(duration: 0.28) : nil, value: layout)
    }
  }

  private func handle(total: CGFloat, width: CGFloat) -> some View {
    VStack(spacing: 10) {
      Capsule().fill(CapoTheme.subtext.opacity(0.6)).frame(width: 5, height: 44)
      Button {
        layout.toggleList()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(CapoTheme.subtext)
          .frame(width: 30, height: 30)
          .background(CapoTheme.card, in: Circle())
          .overlay(Circle().strokeBorder(CapoTheme.border, lineWidth: 1))
          .frame(width: CapoMetrics.minTouchTarget, height: CapoMetrics.minTouchTarget)
          .contentShape(Rectangle())
      }
      .accessibilityLabel(PanelStrings.collapseList)
    }
    .frame(width: 20)
    .background(alignment: .center) { CapoTheme.border.frame(width: 1) }
    .contentShape(Rectangle())
    .gesture(
      DragGesture(minimumDistance: 2, coordinateSpace: .global)
        .onChanged { value in
          let start = dragStartWidth ?? width
          dragStartWidth = start
          dragWidth = SplitLayout.clamp(start + value.translation.width, total: total)
        }
        .onEnded { _ in
          if let dragWidth { layout.setListWidth(dragWidth, total: total) }
          dragStartWidth = nil
          dragWidth = nil
        })
    .accessibilityElement(children: .contain)
    .accessibilityAdjustableAction { direction in
      let step: CGFloat = direction == .increment ? 40 : -40
      layout.setListWidth(width + step, total: total)
    }
  }

  private var expandTab: some View {
    Button {
      layout.toggleList()
    } label: {
      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(CapoTheme.subtext)
        .frame(width: 28, height: 72)
        .background(
          UnevenRoundedRectangle(bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
            .fill(CapoTheme.card)
        )
        .overlay(
          UnevenRoundedRectangle(bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
            .strokeBorder(CapoTheme.border, lineWidth: 1))
        .frame(width: 44, height: CapoMetrics.minTouchTarget + 24, alignment: .leading)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(PanelStrings.expandList)
  }
}

// MARK: - Sidebar

private struct SidebarView: View {
  let model: ShellModel
  @Binding var collapsed: Bool

  private static let items: [(SidebarItem, String)] = [
    (.library, "music.note.list"), (.setlists, "list.bullet.rectangle"), (.teams, "person.3"),
    (.conflicts, "exclamationmark.triangle"), (.settings, "gearshape")
  ]

  private func title(_ item: SidebarItem) -> String {
    switch item {
    case .library: ContextStrings.library
    case .setlists: ContextStrings.setlists
    case .teams: ContextStrings.teams
    case .conflicts: ContextStrings.conflicts
    case .settings: ContextStrings.settings
    }
  }

  var body: some View {
    VStack(spacing: collapsed ? 18 : 14) {
      header
      contextSwitcher
      if collapsed { CapoTheme.border.frame(width: 36, height: 1) }
      VStack(spacing: collapsed ? 12 : 4) {
        ForEach(Self.items, id: \.0) { item, symbol in
          navButton(item, symbol)
        }
      }
      Spacer(minLength: 0)
      footer
    }
    .padding(.horizontal, collapsed ? 14 : 16)
    .padding(.top, 20)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var toggleButton: some View {
    Button {
      collapsed.toggle()
    } label: {
      Image(systemName: "sidebar.leading")
        .font(.system(size: 20, weight: .semibold))
        .frame(width: collapsed ? 56 : CapoMetrics.minTouchTarget, height: collapsed ? 56 : CapoMetrics.minTouchTarget)
        .foregroundStyle(collapsed ? CapoTheme.onPrimary : CapoTheme.text)
        .background(
          collapsed ? CapoTheme.primary : Color.clear,
          in: RoundedRectangle(cornerRadius: CapoRadius.large, style: .continuous))
    }
    .accessibilityLabel(collapsed ? PanelStrings.expandSidebar : PanelStrings.collapseSidebar)
  }

  private var header: some View {
    HStack {
      if !collapsed {
        Text("Capo").font(.title2.weight(.bold)).foregroundStyle(CapoTheme.text)
        Spacer()
      }
      toggleButton
    }
  }

  private var contextSwitcher: some View {
    let teamName = model.contextStore.selectedTeam?.name
    let label = teamName ?? ContextStrings.personal
    let symbol = model.context.teamID == nil ? "person.fill" : "person.2.fill"
    return Menu {
      ContextRows(model: model)
      Divider()
      Button(ContextStrings.invitations, systemImage: "envelope") { model.navigation.showInvitations = true }
    } label: {
      if collapsed {
        Image(systemName: symbol)
          .font(.system(size: 22))
          .frame(width: 56, height: 56)
          .foregroundStyle(CapoTheme.text)
          .background(CapoTheme.card, in: Circle())
          .overlay(Circle().strokeBorder(CapoTheme.border, lineWidth: 1))
      } else {
        HStack(spacing: 10) {
          Image(systemName: symbol)
            .frame(width: 32, height: 32)
            .background(CapoTheme.surface, in: Circle())
          Text(label).font(.body.weight(.semibold)).lineLimit(1)
          Spacer(minLength: 0)
          Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(CapoTheme.subtext)
        }
        .foregroundStyle(CapoTheme.text)
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous)
            .strokeBorder(CapoTheme.border, lineWidth: 1))
      }
    }
    .accessibilityLabel(label)
  }

  private func navButton(_ item: SidebarItem, _ symbol: String) -> some View {
    let selected = (model.navigation.sidebar ?? .library) == item
    let badge = item == .conflicts ? model.conflictCount : 0
    return Button {
      model.navigation.sidebar = item
    } label: {
      if collapsed {
        Image(systemName: symbol)
          .font(.system(size: 22))
          .frame(width: 56, height: 56)
          .foregroundStyle(selected ? CapoTheme.primary : CapoTheme.subtext)
          .background(
            selected ? CapoTheme.primary.opacity(0.16) : Color.clear,
            in: RoundedRectangle(cornerRadius: CapoRadius.large, style: .continuous)
          )
          .overlay(alignment: .topTrailing) { badgeView(badge).offset(x: -6, y: 6) }
      } else {
        HStack(spacing: 12) {
          Image(systemName: symbol)
            .font(.system(size: 20))
            .frame(width: 28)
            .foregroundStyle(selected ? CapoTheme.primary : CapoTheme.subtext)
          Text(title(item)).font(.body.weight(selected ? .semibold : .medium))
          Spacer(minLength: 0)
          badgeView(badge)
        }
        .foregroundStyle(CapoTheme.text)
        .padding(.horizontal, 12)
        .frame(minHeight: 52)
        .background(
          selected ? CapoTheme.primary.opacity(0.16) : Color.clear,
          in: RoundedRectangle(cornerRadius: CapoRadius.medium, style: .continuous))
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title(item))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  @ViewBuilder
  private func badgeView(_ count: Int) -> some View {
    if count > 0 {
      Text("\(count)")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(CapoTheme.card)
        .padding(.horizontal, 5)
        .frame(minWidth: 18, minHeight: 18)
        .background(CapoTheme.destructive, in: Capsule())
    }
  }

  private var footer: some View {
    let status = model.syncStatus
    let healthy = status.phase == .idle && status.pendingOperations == 0 && status.conflicts == 0
    return VStack(spacing: 8) {
      if collapsed {
        Button { model.syncNow(.manual) } label: {
          Circle().fill(healthy ? CapoTheme.success : CapoTheme.warning).frame(width: 12, height: 12)
            .frame(width: CapoMetrics.minTouchTarget, height: CapoMetrics.minTouchTarget)
        }
        .accessibilityLabel(SyncStatusBadge.label(for: status))
      } else {
        HStack(spacing: 10) {
          SyncButton(model: model)
          VStack(alignment: .leading, spacing: 2) {
            Text(SyncStatusBadge.label(for: status))
              .font(.subheadline.weight(.semibold)).foregroundStyle(CapoTheme.text)
            if status.pendingOperations > 0 {
              Text("\(status.pendingOperations)")
                .font(.caption.monospacedDigit()).foregroundStyle(CapoTheme.subtext)
            }
          }
          Spacer(minLength: 0)
        }
      }
      Button {
        model.navigation.showSignOut = true
      } label: {
        Image(systemName: "rectangle.portrait.and.arrow.right")
      }
      .buttonStyle(CapoIconButtonStyle())
      .accessibilityLabel(ContextStrings.signOut)
    }
  }
}
