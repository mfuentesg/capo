import CapoDesign
import SwiftUI

/// Multi-select song picker, used by the playlists UI. Calls `onPick` with the chosen ids in the
/// order they were tapped.
public struct SongPickerView: View {
  let excluding: Set<SongID>
  let onPick: ([SongID]) -> Void

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var model = LibraryModel()
  @State private var picked: [SongID] = []

  public init(excluding: Set<SongID> = [], onPick: @escaping ([SongID]) -> Void) {
    self.excluding = excluding
    self.onPick = onPick
  }

  private var visible: [SongListItem] { model.songs.filter { !excluding.contains($0.id) } }

  public var body: some View {
    @Bindable var model = model
    NavigationStack {
      List {
        ForEach(visible) { item in
          Button { toggle(item.id) } label: {
            SongRow(item: item, showsSelection: true, isSelected: picked.contains(item.id))
          }
          .buttonStyle(.plain)
        }
      }
      .listStyle(.plain)
      .overlay {
        if model.hasLoaded && visible.isEmpty {
          EmptyStateView(
            title: model.filters.isNarrowed
              ? LibraryStrings.noResultsTitle : LibraryStrings.emptyTitle,
            message: model.filters.isNarrowed
              ? LibraryStrings.noResultsMessage : LibraryStrings.emptyMessage,
            systemImage: model.filters.isNarrowed ? "magnifyingglass" : "music.note.list")
        }
      }
      .searchable(text: $model.searchInput, prompt: LibraryStrings.searchPrompt)
      .navigationTitle(LibraryStrings.pickerTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(LibraryStrings.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(LibraryStrings.addCount(picked.count)) {
            onPick(picked)
            dismiss()
          }
          .disabled(picked.isEmpty)
        }
      }
      .task(id: model.searchInput) { await model.commitSearchAfterDebounce() }
      .task(id: model.query(context: context)) {
        for await items in services.songs.songs(model.query(context: context)) {
          model.songs = items
          model.hasLoaded = true
        }
      }
    }
  }

  private func toggle(_ id: SongID) {
    if let index = picked.firstIndex(of: id) { picked.remove(at: index) } else { picked.append(id) }
  }
}
