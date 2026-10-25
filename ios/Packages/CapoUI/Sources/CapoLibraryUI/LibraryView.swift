import CapoDesign
import CapoIcons
import SwiftUI

/// Songs table (design A): search header, sortable column strip, letter-sectioned rows with an
/// A-Z index, and a floating selection bar. Rows push the song page through `CapoActions.openSong`.
/// Compact width falls back to two-line rows without the column strip.
public struct LibraryView: View {
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.currentTeamRole) private var role
  @Environment(\.capoActions) private var actions
  @Environment(\.playlistDraft) private var draft
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var model = LibraryModel()
  @State private var showTagManagement = false
  @State private var assignTagsFor: SongSheetTarget?
  @State private var activeLetter: String?

  public init() {}

  private var canEdit: Bool { role?.canEditContent ?? true }

  public var body: some View {
    @Bindable var model = model
    GeometryReader { proxy in
      let layout = SongTableLogic.Layout(
        width: proxy.size.width, isRegularSizeClass: sizeClass == .regular, showsOwnership: context.isAll)
      VStack(spacing: 0) {
        LibraryHeader(
          model: model, canEdit: canEdit, isRegular: layout.mode == .regular,
          onAdd: { actions.openEditor(.create) }, onManageTags: { showTagManagement = true })
        if layout.mode == .regular { columnStrip(layout) } else { CapoTheme.border.frame(height: 1) }
        songList(layout)
      }
    }
    .background(CapoTheme.background)
    .overlay { emptyState }
    .safeAreaInset(edge: .bottom, spacing: 0) { selectionBar }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .navigationBar)
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

  // MARK: Column strip

  private func columnStrip(_ layout: SongTableLogic.Layout) -> some View {
    func header(_ column: SongColumn, width: CGFloat? = nil) -> some View {
      let sort = model.effectiveTableSort
      let state: TableSortState =
        sort?.column == column ? (sort?.ascending == true ? .ascending : .descending) : .unsorted
      return TableColumnHeader(LibraryStrings.columnName(column), state: state) { model.sort(by: column) }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
    return HStack(spacing: 0) {
      Color.clear.frame(width: SongTableMetrics.cart, height: 1)
      header(.title)
      header(.key, width: SongTableMetrics.key)
      header(.bpm, width: SongTableMetrics.bpm)
      header(.tags, width: SongTableMetrics.tags(showsOwnerColumn: layout.showsOwnerColumn))
      header(.played, width: SongTableMetrics.played)
      if layout.showsOwnerColumn { header(.owner, width: SongTableMetrics.owner) }
    }
    .padding(.leading, -8)
    .padding(.trailing, SongTableMetrics.index)
    .tableHeaderStrip()
  }

  // MARK: List

  private func songList(_ layout: SongTableLogic.Layout) -> some View {
    let displayed = model.displayedSongs(context: context)
    let sections = SongTableLogic.sections(displayed, sort: model.effectiveTableSort, grouping: model.filters.grouping)
    let letters = sections.compactMap { $0.id.hasPrefix("letter-") ? $0.title : nil }
    return ScrollViewReader { reader in
      List {
        ForEach(sections, id: \.id) { section in
          if let title = section.title {
            Section {
              rows(section.items, layout: layout)
            } header: {
              SongSectionHeader(title: title)
                .listRowInsets(EdgeInsets())
                .id(section.id)
            }
          } else {
            rows(section.items, layout: layout)
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .environment(\.defaultMinListRowHeight, 1)
      .refreshable { await services.sync.syncNow(reason: .manual) }
      .overlay(alignment: .trailing) {
        if !letters.isEmpty {
          LetterIndexScrubber(available: Set(letters), active: activeLetter ?? letters.first) { letter in
            guard let target = SongTableLogic.target(for: letter, available: letters) else { return }
            if activeLetter != target {
              activeLetter = target
              reader.scrollTo("letter-\(target)", anchor: .top)
            }
          }
          .padding(.vertical, 8)
        }
      }
    }
  }

  @ViewBuilder
  private func rows(_ items: [SongListItem], layout: SongTableLogic.Layout) -> some View {
    ForEach(items) { item in
      let state = SongTableRowState(
        inCart: draft.contains(item.id), selecting: model.selecting,
        ownership: model.ownership(for: item, in: context), layout: layout)
      Group {
        if layout.mode == .regular {
          SongTableRow(item: item, state: state) { draft.toggle(item.id) }
        } else {
          SongCompactRow(item: item, state: state) { draft.toggle(item.id) }
        }
      }
      .onTapGesture {
        if model.selecting { draft.toggle(item.id) } else { actions.openSong(item.id) }
      }
      .accessibilityAddTraits(.isButton)
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets())
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

  // MARK: Selection

  /// Floating "n selected · Clear · Add to Playlist" once songs are queued.
  @ViewBuilder private var selectionBar: some View {
    if !draft.ids.isEmpty {
      SelectionBar(
        count: draft.ids.count,
        onClear: { withAnimation(.snappy(duration: 0.2)) { draft.clear() } },
        onAdd: {
          actions.addSongsToPlaylist(draft.ids)
        }
      )
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
