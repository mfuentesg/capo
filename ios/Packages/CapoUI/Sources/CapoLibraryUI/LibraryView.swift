import CapoDesign
import CapoIcons
import SwiftUI

/// Searchable, filterable song library (web `songs-client.tsx`). Works in a split-view content
/// column or a compact stack.
public struct LibraryView: View {
  @Binding var selection: SongID?
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.currentTeamRole) private var role
  @Environment(\.capoActions) private var actions
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var model = LibraryModel()
  @State private var showTagManagement = false
  @State private var assignTagsFor: SongSheetTarget?

  public init(selection: Binding<SongID?>) { _selection = selection }

  private var canEdit: Bool { role?.canEditContent ?? true }
  private var isRegular: Bool { sizeClass == .regular }

  public var body: some View {
    @Bindable var model = model
    VStack(spacing: 0) {
      LibraryHeader(
        model: model, canEdit: canEdit, isRegular: isRegular,
        onAdd: { actions.openEditor(.create) }, onManageTags: { showTagManagement = true })
      songList
    }
    .background(CapoTheme.background)
    .overlay { emptyState }
    .safeAreaInset(edge: .bottom, spacing: 0) { cartBar }
    .refreshable { await services.sync.syncNow(reason: .manual) }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(isRegular ? .hidden : .automatic, for: .navigationBar)
    .sheet(isPresented: $showTagManagement) {
      TagManagementView(tags: model.tags).presentationDetents([.medium, .large])
    }
    .sheet(item: $assignTagsFor) { target in
      AssignTagsView(songID: target.id, allTags: model.tags).presentationDetents([.medium, .large])
    }
    .task(id: model.searchInput) { await model.commitSearchAfterDebounce() }
    .task(id: model.query(context: context)) {
      for await items in services.songs.songs(model.query(context: context)) {
        model.songs = items
        model.hasLoaded = true
      }
    }
    .task(id: context) {
      for await tags in services.tags.tags(in: context) { model.tags = tags }
    }
    .task {
      for await teams in services.teams.teams() {
        model.teams = teams.map(\.team).sorted {
          $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
      }
    }
  }

  // MARK: List

  private var songList: some View {
    let groups = SongGrouping.groups(model.songs, by: model.filters.grouping)
    return List(selection: $selection) {
      ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
        if let title = group.title {
          Section {
            rows(group.items)
          } header: {
            Text(title)
              .capoText(.sm, weight: .semibold)
              .foregroundStyle(CapoTheme.mutedForeground)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
              .background(CapoTheme.background)
              .textCase(nil)
          }
        } else {
          rows(group.items)
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }

  @ViewBuilder
  private func rows(_ items: [SongListItem]) -> some View {
    ForEach(items) { item in
      SongRow(
        item: item, isSelected: selection == item.id, inCart: model.cart.contains(item.id),
        ownership: model.ownership(for: item, in: context),
        onToggleCart: { model.toggleCart(item.id) }
      )
      .tag(item.id)
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
      .swipeActions(edge: .trailing) {
        Button { actions.addSongsToPlaylist([item.id]) } label: {
          CapoIconLabel(LibraryStrings.addToSetlist, icon: .listMusic)
        }
        .tint(CapoTheme.accentPlaylists)
      }
      .swipeActions(edge: .leading) {
        if canEdit {
          Button { assignTagsFor = SongSheetTarget(id: item.id) } label: {
            CapoIconLabel(LibraryStrings.assignTags, icon: .tag)
          }
          .tint(CapoTheme.chord)
        }
      }
      .contextMenu {
        Button { actions.addSongsToPlaylist([item.id]) } label: {
          CapoIconLabel(LibraryStrings.addToSetlist, icon: .listMusic)
        }
        if canEdit {
          Button { assignTagsFor = SongSheetTarget(id: item.id) } label: {
            CapoIconLabel(LibraryStrings.assignTags, icon: .tag)
          }
          Button { actions.openEditor(.edit(item.id)) } label: {
            CapoIconLabel(LibraryStrings.editSong, icon: .pencil)
          }
        }
      }
    }
  }

  // MARK: Cart

  /// The web's draft indicator: appears once songs are queued, opens the add-to-playlist flow.
  @ViewBuilder private var cartBar: some View {
    if !model.cart.isEmpty {
      HStack(spacing: 4) {
        Button {
          actions.addSongsToPlaylist(model.cart)
          model.cart = []
        } label: {
          HStack(spacing: 8) {
            CapoIcon(.listMusic, size: 16)
            Text(LibraryStrings.cartAdd(model.cart.count)).capoText(.sm, weight: .medium)
          }
          .padding(.leading, 16).padding(.trailing, 8)
          .frame(minHeight: CapoMetrics.minHitTarget)
          .contentShape(Rectangle())
        }
        Button { model.cart = [] } label: {
          CapoIcon(.x, size: 14)
            .frame(width: CapoMetrics.minHitTarget, height: CapoMetrics.minHitTarget)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(LibraryStrings.clearCart)
      }
      .buttonStyle(.plain)
      .foregroundStyle(Color.white)
      .background(CapoTheme.accentPlaylists, in: Capsule())
      .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
      .padding(.bottom, 12)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  // MARK: Empty

  @ViewBuilder private var emptyState: some View {
    if model.hasLoaded && model.songs.isEmpty {
      LibraryEmptyState(
        title: model.filters.isNarrowed ? LibraryStrings.noSongs : LibraryStrings.emptyTitle,
        message: model.filters.isNarrowed ? LibraryStrings.tryDifferentSearch : LibraryStrings.emptyMessage)
    }
  }
}

/// The web `Empty` block with the songs tint (`song-list.tsx`: Music in a blue tile).
struct LibraryEmptyState: View {
  @Environment(\.capoUIScale) private var scale
  var icon: CapoIconName = .music
  let title: String
  let message: String

  var body: some View {
    let tile = RoundedRectangle(cornerRadius: CapoRadius.base * scale, style: .continuous)
    VStack(spacing: 16) {
      CapoIcon(icon, size: 24 * scale)
        .foregroundStyle(CapoTheme.accentSongs)
        .frame(width: 40 * scale, height: 40 * scale)
        .background(CapoTheme.accentSongs.opacity(0.10), in: tile)
        .overlay(tile.strokeBorder(CapoTheme.accentSongs.opacity(0.20), lineWidth: 1))
      VStack(spacing: 4) {
        Text(title).capoText(.lg, weight: .medium, tracking: -0.025)
        Text(message).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
      }
      .multilineTextAlignment(.center)
    }
    .padding(24)
  }
}

/// `sheet(item:)` needs an Identifiable value; avoids a retroactive conformance on UUID.
struct SongSheetTarget: Identifiable, Hashable {
  let id: SongID
}
