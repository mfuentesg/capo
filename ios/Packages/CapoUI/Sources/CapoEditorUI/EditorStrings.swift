import Foundation

/// Editor copy. `L10n` has no editor keys yet; WP12 harvests the `ios.editor.*` keys in Wave 3.
/// No `bundle:` argument: CapoEditorUI has no resources, so there is no `Bundle.module`.
enum EditorStrings {
  // TODO(i18n)
  static var newSong: String { String(localized: "ios.editor.newSong", defaultValue: "New song") }
  // TODO(i18n)
  static var editSong: String { String(localized: "ios.editor.editSong", defaultValue: "Edit song") }
  // TODO(i18n)
  static var details: String { String(localized: "ios.editor.details", defaultValue: "Details") }
  // TODO(i18n)
  static var title: String { String(localized: "ios.editor.title", defaultValue: "Title") }
  // TODO(i18n)
  static var titleRequired: String {
    String(localized: "ios.editor.titleRequired", defaultValue: "A title is required")
  }
  // TODO(i18n)
  static var artist: String { String(localized: "ios.editor.artist", defaultValue: "Artist") }
  // TODO(i18n)
  static var key: String { String(localized: "ios.editor.key", defaultValue: "Key") }
  // TODO(i18n)
  static var noKey: String { String(localized: "ios.editor.noKey", defaultValue: "None") }
  // TODO(i18n)
  static var bpm: String { String(localized: "ios.editor.bpm", defaultValue: "Tempo (BPM)") }
  // TODO(i18n)
  static var bpmInvalid: String {
    String(localized: "ios.editor.bpmInvalid", defaultValue: "Tempo must be between 1 and 400")
  }
  // TODO(i18n)
  static var transpose: String { String(localized: "ios.editor.transpose", defaultValue: "Transpose") }
  // TODO(i18n)
  static var capo: String { String(localized: "ios.editor.capo", defaultValue: "Capo") }
  // TODO(i18n)
  static var notes: String { String(localized: "ios.editor.notes", defaultValue: "Notes") }
  // TODO(i18n)
  static var lyrics: String { String(localized: "ios.editor.lyrics", defaultValue: "Lyrics (ChordPro)") }
  // TODO(i18n)
  static var preview: String { String(localized: "ios.editor.preview", defaultValue: "Preview") }
  // TODO(i18n)
  static var edit: String { String(localized: "ios.editor.edit", defaultValue: "Edit") }
  // TODO(i18n)
  static var save: String { String(localized: "ios.editor.save", defaultValue: "Save") }
  // TODO(i18n)
  static var cancel: String { String(localized: "ios.editor.cancel", defaultValue: "Cancel") }
  // TODO(i18n)
  static var delete: String { String(localized: "ios.editor.delete", defaultValue: "Delete song") }
  // TODO(i18n)
  static var deleteConfirmTitle: String {
    String(localized: "ios.editor.deleteConfirmTitle", defaultValue: "Delete this song?")
  }
  // TODO(i18n)
  static var deleteConfirmMessage: String {
    String(
      localized: "ios.editor.deleteConfirmMessage",
      defaultValue: "It will be removed from your library and from any setlists.")
  }
  // TODO(i18n)
  static var discardTitle: String {
    String(localized: "ios.editor.discardTitle", defaultValue: "Discard changes?")
  }
  // TODO(i18n)
  static var discard: String { String(localized: "ios.editor.discard", defaultValue: "Discard") }
  // TODO(i18n)
  static var keepEditing: String {
    String(localized: "ios.editor.keepEditing", defaultValue: "Keep editing")
  }
  // TODO(i18n)
  static var viewerNotice: String {
    String(
      localized: "ios.editor.viewerNotice",
      defaultValue: "Viewers can't edit songs in this team.")
  }
  // TODO(i18n)
  static var notFound: String {
    String(localized: "ios.editor.notFound", defaultValue: "This song is no longer available.")
  }
  // TODO(i18n)
  static var insertDirective: String {
    String(localized: "ios.editor.insertDirective", defaultValue: "Insert directive")
  }
  // TODO(i18n)
  static var dismissKeyboard: String {
    String(localized: "ios.editor.dismissKeyboard", defaultValue: "Hide keyboard")
  }
  // TODO(i18n)
  static var saveFailed: String {
    String(localized: "ios.editor.saveFailed", defaultValue: "Couldn't save the song")
  }
  // TODO(i18n)
  static var comment: String { String(localized: "ios.editor.comment", defaultValue: "Comment") }

  // Conflicts
  // TODO(i18n)
  static var conflictsTitle: String {
    String(localized: "ios.editor.conflicts.title", defaultValue: "Sync conflicts")
  }
  // TODO(i18n)
  static var conflictsEmptyTitle: String {
    String(localized: "ios.editor.conflicts.emptyTitle", defaultValue: "No conflicts")
  }
  // TODO(i18n)
  static var conflictsEmptyMessage: String {
    String(
      localized: "ios.editor.conflicts.emptyMessage",
      defaultValue: "Everything you edited offline has been synced.")
  }
  // TODO(i18n)
  static var mine: String { String(localized: "ios.editor.conflicts.mine", defaultValue: "Mine") }
  // TODO(i18n)
  static var theirs: String { String(localized: "ios.editor.conflicts.theirs", defaultValue: "Server") }
  // TODO(i18n)
  static var deletedRemotely: String {
    String(
      localized: "ios.editor.conflicts.deletedRemotely",
      defaultValue: "This song was deleted on the server.")
  }
  // TODO(i18n)
  static var keepMine: String {
    String(localized: "ios.editor.conflicts.keepMine", defaultValue: "Keep mine")
  }
  // TODO(i18n)
  static var keepTheirs: String {
    String(localized: "ios.editor.conflicts.keepTheirs", defaultValue: "Keep server version")
  }
  // TODO(i18n)
  static var keepBoth: String {
    String(localized: "ios.editor.conflicts.keepBoth", defaultValue: "Keep both")
  }
  // TODO(i18n)
  static var differs: String {
    String(localized: "ios.editor.conflicts.differs", defaultValue: "Differs")
  }
  // TODO(i18n)
  static var empty: String { String(localized: "ios.editor.conflicts.empty", defaultValue: "(empty)") }
  // TODO(i18n)
  static var resolveFailed: String {
    String(localized: "ios.editor.conflicts.resolveFailed", defaultValue: "Couldn't resolve the conflict")
  }
}
