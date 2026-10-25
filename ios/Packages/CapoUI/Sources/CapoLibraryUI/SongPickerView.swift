import CapoDesign
import SwiftUI

/// Multi-select song picker, used by the playlists UI. Calls `onPick` with the chosen ids in the
/// order they were tapped.
public struct SongPickerView: View {
  let excluding: Set<SongID>
  /// Bucket of the target playlist: a playlist only holds songs of its own personal/team bucket
  /// (web `add-songs-sheet`), so the list is limited to it. nil = the current view context.
  let bucket: AppContext?
  let onPick: ([SongID]) -> Void

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var model = LibraryModel()
  @State private var picked: [SongID] = []

  public init(
    excluding: Set<SongID> = [], bucket: AppContext? = nil, onPick: @escaping ([SongID]) -> Void
  ) {
    self.excluding = excluding
    self.bucket = bucket
    self.onPick = onPick
  }

  private var queryContext: AppContext { bucket ?? context }
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
          LibraryEmptyState(
            title: model.filters.isNarrowed ? LibraryStrings.noSongs : LibraryStrings.emptyTitle,
            message: model.filters.isNarrowed
              ? LibraryStrings.tryDifferentSearch : LibraryStrings.emptyMessage)
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
      .task(id: model.query(context: queryContext)) {
        for await items in services.songs.songs(model.query(context: queryContext)) {
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
