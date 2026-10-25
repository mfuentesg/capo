import CapoDesign
import CapoIcons
import SwiftUI

/// Create or edit a setlist's name, description and date.
struct PlaylistFormView: View {
  enum Mode { case create, edit(Playlist) }

  let mode: Mode
  var onSaved: (Playlist?) -> Void = { _ in }

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.creationContext) private var creationContext
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var details = ""
  @State private var hasDate = false
  @State private var date = Date()
  @State private var errorText: String?
  @State private var seeded = false
  @State private var bucket: AppContext?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack(spacing: 8) {
            TextField(PlaylistStrings.name, text: $name)
            if isCreate {
              Button {
                name = PlaylistLogic.suggestName(
                  adjectives: L10n.Ios.Playlists.suggestAdjectives,
                  nouns: L10n.Ios.Playlists.suggestNouns)
              } label: {
                CapoIcon(.sparkles, size: 16).foregroundStyle(CapoTheme.mutedForeground)
                  .frame(width: 36, height: 36).contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel(L10n.Playlists.suggestName)
            }
          }
          if name.count > PlaylistLogic.maxName {
            limitError(PlaylistStrings.name, max: PlaylistLogic.maxName)
          }
          TextField(PlaylistStrings.descriptionLabel, text: $details, axis: .vertical)
            .lineLimit(1...4)
          if details.count > PlaylistLogic.maxDescription {
            limitError(PlaylistStrings.descriptionLabel, max: PlaylistLogic.maxDescription)
          }
        }
        .listRowBackground(CapoTheme.card)
        if isCreate {
          Section {
            BucketPicker(
              selection: Binding(get: { bucket ?? creationContext }, set: { bucket = $0 }),
              label: L10n.Playlists.bucket)
          }
          .listRowBackground(Color.clear)
        }
        Section {
          Toggle(PlaylistStrings.hasDate, isOn: $hasDate).tint(CapoTheme.primary)
          if hasDate {
            DatePicker(PlaylistStrings.date, selection: $date, displayedComponents: .date)
          }
        }
        .listRowBackground(CapoTheme.card)
        if let errorText { Text(errorText).font(CapoFont.style(.footnote)).foregroundStyle(CapoTheme.destructive) }
      }
      .scrollContentBackground(.hidden)
      .background(CapoTheme.background)
      .tint(CapoTheme.primary)
      .navigationTitle(isCreate ? PlaylistStrings.newSetlist : PlaylistStrings.editDetails)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(PlaylistStrings.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isCreate ? PlaylistStrings.create : PlaylistStrings.save, action: save)
            .font(CapoFont.style(.body, weight: .bold))
            .disabled(!canSave)
        }
      }
      .onAppear(perform: seed)
    }
  }

  private var canSave: Bool {
    !name.trimmingCharacters(in: .whitespaces).isEmpty && name.count <= PlaylistLogic.maxName
      && details.count <= PlaylistLogic.maxDescription
  }

  private func limitError(_ field: String, max: Int) -> some View {
    Text("\(field): \(L10n.Ios.Editor.maxLength(max: String(max)))")
      .font(CapoFont.style(.footnote)).foregroundStyle(CapoTheme.destructive)
  }

  private var isCreate: Bool {
    if case .create = mode { true } else { false }
  }

  private func seed() {
    guard !seeded else { return }
    seeded = true
    if case .edit(let playlist) = mode {
      name = playlist.name
      details = playlist.description ?? ""
      if let d = PlaylistDate.parse(playlist.date) {
        hasDate = true
        date = d
      }
    }
  }

  private func save() {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    let dateString = hasDate ? PlaylistDate.format(date) : ""
    Task {
      do {
        switch mode {
        case .create:
          let created = try await services.playlists.create(
            PlaylistDraft(
              name: trimmed, description: details.isEmpty ? nil : details,
              date: hasDate ? dateString : nil),
            in: bucket ?? creationContext)
          onSaved(created)
        case .edit(let playlist):
          try await services.playlists.update(
            id: playlist.id,
            PlaylistPatch(name: trimmed, description: details, date: dateString))
          onSaved(nil)
        }
        dismiss()
      } catch { errorText = String(describing: error) }
    }
  }
}
