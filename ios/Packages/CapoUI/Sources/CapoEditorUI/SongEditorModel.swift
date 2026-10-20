import CapoDesign
import Observation

@Observable
final class SongEditorModel {
  enum LoadState: Equatable { case loading, ready, missing }

  var form = EditorForm()
  private(set) var baseline = EditorForm()
  private(set) var original: Song?
  private(set) var loadState: LoadState = .loading
  private(set) var isSaving = false
  var errorText: String?

  var isDirty: Bool { form != baseline }
  var isEditing: Bool { original != nil }
  var canSave: Bool { form.isValid && isDirty && !isSaving }

  func load(_ request: SongEditorRequest, songs: any SongRepository) async {
    switch request {
    case .create:
      loadState = .ready
    case .edit(let id):
      do {
        guard let song = try await songs.fetchSong(id: id) else {
          loadState = .missing
          return
        }
        original = song
        form = EditorForm(song: song)
        baseline = form
        loadState = .ready
      } catch {
        loadState = .missing
      }
    }
  }

  /// Returns the saved song id, or nil on failure (`errorText` is set).
  func save(songs: any SongRepository, context: AppContext) async -> SongID? {
    guard canSave else { return nil }
    isSaving = true
    defer { isSaving = false }
    do {
      if let original {
        let patch = form.patch(against: original)
        if !patch.isEmpty { try await songs.update(id: original.id, patch) }
        baseline = form
        return original.id
      }
      let song = try await songs.create(form.draft(), in: context)
      baseline = form
      return song.id
    } catch {
      errorText = EditorStrings.saveFailed
      return nil
    }
  }

  func delete(songs: any SongRepository) async -> Bool {
    guard let original else { return false }
    do {
      try await songs.delete(id: original.id)
      return true
    } catch {
      errorText = EditorStrings.saveFailed
      return false
    }
  }
}
