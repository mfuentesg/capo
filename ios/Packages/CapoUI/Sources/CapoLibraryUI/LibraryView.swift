import CapoDesign
import SwiftUI

/// Searchable, filterable song library. Works in a split-view content column or a compact stack.
public struct LibraryView: View {
  @Binding var selection: SongID?
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.currentTeamRole) private var role
  @Environment(\.capoActions) private var actions
  @State private var model = LibraryModel()
  @State private var showTagManagement = false
  @State private var assignTagsFor: SongSheetTarget?

  public init(selection: Binding<SongID?>) { _selection = selection }

  private var canEdit: Bool { role?.canEditContent ?? true }

  public var body: some View {
    @Bindable var model = model
    List(selection: $selection) {
      ForEach(model.songs) { item in
        SongRow(item: item, isSelected: selection == item.id)
          .tag(item.id)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
          .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
          .swipeActions(edge: .trailing) {
            Button { actions.addSongsToPlaylist([item.id]) } label: {
              Label(LibraryStrings.addToSetlist, systemImage: "music.note.list")
            }
            .tint(CapoTheme.primary)
          }
          .swipeActions(edge: .leading) {
            if canEdit {
              Button { assignTagsFor = SongSheetTarget(id: item.id) } label: {
                Label(LibraryStrings.assignTags, systemImage: "tag")
              }
              .tint(CapoTheme.chord)
            }
          }
          .contextMenu {
            Button { actions.addSongsToPlaylist([item.id]) } label: {
              Label(LibraryStrings.addToSetlist, systemImage: "music.note.list")
            }
            if canEdit {
              Button { assignTagsFor = SongSheetTarget(id: item.id) } label: {
                Label(LibraryStrings.assignTags, systemImage: "tag")
              }
              Button { actions.openEditor(.edit(item.id)) } label: {
                Label(LibraryStrings.editSong, systemImage: "pencil")
              }
            }
          }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(CapoTheme.background)
    .overlay { emptyState }
    .safeAreaInset(edge: .top, spacing: 0) {
      if !model.tags.isEmpty {
        TagFilterBar(tags: model.tags, selected: model.filters.tagIDs) {
          model.filters.toggle(tag: $0)
        }
      }
    }
    .searchable(text: $model.searchInput, prompt: LibraryStrings.searchPrompt)
    .refreshable { await services.sync.syncNow(reason: .manual) }
    .navigationTitle(LibraryStrings.title)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) { FilterMenu(model: model, onManageTags: { showTagManagement = true }) }
      if canEdit {
        ToolbarItem(placement: .topBarTrailing) {
          Button { actions.openEditor(.create) } label: {
            Label(LibraryStrings.newSong, systemImage: "plus")
              .labelStyle(.iconOnly)
              .fontWeight(.bold)
              .foregroundStyle(CapoTheme.onPrimary)
              .frame(width: CapoMetrics.minTouchTarget, height: 40)
              .background(CapoTheme.primary, in: RoundedRectangle(cornerRadius: CapoRadius.small + 2, style: .continuous))
          }
        }
      }
    }
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
  }

  @ViewBuilder private var emptyState: some View {
    if model.hasLoaded && model.songs.isEmpty {
      if model.filters.isNarrowed {
        EmptyStateView(
          title: LibraryStrings.noResultsTitle, message: LibraryStrings.noResultsMessage,
          systemImage: "magnifyingglass")
      } else {
        EmptyStateView(
          title: LibraryStrings.emptyTitle, message: LibraryStrings.emptyMessage,
          systemImage: "music.note.list")
      }
    }
  }
}

/// `sheet(item:)` needs an Identifiable value; avoids a retroactive conformance on UUID.
struct SongSheetTarget: Identifiable, Hashable {
  let id: SongID
}

struct TagFilterBar: View {
  let tags: [SongTag]
  let selected: Set<TagID>
  let onToggle: (TagID) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(tags) { tag in
          Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onToggle(tag.id)
          } label: {
            TagChip(name: tag.name, colorHex: tag.color, isSelected: selected.contains(tag.id))
              .frame(minHeight: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal)
    }
    .background(CapoTheme.background)
  }
}

struct FilterMenu: View {
  @Bindable var model: LibraryModel
  let onManageTags: () -> Void

  var body: some View {
    Menu {
      Picker(LibraryStrings.sort, selection: Binding(
        get: { model.filters.effectiveSort }, set: { model.filters.sort = $0 })
      ) {
        ForEach(model.filters.availableSorts, id: \.self) { Text(LibraryStrings.sortName($0)).tag($0) }
      }
      Menu(LibraryStrings.status) {
        ForEach(SongStatus.allCases, id: \.self) { status in
          Toggle(LibraryStrings.statusName(status), isOn: Binding(
            get: { model.filters.statuses.contains(status) },
            set: { _ in model.filters.toggle(status: status) }))
        }
      }
      Picker(LibraryStrings.tempo, selection: $model.filters.bpm) {
        Text("—").tag(BPMBucket?.none)
        ForEach(BPMBucket.allCases, id: \.self) {
          Text(LibraryStrings.bucketName($0)).tag(BPMBucket?.some($0))
        }
      }
      Divider()
      Button(LibraryStrings.manageTags, systemImage: "tag", action: onManageTags)
      if model.filters.hasActiveFilters {
        Button(LibraryStrings.resetFilters, systemImage: "xmark.circle") { model.filters.resetFilters() }
      }
    } label: {
      Label(
        LibraryStrings.filters,
        systemImage: model.filters.hasActiveFilters
          ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
    }
    .tint(CapoTheme.info)
  }
}
