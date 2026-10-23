import CapoDesign
import Foundation

/// Editor copy; thin wrappers over the generated `L10n.Ios.Editor`.
/// No `bundle:` argument: CapoEditorUI has no resources, so there is no `Bundle.module`.
enum EditorStrings {
  static var newSong: String { L10n.Ios.Editor.newSong }
  static var editSong: String { L10n.Ios.Editor.editSong }
  static var details: String { L10n.Ios.Editor.details }
  static var title: String { L10n.Ios.Editor.title }
  static var titleRequired: String {
    L10n.Ios.Editor.titleRequired
  }
  static var artist: String { L10n.Ios.Editor.artist }
  static var key: String { L10n.Ios.Editor.key }
  static var noKey: String { L10n.Ios.Editor.noKey }
  static var bpm: String { L10n.Ios.Editor.bpm }
  static var bpmInvalid: String {
    L10n.Ios.Editor.bpmInvalid
  }
  static var transpose: String { L10n.Ios.Editor.transpose }
  static var capo: String { L10n.Ios.Editor.capo }
  static var notes: String { L10n.Ios.Editor.notes }
  static var lyrics: String { L10n.Ios.Editor.lyrics }
  static var preview: String { L10n.Ios.Editor.preview }
  static var edit: String { L10n.Ios.Editor.edit }
  static var save: String { L10n.Ios.Editor.save }
  static var cancel: String { L10n.Ios.Editor.cancel }
  static var delete: String { L10n.Ios.Editor.delete }
  static var deleteConfirmTitle: String {
    L10n.Ios.Editor.deleteConfirmTitle
  }
  static var deleteConfirmMessage: String {
    L10n.Ios.Editor.deleteConfirmMessage
  }
  static var discardTitle: String {
    L10n.Ios.Editor.discardTitle
  }
  static var discard: String { L10n.Ios.Editor.discard }
  static var keepEditing: String {
    L10n.Ios.Editor.keepEditing
  }
  static var viewerNotice: String {
    L10n.Ios.Editor.viewerNotice
  }
  static var notFound: String {
    L10n.Ios.Editor.notFound
  }
  static var insertDirective: String {
    L10n.Ios.Editor.insertDirective
  }
  static var dismissKeyboard: String {
    L10n.Ios.Editor.dismissKeyboard
  }
  static var saveFailed: String {
    L10n.Ios.Editor.saveFailed
  }
  static var comment: String { L10n.Ios.Editor.comment }

  // Conflicts
  static var conflictsTitle: String {
    L10n.Ios.Editor.Conflicts.title
  }
  static var conflictsEmptyTitle: String {
    L10n.Ios.Editor.Conflicts.emptyTitle
  }
  static var conflictsEmptyMessage: String {
    L10n.Ios.Editor.Conflicts.emptyMessage
  }
  static var mine: String { L10n.Ios.Editor.Conflicts.mine }
  static var theirs: String { L10n.Ios.Editor.Conflicts.theirs }
  static var deletedRemotely: String {
    L10n.Ios.Editor.Conflicts.deletedRemotely
  }
  static var keepMine: String {
    L10n.Ios.Editor.Conflicts.keepMine
  }
  static var keepTheirs: String {
    L10n.Ios.Editor.Conflicts.keepTheirs
  }
  static var keepBoth: String {
    L10n.Ios.Editor.Conflicts.keepBoth
  }
  static var differs: String {
    L10n.Ios.Editor.Conflicts.differs
  }
  static var empty: String { L10n.Ios.Editor.Conflicts.empty }
  static var resolveFailed: String {
    L10n.Ios.Editor.Conflicts.resolveFailed
  }
}

extension EditorStrings {
  static var livePreview: String { L10n.Ios.Editor.livePreview }
  static var chordsMode: String { L10n.Ios.Editor.chordsMode }
  static var showPreview: String { L10n.Ios.Editor.showPreview }
  static var hidePreview: String { L10n.Ios.Editor.hidePreview }
  static var resizePreview: String { L10n.Ios.Editor.resizePreview }
  static var savedLocally: String { L10n.Ios.Editor.savedLocally }
  static var deleteSong: String { L10n.Ios.Editor.deleteSong }
  static var moreOptions: String { L10n.Ios.Editor.moreOptions }
}
