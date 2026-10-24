import CapoDesign
import CapoChordPro
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

  enum ParseOutcome: Equatable { case converted, alreadyChordPro }

  /// Wand: converts chord-above-lyrics blocks in the lyrics to ChordPro (web `handleParseChords`).
  @discardableResult
  func parseChords() -> ParseOutcome {
    let result = ChordProConverter.convertChordAboveLyricsBlocks(form.lyrics)
    guard result.converted else { return .alreadyChordPro }
    form.lyrics = result.output
    return .converted
  }

  /// Applies a CifraClub import. In create mode (nothing typed yet) the details fill in too, like the
  /// web's create-from-import; otherwise only the lyrics are replaced.
  func apply(import song: CifraClubSong) {
    form.lyrics = song.lyrics
    guard !isEditing, form.title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    form.title = song.title
    form.artist = song.artist
    if song.keyFound { form.key = song.key }
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
