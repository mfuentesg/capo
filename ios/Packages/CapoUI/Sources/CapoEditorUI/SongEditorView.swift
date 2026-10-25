import CapoChordPro
import CapoDesign
import CapoIcons
import CapoRendering
import SwiftUI

public struct SongEditorView: View {
  let request: SongEditorRequest
  let onFinish: (SongID?) -> Void

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.creationContext) private var creationContext
  @Environment(\.teamRoles) private var teamRoles
  @State private var model = SongEditorModel()
  @State private var confirmDelete = false
  @State private var confirmDiscard = false
  @State private var panel = PreviewPanelLayout.load()
  @State private var showChords = true
  @State private var showExtras = false
  @State private var showPreviewSheet = false
  @State private var showCifra = false
  @State private var showReference = false
  @State private var notice: String?
  @State private var controller = LyricsEditorController()
  /// Where a new song is saved (web `BucketSelector`); seeded from the creation context.
  @State private var bucket: AppContext?
  @Environment(\.horizontalSizeClass) private var sizeClass

  public init(request: SongEditorRequest, onFinish: @escaping (SongID?) -> Void) {
    self.request = request
    self.onFinish = onFinish
  }

  private var isViewer: Bool {
    let teamID = model.original.map(\.teamID) ?? creationContext.teamID
    return !teamRoles.canEdit(teamID: teamID)
  }
  private var canDelete: Bool { teamRoles.canDelete(teamID: model.original?.teamID) }

  public var body: some View {
    VStack(spacing: 0) {
      header
      content
    }
    .capoTheme()
    .sheet(isPresented: $showPreviewSheet) {
      VStack {
        LivePreviewPanel(rendered: renderedPreview, showChords: $showChords) {
          showPreviewSheet = false
        }
        .padding(20)
      }
      .capoTheme()
      .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showCifra) {
      CifraClubImportView(
        mode: cifraMode,
        onImported: { song in
          model.apply(import: song)
          notice = L10n.Toasts.cifraImportSuccess
        },
        onClose: { showCifra = false }
      )
      .capoTheme()
      .presentationDetents([.height(260), .medium])
    }
    .sheet(isPresented: $showReference) {
      ChordProReferenceView { showReference = false }
        .capoTheme()
        .presentationDetents([.large])
    }
    .capoToast($notice)
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
        GeometryReader { geo in
          if sizeClass == .regular { regularLayout(containerWidth: geo.size.width) } else { editorColumn }
        }
      }
    }
  }

  // MARK: Layout

  private func regularLayout(containerWidth: CGFloat) -> some View {
    HStack(spacing: 0) {
      editorColumn
      if !panel.isCollapsed {
        PreviewResizeHandle(layout: $panel, containerWidth: containerWidth)
        VStack(spacing: 14) {
          LivePreviewPanel(rendered: renderedPreview, showChords: $showChords) { setCollapsed(true) }
          if model.isEditing && canDelete { deleteButton }
        }
        .padding(20)
        .frame(width: panel.resolvedWidth(containerWidth: containerWidth))
        .background(CapoTheme.background)
      }
    }
  }

  private func setCollapsed(_ collapsed: Bool) {
    withAnimation(.easeInOut(duration: 0.2)) { panel.isCollapsed = collapsed }
    panel.save()
  }

  private var editorColumn: some View {
    VStack(spacing: 0) {
      metadata
      Divider().overlay(CapoTheme.border)
      ShiftChordsToolbar { controller.shiftChords(by: $0) }
      if controller.hasSelection {
        SectionWrapToolbar { controller.wrap($0) }
      }
      LyricsTextView(text: $model.form.lyrics, songKey: model.form.key, controller: controller)
    }
  }

  private var showDeleteInExtras: Bool {
    model.isEditing && canDelete && (sizeClass != .regular || panel.isCollapsed)
  }

  private var header: some View {
    HStack(spacing: 12) {
      Button(EditorStrings.cancel) {
        if model.isDirty { confirmDiscard = true } else { onFinish(nil) }
      }
      .capoText(.base, weight: .semibold)
      .foregroundStyle(CapoTheme.info)
      .frame(minHeight: CapoMetrics.minTouchTarget)
      .accessibilityIdentifier("editor.cancel")
      Spacer(minLength: 0)
      VStack(spacing: 2) {
        Text(request == .create ? EditorStrings.newSong : EditorStrings.editSong)
          .capoText(.lg, weight: .bold)
        HStack(spacing: 6) {
          Circle().fill(CapoTheme.primary).frame(width: 8, height: 8)
          Text(EditorStrings.savedLocally)
            .capoText(.xs)
            .foregroundStyle(CapoTheme.subtext)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 0)
      if !isViewer, model.loadState == .ready {
        extraActions
        previewToggle
        Button(EditorStrings.save) {
          Task {
            if let id = await model.save(songs: services.songs, context: bucket ?? creationContext) { onFinish(id) }
          }
        }
        .buttonStyle(CapoPrimaryButtonStyle())
        .opacity(model.canSave ? 1 : 0.4)
        .disabled(!model.canSave)
        .accessibilityIdentifier("editor.save")
      }
    }
    .padding(.horizontal, 20).padding(.vertical, 8)
    .background(CapoTheme.sidebar)
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
  }

  private var cifraMode: CifraClubImportView.Mode {
    request == .create && model.form.lyrics.isEmpty
      ? .create
      : .replaceLyrics(hasExistingLyrics: !model.form.lyrics.isEmpty)
  }

  /// Wand (parse chords), CifraClub import and the ChordPro reference.
  private var extraActions: some View {
    HStack(spacing: 0) {
      Button {
        notice = model.parseChords() == .converted
          ? L10n.Toasts.lyricsConvertedToChordPro : L10n.Songs.Lyrics.parseChordsAlreadyChordPro
      } label: { CapoIcon(.wand2, size: 18) }
        .buttonStyle(CapoIconButtonStyle())
        .accessibilityLabel(L10n.Songs.Lyrics.parseChords)
        .accessibilityIdentifier("editor.parse")
      Button { showCifra = true } label: { CapoIcon(.music4, size: 18) }
        .buttonStyle(CapoIconButtonStyle())
        .accessibilityLabel(L10n.Songs.Lyrics.importFromCifraClub)
        .accessibilityIdentifier("editor.cifra")
      Button { showReference = true } label: { CapoIcon(.bookOpen, size: 18) }
        .buttonStyle(CapoIconButtonStyle())
        .accessibilityLabel(L10n.Songs.Lyrics.chordproReference)
        .accessibilityIdentifier("editor.reference")
    }
  }

  @ViewBuilder private var previewToggle: some View {
    if sizeClass == .regular {
      Button { setCollapsed(!panel.isCollapsed) } label: {
        CapoIcon(.columns2, size: 18)
      }
      .buttonStyle(CapoIconButtonStyle())
      .accessibilityLabel(panel.isCollapsed ? EditorStrings.showPreview : EditorStrings.hidePreview)
      .accessibilityIdentifier("editor.preview.toggle")
    } else {
      Button { showPreviewSheet = true } label: { CapoIcon(.eye, size: 18) }
        .buttonStyle(CapoIconButtonStyle())
        .accessibilityLabel(EditorStrings.showPreview)
        .accessibilityIdentifier("editor.preview.toggle")
    }
  }

  // MARK: Metadata

  private var metadata: some View {
    VStack(spacing: 12) {
      TextField(EditorStrings.title, text: $model.form.title)
        .capoText(.xl, weight: .bold)
        .padding(.horizontal, 16).frame(height: 52)
        .fieldChrome(radius: CapoRadius.medium + 2)
        .accessibilityIdentifier("editor.title")
      if model.form.issues.contains(.titleRequired) && model.isDirty {
        errorText(EditorStrings.titleRequired)
      }
      if sizeClass == .regular {
        HStack(alignment: .bottom, spacing: 10) {
          artistField.frame(maxWidth: .infinity)
          keyField.frame(width: 110)
          bpmField.frame(width: 110)
          capoField.frame(width: 110)
        }
      } else {
        artistField
        HStack(alignment: .bottom, spacing: 10) {
          keyField; bpmField; capoField
        }
      }
      if model.form.issues.contains(.bpmInvalid) { errorText(EditorStrings.bpmInvalid) }
      ForEach(EditorForm.LimitedField.allCases, id: \.self) { field in
        if model.form.issues.contains(.tooLong(field)) { errorText(EditorStrings.tooLong(field)) }
      }
      if !model.isEditing {
        BucketPicker(selection: Binding(get: { bucket ?? creationContext }, set: { bucket = $0 })).padding(.top, 4)
      }
      DisclosureGroup(isExpanded: $showExtras) {
        extras.padding(.top, 8)
      } label: {
        Text(EditorStrings.moreOptions)
          .capoText(.sm, weight: .semibold)
          .foregroundStyle(CapoTheme.subtext)
          .frame(minHeight: 36, alignment: .leading)
      }
      .tint(CapoTheme.subtext)
    }
    .padding(.horizontal, 20).padding(.vertical, 14)
    .background(CapoTheme.background)
  }

  private func errorText(_ text: String) -> some View {
    Text(text).capoText(.xs).foregroundStyle(CapoTheme.destructive)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 4) {
      Text(label.uppercased())
        .capoText(.px12, weight: .semibold, tracking: 0.08)
        .foregroundStyle(CapoTheme.subtext)
      content()
        .capoText(.base, weight: .medium)
        .padding(.horizontal, 14).frame(height: 46)
        .fieldChrome(radius: CapoRadius.medium)
    }
  }

  private var artistField: some View {
    labeled(EditorStrings.artist) {
      TextField(EditorStrings.artist, text: $model.form.artist).accessibilityIdentifier("editor.artist")
    }
  }

  private var keyField: some View {
    labeled(EditorStrings.key) {
      Menu {
        Picker(EditorStrings.key, selection: $model.form.key) {
          Text(EditorStrings.noKey).tag("")
          ForEach(EditorForm.keys, id: \.self) { Text($0).tag($0) }
        }
      } label: {
        menuLabel(model.form.key.isEmpty ? "—" : model.form.key)
      }
      .accessibilityIdentifier("editor.key")
    }
  }

  private var bpmField: some View {
    labeled(EditorStrings.bpm) {
      TextField(EditorStrings.bpm, text: $model.form.bpm).keyboardType(.numberPad)
        .accessibilityIdentifier("editor.bpm")
    }
  }

  private var capoField: some View {
    labeled(EditorStrings.capo) {
      Menu {
        Picker(EditorStrings.capo, selection: $model.form.capo) {
          ForEach(Array(EffectiveSongSettings.capoRange), id: \.self) { Text("\($0)").tag($0) }
        }
      } label: {
        menuLabel("\(model.form.capo)")
      }
      .accessibilityIdentifier("editor.capo")
    }
  }

  private func menuLabel(_ value: String) -> some View {
    HStack {
      Text(value).foregroundStyle(CapoTheme.text)
      Spacer(minLength: 4)
      CapoIcon(.chevronDown, size: 16).foregroundStyle(CapoTheme.subtext)
    }
    .frame(maxWidth: .infinity, minHeight: CapoMetrics.minTouchTarget)
    .contentShape(Rectangle())
  }

  private var extras: some View {
    VStack(spacing: 12) {
      Stepper(value: $model.form.transpose, in: EffectiveSongSettings.transposeRange) {
        LabeledContent(EditorStrings.transpose, value: signed(model.form.transpose))
      }
      .frame(minHeight: CapoMetrics.minTouchTarget)
      TextField(EditorStrings.notes, text: $model.form.notes, axis: .vertical)
        .lineLimit(2...6)
        .padding(14)
        .fieldChrome(radius: CapoRadius.medium)
      if showDeleteInExtras { deleteButton }
    }
  }

  private var deleteButton: some View {
    Button { confirmDelete = true } label: {
      HStack(spacing: 8) {
        CapoIcon(.trash2, size: 16)
        Text(EditorStrings.deleteSong)
      }
      .capoText(.base, weight: .semibold)
      .foregroundStyle(CapoTheme.destructive)
        .frame(maxWidth: .infinity, minHeight: 52)
        .overlay(
          RoundedRectangle(cornerRadius: CapoRadius.medium + 2, style: .continuous)
            .strokeBorder(CapoTheme.destructive, lineWidth: 1))
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("editor.delete")
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
}

private extension View {
  /// Card-coloured input box with a border, as in the web editor's fields.
  func fieldChrome(radius: CGFloat) -> some View {
    background(CapoTheme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .strokeBorder(CapoTheme.border, lineWidth: 1))
  }
}
