import CapoChordPro
import CapoDesign
import CapoRendering
import SwiftUI

public struct SongEditorView: View {
  let request: SongEditorRequest
  let onFinish: (SongID?) -> Void

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.currentTeamRole) private var role
  @State private var model = SongEditorModel()
  @State private var page: Page = .details
  @State private var confirmDelete = false
  @State private var confirmDiscard = false

  enum Page: Hashable { case details, lyrics, preview }

  public init(request: SongEditorRequest, onFinish: @escaping (SongID?) -> Void) {
    self.request = request
    self.onFinish = onFinish
  }

  private var isViewer: Bool { role == .viewer }

  public var body: some View {
    NavigationStack {
      content
        .navigationTitle(request == .create ? EditorStrings.newSong : EditorStrings.editSong)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }
    .task { await model.load(request, songs: services.songs) }
    .interactiveDismissDisabled(model.isDirty)
    .confirmationDialog(
      EditorStrings.deleteConfirmTitle, isPresented: $confirmDelete, titleVisibility: .visible
    ) {
      Button(EditorStrings.delete, role: .destructive) {
        Task {
          if await model.delete(songs: services.songs) { onFinish(nil) }
        }
      }
      Button(EditorStrings.cancel, role: .cancel) {}
    } message: {
      Text(EditorStrings.deleteConfirmMessage)
    }
    .confirmationDialog(
      EditorStrings.discardTitle, isPresented: $confirmDiscard, titleVisibility: .visible
    ) {
      Button(EditorStrings.discard, role: .destructive) { onFinish(nil) }
      Button(EditorStrings.keepEditing, role: .cancel) {}
    }
    .alert(
      EditorStrings.saveFailed,
      isPresented: Binding(
        get: { model.errorText != nil }, set: { if !$0 { model.errorText = nil } })
    ) {
      Button(L10n.Common.close, role: .cancel) {}
    }
  }

  @ViewBuilder private var content: some View {
    if isViewer {
      EmptyStateView(title: EditorStrings.viewerNotice, message: nil, systemImage: "lock")
    } else {
      switch model.loadState {
      case .loading:
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      case .missing:
        EmptyStateView(title: EditorStrings.notFound, message: nil, systemImage: "music.note")
      case .ready:
        VStack(spacing: 0) {
          Picker("", selection: $page) {
            Text(EditorStrings.details).tag(Page.details)
            Text(EditorStrings.lyrics).tag(Page.lyrics)
            Text(EditorStrings.preview).tag(Page.preview)
          }
          .pickerStyle(.segmented)
          .padding([.horizontal, .top])
          .padding(.bottom, 8)
          .accessibilityIdentifier("editor.pagePicker")
          switch page {
          case .details: detailsForm
          case .lyrics: LyricsTextView(text: $model.form.lyrics)
          case .preview: preview
          }
        }
      }
    }
  }

  private var detailsForm: some View {
    Form {
      Section {
        TextField(EditorStrings.title, text: $model.form.title)
          .accessibilityIdentifier("editor.title")
        if model.form.issues.contains(.titleRequired) && model.isDirty {
          Text(EditorStrings.titleRequired).font(.footnote).foregroundStyle(.red)
        }
        TextField(EditorStrings.artist, text: $model.form.artist)
        Picker(EditorStrings.key, selection: $model.form.key) {
          Text(EditorStrings.noKey).tag("")
          ForEach(EditorForm.keys, id: \.self) { Text($0).tag($0) }
        }
        TextField(EditorStrings.bpm, text: $model.form.bpm)
          .keyboardType(.numberPad)
        if model.form.issues.contains(.bpmInvalid) {
          Text(EditorStrings.bpmInvalid).font(.footnote).foregroundStyle(.red)
        }
      }
      Section {
        Stepper(value: $model.form.transpose, in: EffectiveSongSettings.transposeRange) {
          LabeledContent(EditorStrings.transpose, value: signed(model.form.transpose))
        }
        Stepper(value: $model.form.capo, in: EffectiveSongSettings.capoRange) {
          LabeledContent(EditorStrings.capo, value: "\(model.form.capo)")
        }
      }
      Section(EditorStrings.notes) {
        TextField(EditorStrings.notes, text: $model.form.notes, axis: .vertical)
          .lineLimit(2...8)
      }
      if model.isEditing {
        Section {
          Button(EditorStrings.delete, role: .destructive) { confirmDelete = true }
            .accessibilityIdentifier("editor.delete")
        }
      }
    }
  }

  private var preview: some View {
    ScrollView {
      ChordProContentView(rendered: renderedPreview, style: SongRenderStyle())
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var renderedPreview: RenderedSong {
    ChordProEngine.render(
      model.form.lyrics,
      options: ChordProRenderOptions(
        transpose: model.form.transpose, capo: model.form.capo,
        sectionLabels: [
          "chorus": L10n.SongSections.chorus, "verse": L10n.SongSections.verse,
          "bridge": L10n.SongSections.bridge, "tab": L10n.SongSections.tab,
          "grid": L10n.SongSections.grid, "intro": L10n.SongSections.intro,
          "outro": L10n.SongSections.outro, "pre_chorus": L10n.SongSections.pre_chorus
        ],
        commentLabel: EditorStrings.comment))
  }

  private func signed(_ value: Int) -> String { value > 0 ? "+\(value)" : "\(value)" }

  @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button(EditorStrings.cancel) {
        if model.isDirty { confirmDiscard = true } else { onFinish(nil) }
      }
    }
    if !isViewer {
      ToolbarItem(placement: .confirmationAction) {
        Button(EditorStrings.save) {
          Task {
            if let id = await model.save(songs: services.songs, context: context) { onFinish(id) }
          }
        }
        .disabled(!model.canSave)
        .accessibilityIdentifier("editor.save")
      }
    }
  }
}
