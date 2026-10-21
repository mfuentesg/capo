import CapoDesign
import SwiftUI

/// Create or edit a setlist's name, description and date.
struct PlaylistFormView: View {
  enum Mode { case create, edit(Playlist) }

  let mode: Mode
  var onSaved: (Playlist?) -> Void = { _ in }

  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var details = ""
  @State private var hasDate = false
  @State private var date = Date()
  @State private var errorText: String?
  @State private var seeded = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(PlaylistStrings.name, text: $name)
          TextField(PlaylistStrings.descriptionLabel, text: $details, axis: .vertical)
            .lineLimit(1...4)
        }
        .listRowBackground(CapoTheme.card)
        Section {
          Toggle(PlaylistStrings.hasDate, isOn: $hasDate).tint(CapoTheme.primary)
          if hasDate {
            DatePicker(PlaylistStrings.date, selection: $date, displayedComponents: .date)
          }
        }
        .listRowBackground(CapoTheme.card)
        if let errorText { Text(errorText).font(.footnote).foregroundStyle(CapoTheme.destructive) }
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
            .font(.body.weight(.bold))
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .onAppear(perform: seed)
    }
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
            in: context)
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
